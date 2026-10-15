USE mediatheque;

DROP PROCEDURE IF EXISTS p_emprunter;
DROP PROCEDURE IF EXISTS p_rendre;
DROP PROCEDURE IF EXISTS p_bilan_adherent;

DELIMITER //

CREATE PROCEDURE p_emprunter(IN  p_code_barre  VARCHAR(20),
                             IN  p_adherent_id INT UNSIGNED,
                             OUT p_emprunt_id  INT UNSIGNED)
MODIFIES SQL DATA
BEGIN
  DECLARE v_actif         TINYINT      DEFAULT NULL;
  DECLARE v_exemplaire_id INT UNSIGNED DEFAULT NULL;
  DECLARE v_disponible    TINYINT      DEFAULT NULL;
  DECLARE v_etat          VARCHAR(20)  DEFAULT NULL;
  DECLARE v_dues          DECIMAL(8,2) DEFAULT 0.00;
  DECLARE v_message       VARCHAR(255) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET p_emprunt_id = NULL;
  START TRANSACTION;

  SELECT actif INTO v_actif FROM adherent WHERE id = p_adherent_id;

  IF v_actif IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : adhérent inconnu.';
  END IF;
  IF v_actif = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : l''inscription de cet adhérent n''est plus active.';
  END IF;

  -- FOR UPDATE : deux guichets ne peuvent pas prêter le même exemplaire en même temps
  SELECT id, disponible, etat INTO v_exemplaire_id, v_disponible, v_etat
    FROM exemplaire
   WHERE code_barre = p_code_barre
     FOR UPDATE;

  IF v_exemplaire_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : code-barres inconnu, aucun exemplaire ne porte ce code.';
  END IF;
  IF v_etat = 'hors_service' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : cet exemplaire est hors service.';
  END IF;
  IF v_disponible = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : cet exemplaire est déjà emprunté.';
  END IF;

  IF f_nb_emprunts_en_cours(p_adherent_id) >= 5 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Emprunt refusé : quota atteint, 5 documents maximum par adhérent.';
  END IF;

  SET v_dues = f_penalites_dues(p_adherent_id);
  IF v_dues > 10 THEN
    SET v_message = CONCAT('Emprunt refusé : ', v_dues, ' € de pénalités impayées (10 € maximum).');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_message;
  END IF;

  -- Dates et disponibilité : gérées par les triggers
  INSERT INTO emprunt (exemplaire_id, adherent_id)
  VALUES (v_exemplaire_id, p_adherent_id);

  SET p_emprunt_id = LAST_INSERT_ID();
  COMMIT;
END //

CREATE PROCEDURE p_rendre(IN p_code_barre VARCHAR(20))
MODIFIES SQL DATA
BEGIN
  DECLARE v_tarif       DECIMAL(4,2) DEFAULT 0.20;
  DECLARE v_emprunt_id  INT UNSIGNED DEFAULT NULL;
  DECLARE v_adherent_id INT UNSIGNED DEFAULT NULL;
  DECLARE v_jours       INT          DEFAULT 0;
  DECLARE v_montant     DECIMAL(6,2) DEFAULT 0.00;
  DECLARE v_message     VARCHAR(255) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT em.id, em.adherent_id INTO v_emprunt_id, v_adherent_id
    FROM emprunt em
    JOIN exemplaire ex ON ex.id = em.exemplaire_id
   WHERE ex.code_barre = p_code_barre
     AND em.date_retour_reelle IS NULL
     FOR UPDATE;

  IF v_emprunt_id IS NULL THEN
    SET v_message = CONCAT('Retour refusé : aucun emprunt en cours pour le code-barres ', p_code_barre, '.');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_message;
  END IF;

  UPDATE emprunt SET date_retour_reelle = CURDATE() WHERE id = v_emprunt_id;

  SET v_jours = f_jours_de_retard(v_emprunt_id);
  IF v_jours > 0 THEN
    SET v_montant = v_jours * v_tarif;
    INSERT INTO penalite (adherent_id, emprunt_id, montant, motif, date_creation)
    VALUES (v_adherent_id, v_emprunt_id, v_montant,
            CONCAT('Retour avec ', v_jours, ' jour(s) de retard'), CURDATE());
  END IF;

  COMMIT;

  SELECT v_emprunt_id AS emprunt_id, v_jours AS jours_de_retard, v_montant AS montant_facture;
END //

CREATE PROCEDURE p_bilan_adherent(IN p_adherent_id INT UNSIGNED)
READS SQL DATA
BEGIN
  IF NOT EXISTS (SELECT 1 FROM adherent WHERE id = p_adherent_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bilan impossible : adhérent inconnu.';
  END IF;

  SELECT id, nom, prenom, email, ville, date_inscription, actif,
         f_nb_emprunts_en_cours(id) AS nb_en_cours,
         f_penalites_dues(id)       AS penalites_dues
    FROM adherent
   WHERE id = p_adherent_id;

  SELECT em.id AS emprunt_id, ex.code_barre, o.titre,
         em.date_emprunt, em.date_retour_prevue,
         f_jours_de_retard(em.id) AS jours_de_retard
    FROM emprunt em
    JOIN exemplaire ex ON ex.id = em.exemplaire_id
    JOIN ouvrage    o  ON o.id  = ex.ouvrage_id
   WHERE em.adherent_id = p_adherent_id
     AND em.date_retour_reelle IS NULL
   ORDER BY em.date_retour_prevue;

  SELECT COUNT(*) AS nb_emprunts_total
    FROM emprunt
   WHERE adherent_id = p_adherent_id;
END //

DELIMITER ;
