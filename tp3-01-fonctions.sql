USE mediatheque;

DROP FUNCTION IF EXISTS f_nb_emprunts_en_cours;
DROP FUNCTION IF EXISTS f_penalites_dues;
DROP FUNCTION IF EXISTS f_jours_de_retard;

DELIMITER //

CREATE FUNCTION f_nb_emprunts_en_cours(p_adherent_id INT UNSIGNED)
RETURNS INT UNSIGNED
READS SQL DATA
BEGIN
  DECLARE v_nb INT UNSIGNED DEFAULT 0;

  SELECT COUNT(*) INTO v_nb
    FROM emprunt
   WHERE adherent_id = p_adherent_id
     AND date_retour_reelle IS NULL;

  RETURN v_nb;
END //

CREATE FUNCTION f_penalites_dues(p_adherent_id INT UNSIGNED)
RETURNS DECIMAL(8,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(8,2) DEFAULT 0.00;

  -- SUM() sur zéro ligne renvoie NULL : COALESCE le remplace par 0.00
  SELECT COALESCE(SUM(montant), 0.00) INTO v_total
    FROM penalite
   WHERE adherent_id = p_adherent_id
     AND payee = 0;

  RETURN v_total;
END //

CREATE FUNCTION f_jours_de_retard(p_emprunt_id INT UNSIGNED)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_jours INT DEFAULT NULL;

  -- Emprunt rendu : date de retour réelle ; en cours : aujourd'hui
  SELECT GREATEST(0, DATEDIFF(COALESCE(date_retour_reelle, CURDATE()),
                              date_retour_prevue))
    INTO v_jours
    FROM emprunt
   WHERE id = p_emprunt_id;

  RETURN v_jours;
END //

DELIMITER ;

SELECT a.id,
       CONCAT(a.prenom, ' ', a.nom)   AS adherent,
       f_nb_emprunts_en_cours(a.id)   AS nb_en_cours,
       f_penalites_dues(a.id)         AS penalites_dues,
       (SELECT MAX(f_jours_de_retard(em.id))
          FROM emprunt em
         WHERE em.adherent_id = a.id
           AND em.date_retour_reelle IS NULL) AS retard_max
  FROM adherent a
 WHERE f_nb_emprunts_en_cours(a.id) > 0
 ORDER BY retard_max DESC, a.id;
