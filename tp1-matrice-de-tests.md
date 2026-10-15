# TP1 — Matrice de tests

Chaque test est lancé **connecté avec le compte concerné** :

```
mysql -u stagiaire -p mediatheque
```

## `app_media`

| # | Commande | Attendu | Obtenu |
|---|---|---|---|
| 1 | `SELECT id, nom, prenom FROM adherent LIMIT 5;` | OK | OK |
| 2 | `SELECT email FROM adherent LIMIT 1;` | refus | `ERROR 1143` |
| 3 | `UPDATE exemplaire SET disponible = 0 WHERE id = 3;` | OK | OK |
| 4 | `UPDATE exemplaire SET etat = 'use' WHERE id = 3;` | refus | `ERROR 1143` |
| 5 | `DELETE FROM emprunt WHERE id = 1;` | refus | `ERROR 1142` |

## `biblio_marie`

| # | Commande | Attendu | Obtenu |
|---|---|---|---|
| 6 | `SELECT nom, email, telephone FROM adherent LIMIT 3;` | OK | OK |
| 7 | `CREATE USER 'test'@'localhost' IDENTIFIED BY 'Test!2026';` | refus | `ERROR 1227` |

## `stagiaire`

| # | Commande | Attendu | Obtenu |
|---|---|---|---|
| 8 | `SELECT nom, prenom, ville FROM adherent LIMIT 5;` | OK | OK |
| 9 | `SELECT email FROM adherent LIMIT 1;` | refus | `ERROR 1143` |
| 10 | `SELECT * FROM adherent LIMIT 1;` | refus | `ERROR 1142` |

**Pourquoi 9 et 10 n'ont pas la même erreur ?**

> - **1143** = refus sur **une colonne** (`email`).
> - **1142** = refus sur **toute la table** : `*` demande toutes les colonnes, or le stagiaire n'en a que certaines.

## `analyste`

| # | Commande | Attendu | Obtenu |
|---|---|---|---|
| 11 | `SELECT COUNT(*) FROM adherent;` | refus | `ERROR 1142` |
| 12 | `SELECT COUNT(*) FROM reservation;` | OK après `GRANT`, refus après `REVOKE` | OK (8), puis `ERROR 1142` |

## Conclusion

**Quel compte peut encore faire quelque chose d'inutile ?**

> `app_media` peut modifier **toutes** les colonnes d'un emprunt, alors qu'il n'a besoin que d'enregistrer le retour.
> Correction : ne lui laisser que `UPDATE (date_retour_reelle)` sur `emprunt`.
