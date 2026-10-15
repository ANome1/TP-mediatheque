USE mediatheque;

CREATE TABLE IF NOT EXISTS journal_action (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_cible VARCHAR(40)     NOT NULL,
  operation   VARCHAR(10)     NOT NULL,
  cle         VARCHAR(40)     NOT NULL,
  auteur      VARCHAR(100)    NOT NULL,
  horodatage  DATETIME        NOT NULL,
  details     VARCHAR(255)        NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_emprunt_bi;
DROP TRIGGER IF EXISTS trg_emprunt_ai;
DROP TRIGGER IF EXISTS trg_emprunt_au;

DELIMITER //

CREATE TRIGGER trg_emprunt_bi
BEFORE INSERT ON emprunt
FOR EACH ROW
BEGIN
  IF NEW.date_emprunt IS NULL THEN
    SET NEW.date_emprunt = CURDATE();
  END IF;

  IF NEW.date_retour_prevue IS NULL THEN
    SET NEW.date_retour_prevue = NEW.date_emprunt + INTERVAL 14 DAY;
  END IF;

  IF NEW.date_retour_prevue < NEW.date_emprunt THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Emprunt refusé : la date de retour prévue est antérieure à la date d''emprunt.';
  END IF;
END //

CREATE TRIGGER trg_emprunt_ai
AFTER INSERT ON emprunt
FOR EACH ROW
BEGIN
  -- Un emprunt inséré déjà rendu (archive) ne sort pas l'exemplaire
  IF NEW.date_retour_reelle IS NULL THEN
    UPDATE exemplaire SET disponible = 0 WHERE id = NEW.exemplaire_id;
  END IF;

  INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
  VALUES ('emprunt', 'INSERT', NEW.id, USER(), NOW(),
          CONCAT('exemplaire ', NEW.exemplaire_id, ' prêté à l''adhérent ', NEW.adherent_id));
END //

CREATE TRIGGER trg_emprunt_au
AFTER UPDATE ON emprunt
FOR EACH ROW
BEGIN
  -- Seul le passage NULL -> date est un retour (pas une simple modification)
  IF OLD.date_retour_reelle IS NULL AND NEW.date_retour_reelle IS NOT NULL THEN
    UPDATE exemplaire SET disponible = 1 WHERE id = NEW.exemplaire_id;

    INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
    VALUES ('emprunt', 'RETOUR', NEW.id, USER(), NOW(),
            CONCAT('exemplaire ', NEW.exemplaire_id, ' rendu'));
  ELSE
    INSERT INTO journal_action (table_cible, operation, cle, auteur, horodatage, details)
    VALUES ('emprunt', 'UPDATE', NEW.id, USER(), NOW(), 'emprunt modifié');
  END IF;
END //

DELIMITER ;

SHOW TRIGGERS FROM mediatheque;
