USE mediatheque;

-- Remise à zéro : MySQL n'a pas de DROP INDEX IF EXISTS.
-- Le composite sert aussi à la clé étrangère : il faut retirer la clé
-- avant de le supprimer, puis la remettre.
SET @composite = (SELECT COUNT(*) FROM information_schema.statistics
                   WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                     AND index_name = 'idx_emprunt_adherent_date');
SET @sql = IF(@composite > 0, 'ALTER TABLE emprunt DROP FOREIGN KEY fk_emprunt_adherent', 'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @sql = IF(@composite > 0, 'DROP INDEX idx_emprunt_adherent_date ON emprunt', 'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @sql = IF(@composite > 0, 'ALTER TABLE emprunt ADD CONSTRAINT fk_emprunt_adherent FOREIGN KEY (adherent_id) REFERENCES adherent (id)', 'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'idx_emprunt_date') > 0,
              'DROP INDEX idx_emprunt_date ON emprunt', 'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.statistics
                WHERE table_schema = 'mediatheque' AND table_name = 'emprunt'
                  AND index_name = 'idx_emprunt_retour') > 0,
              'DROP INDEX idx_emprunt_retour ON emprunt', 'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

ANALYZE TABLE emprunt;

-- Avant
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
SELECT COUNT(*) AS r1_lignes FROM emprunt WHERE date_emprunt = '2024-03-12';

EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
SELECT COUNT(*) AS r2_lignes FROM emprunt WHERE date_retour_reelle IS NULL;

EXPLAIN SELECT id, date_emprunt FROM emprunt
         WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
SELECT COUNT(*) AS r3_lignes FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';

SELECT ROUND(data_length  / 1024 / 1024, 2) AS donnees_mo,
       ROUND(index_length / 1024 / 1024, 2) AS index_mo
  FROM information_schema.tables
 WHERE table_schema = 'mediatheque' AND table_name = 'emprunt';

-- Après
CREATE INDEX idx_emprunt_date ON emprunt (date_emprunt);
ANALYZE TABLE emprunt;
EXPLAIN SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';

CREATE INDEX idx_emprunt_retour ON emprunt (date_retour_reelle);
ANALYZE TABLE emprunt;
EXPLAIN SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;

-- Égalité (adherent_id) d'abord, plage (date_emprunt) ensuite : les emprunts
-- de l'adhérent sont regroupés et triés par date. Dans l'autre ordre, il
-- faudrait parcourir les emprunts récents de tous les adhérents.
CREATE INDEX idx_emprunt_adherent_date ON emprunt (adherent_id, date_emprunt);
ANALYZE TABLE emprunt;
EXPLAIN SELECT id, date_emprunt FROM emprunt
         WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';

-- Préfixe gauche : le composite sert pour la 1re requête, pas pour la 2e
EXPLAIN SELECT id FROM emprunt WHERE adherent_id = 12;
EXPLAIN SELECT id FROM emprunt WHERE date_emprunt >= '2025-01-01';

-- Index couvrant : "Using index" disparaît dès qu'on demande exemplaire_id
EXPLAIN SELECT adherent_id, date_emprunt FROM emprunt WHERE adherent_id = 12;
EXPLAIN SELECT adherent_id, date_emprunt, exemplaire_id FROM emprunt WHERE adherent_id = 12;

-- YEAR() sur la colonne empêche d'utiliser l'index ; la plage de dates, non
EXPLAIN SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;
SELECT  COUNT(*) AS avec_year FROM emprunt WHERE YEAR(date_emprunt) = 2024;

EXPLAIN SELECT COUNT(*) FROM emprunt
         WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';
SELECT  COUNT(*) AS avec_plage FROM emprunt
 WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';

ANALYZE TABLE emprunt;
SELECT ROUND(data_length  / 1024 / 1024, 2) AS donnees_mo,
       ROUND(index_length / 1024 / 1024, 2) AS index_mo
  FROM information_schema.tables
 WHERE table_schema = 'mediatheque' AND table_name = 'emprunt';
