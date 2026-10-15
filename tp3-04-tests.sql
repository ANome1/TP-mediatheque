USE mediatheque;

SET @code = (SELECT code_barre FROM exemplaire
              WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);

SET @adherent = (SELECT id FROM adherent
                  WHERE actif = 1 AND f_nb_emprunts_en_cours(id) = 0 AND f_penalites_dues(id) = 0
                  ORDER BY id LIMIT 1);

SET @code_retard = (SELECT ex.code_barre
                      FROM emprunt em JOIN exemplaire ex ON ex.id = em.exemplaire_id
                     WHERE em.date_retour_reelle IS NULL AND em.date_retour_prevue < CURDATE()
                     ORDER BY em.date_retour_prevue LIMIT 1);

SELECT @code, @adherent, @code_retard;

-- T1
CALL p_emprunter(@code, @adherent, @id);
SELECT id, date_emprunt, date_retour_prevue FROM emprunt WHERE id = @id;
SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code;
SELECT operation, cle, details FROM journal_action ORDER BY id DESC LIMIT 1;

-- T2
-- CALL p_emprunter(@code, 1, @id);
--   ERROR 1644 : Emprunt refusé : cet exemplaire est déjà emprunté.

-- T3
-- CALL p_emprunter('MED-00119', 7, @id);
--   ERROR 1644 : Emprunt refusé : l'inscription de cet adhérent n'est plus active.

-- T4
-- CALL p_emprunter('MED-99999', 1, @id);
--   ERROR 1644 : Emprunt refusé : code-barres inconnu, aucun exemplaire ne porte ce code.

-- T5
CALL p_emprunter((SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1), @adherent, @id);
CALL p_emprunter((SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1), @adherent, @id);
CALL p_emprunter((SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1), @adherent, @id);
CALL p_emprunter((SELECT code_barre FROM exemplaire WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1), @adherent, @id);
SELECT f_nb_emprunts_en_cours(@adherent) AS en_cours;
-- CALL p_emprunter('MED-00119', @adherent, @id);
--   ERROR 1644 : Emprunt refusé : quota atteint, 5 documents maximum par adhérent.

-- T6
-- CALL p_emprunter('MED-00119', 5, @id);
--   ERROR 1644 : Emprunt refusé : 12.00 € de pénalités impayées (10 € maximum).

-- T7 : variable lue avant, car INSERT ... SELECT FROM exemplaire échoue (erreur 1442)
SET @libre = (SELECT id FROM exemplaire
               WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);
INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt, date_retour_prevue)
VALUES (@libre, 2, NULL, NULL);
SELECT id, date_emprunt, date_retour_prevue FROM emprunt WHERE id = LAST_INSERT_ID();
SELECT id, disponible FROM exemplaire WHERE id = @libre;

-- T8
CALL p_rendre(@code_retard);
SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code_retard;
SELECT adherent_id, montant, motif FROM penalite ORDER BY id DESC LIMIT 1;

-- T9
-- CALL p_rendre(@code_retard);
--   ERROR 1644 : Retour refusé : aucun emprunt en cours pour le code-barres MED-00107.
