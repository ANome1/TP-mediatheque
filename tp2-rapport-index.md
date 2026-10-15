# TP2 — Rapport sur les index

Mesures faites sur la table `emprunt` (≈ 200 000 lignes), avec le script `tp2-03-index.sql`.

**Comment lire un `EXPLAIN` :**
- `type = ALL` : MySQL lit **toute la table** (lent).
- `type = ref` ou `range` : MySQL **utilise un index** (rapide).
- `rows` : le nombre de lignes que MySQL pense devoir lire (une estimation).

## Avant / après

### R1 — les emprunts d'une journée

```sql
SELECT * FROM emprunt WHERE date_emprunt = '2024-03-12';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | `ALL` | — | 199 875 | `Using where` |
| après | `ref` | `idx_emprunt_date` | 104 | — |

- Index : `CREATE INDEX idx_emprunt_date ON emprunt (date_emprunt);`
- Lignes renvoyées : **104**
- Conclusion : on lit 104 lignes au lieu de 200 000.

### R2 — les emprunts en cours

```sql
SELECT * FROM emprunt WHERE date_retour_reelle IS NULL;
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | `ALL` | — | 199 875 | `Using where` |
| après | `ref` | `idx_emprunt_retour` | 30 | `Using index condition` |

- Index : `CREATE INDEX idx_emprunt_retour ON emprunt (date_retour_reelle);`
- Lignes renvoyées : **30**
- Conclusion : on lit 30 lignes au lieu de 200 000.

### R3 — l'historique récent d'un adhérent

```sql
SELECT id, date_emprunt FROM emprunt
 WHERE adherent_id = 12 AND date_emprunt >= '2025-01-01';
```

| | `type` | `key` | `rows` | `Extra` |
|---|---|---|---|---|
| avant | `ref` | `fk_emprunt_adherent` | 5 070 | `Using where` |
| après | `range` | `idx_emprunt_adherent_date` | 741 | `Using where; Using index` |

- Index : `CREATE INDEX idx_emprunt_adherent_date ON emprunt (adherent_id, date_emprunt);`
- Lignes renvoyées : **741**
- **Pourquoi cet ordre ?** On met d'abord la colonne testée avec `=` (`adherent_id`), puis celle testée avec `>=` (`date_emprunt`). Les emprunts de l'adhérent 12 sont alors regroupés et triés par date : on lit directement les bons. Dans l'autre ordre, il faudrait parcourir les emprunts récents de **tous** les adhérents.

## Le préfixe gauche

| Requête | Le composite sert ? | Pourquoi |
|---|---|---|
| `WHERE adherent_id = 12` | **Oui** | `adherent_id` est la 1re colonne de l'index. |
| `WHERE date_emprunt >= '2025-01-01'` | **Non** (MySQL prend `idx_emprunt_date`) | `date_emprunt` n'est que la 2e colonne : seule, elle ne permet pas d'utiliser l'index. |

## L'index couvrant

- 1re requête (`adherent_id, date_emprunt`) : `Extra` affiche **`Using index`**.
- 2e requête (on ajoute `exemplaire_id`) : `Using index` disparaît. `exemplaire_id` n'est pas dans l'index, donc MySQL doit aller relire chaque ligne dans la table.

## La requête réécrite

```sql
-- avant : type = index, rows = 199 875 (tout l'index est lu)
SELECT COUNT(*) FROM emprunt WHERE YEAR(date_emprunt) = 2024;

-- après : type = range, rows = 22 203 (seule l'année 2024 est lue)
SELECT COUNT(*) FROM emprunt
 WHERE date_emprunt >= '2024-01-01' AND date_emprunt < '2025-01-01';
```

Les deux renvoient **43 015**. `YEAR()` oblige MySQL à calculer l'année de chaque ligne. Avec une plage de dates, il peut chercher directement dans l'index.

## Le prix des index

| | données (Mo) | index (Mo) |
|---|---|---|
| avant | 8,52 | 11,03 |
| après | 8,52 | 18,06 |

Conclusion : les index prennent environ 7 Mo de plus et ralentissent un peu les écritures. On n'en crée que pour des requêtes qui en ont besoin.
