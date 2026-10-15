USE mediatheque;

CREATE OR REPLACE VIEW v_adherent_lyon AS
SELECT id, nom, prenom, email, telephone, date_naissance,
       ville, date_inscription, actif
  FROM adherent
 WHERE ville = 'Lyon'
  WITH CHECK OPTION;

INSERT INTO v_adherent_lyon (nom, prenom, email, ville, date_inscription)
VALUES ('Testeur', 'Lyon', 'lyon.test@example.fr', 'Lyon', CURDATE());

SELECT id, nom, prenom, ville FROM adherent WHERE email = 'lyon.test@example.fr';

-- INSERT INTO v_adherent_lyon (nom, prenom, email, ville, date_inscription)
-- VALUES ('Testeur', 'Bron', 'bron.test@example.fr', 'Bron', CURDATE());
--   ERROR 1369 : CHECK OPTION failed -> la ligne ne respecte pas ville = 'Lyon'

-- UPDATE v_catalogue SET titre = 'Test' WHERE ouvrage_id = 1;
--   ERROR 1288 : not updatable -> la vue contient GROUP BY, COUNT, SUM

SELECT table_name, is_updatable
  FROM information_schema.views
 WHERE table_schema = 'mediatheque'
 ORDER BY table_name;

-- Sinon base-03-volume.sql plante (ids d'adhérents non contigus)
DELETE FROM adherent WHERE email = 'lyon.test@example.fr';
