-- =====================================================================
--  Médiathèque municipale — mise en volume de la table emprunt
--  Module SQL avancé · B2 Informatique · Lionel Duport
--
--      mysql -u root -p < base-03-volume.sql
--
--  À exécuter AVANT la séance 2 : sans volume, toutes les requêtes
--  répondent en 0 ms et aucun index ne sert à rien.
--
--  Le script ajoute 200 000 emprunts d'archive (tous rendus, entre 2021
--  et 2025). Les 130 emprunts du jeu de départ ne sont pas touchés :
--  les emprunts en cours et les retards restent exactement les mêmes.
--  Comptez une à deux minutes d'exécution.
-- =====================================================================

USE mediatheque;

-- Rejouable : on efface l'archive éventuellement déjà générée.
DELETE FROM emprunt WHERE id >= 100000;
ALTER TABLE emprunt AUTO_INCREMENT = 100000;

-- Table de chiffres : 10 lignes, 0 à 9.
DROP TABLE IF EXISTS chiffre;
CREATE TABLE chiffre (n TINYINT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO chiffre (n) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

-- Les effectifs sont lus AVANT l'insertion, et rangés dans des variables.
-- Si on les lisait dans le SELECT, un trigger sur emprunt qui met à jour
-- exemplaire ferait échouer la requête (erreur 1442 : on ne peut pas modifier
-- une table que l'instruction en cours est déjà en train de lire).
SET @nb_exemplaires = (SELECT COUNT(*) FROM exemplaire);
SET @nb_adherents   = (SELECT COUNT(*) FROM adherent);

-- Six tables de chiffres jointes entre elles = 1 000 000 de combinaisons,
-- dont on ne garde que les 200 000 premières.
INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt,
                     date_retour_prevue, date_retour_reelle)
SELECT exemplaire_id,
       adherent_id,
       d,
       d + INTERVAL 14 DAY,
       d + INTERVAL (10 + duree) DAY
  FROM (
        SELECT 1 + FLOOR(RAND(101) * @nb_exemplaires) AS exemplaire_id,
               1 + FLOOR(RAND(202) * @nb_adherents)   AS adherent_id,
               DATE('2021-01-04') + INTERVAL FLOOR(RAND(303) * 1700) DAY AS d,
               FLOOR(RAND(404) * 9) AS duree
          FROM chiffre c1, chiffre c2, chiffre c3,
               chiffre c4, chiffre c5, chiffre c6
         LIMIT 200000
       ) AS tirage;

DROP TABLE chiffre;

-- Les statistiques de l'optimiseur sont recalculées : sans cela, MySQL
-- raisonne encore sur une table de 130 lignes et choisit mal son plan.
ANALYZE TABLE emprunt;

SELECT COUNT(*) AS emprunts_total,
       SUM(date_retour_reelle IS NULL) AS encore_en_cours
  FROM emprunt;
