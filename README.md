# Médiathèque : TP1 à TP3 (SQL avancé, MySQL)

Trois TP sur la même base `mediatheque` (adhérents, livres, emprunts) :

1. **TP1** : qui a le droit de faire quoi (rôles et comptes).
2. **TP2** : des vues pour simplifier et protéger, et des index pour accélérer.
3. **TP3** : automatiser le prêt avec des fonctions, des procédures et des triggers.

Tout a été testé sur MySQL 8.0.

---

## Les fichiers

| Fichier | Contenu |
|---|---|
| `base-01-schema.sql` | Crée les tables (fourni) |
| `base-02-donnees.sql` | Remplit les tables (fourni) |
| `base-03-volume.sql` | Ajoute 200 000 emprunts, pour tester les index (fourni) |
| `tp1-01-roles-et-comptes.sql` | TP1 : rôles, comptes, droits |
| `tp1-matrice-de-tests.md` | TP1 : résultats des 12 tests |
| `tp2-01-vues.sql` | TP2 : les 4 vues |
| `tp2-02-vue-modifiable.sql` | TP2 : une vue où l'on peut écrire |
| `tp2-03-index.sql` | TP2 : les index |
| `tp2-rapport-index.md` | TP2 : mesures avant / après les index |
| `tp3-01-fonctions.sql` | TP3 : les 3 fonctions |
| `tp3-02-procedures.sql` | TP3 : emprunter, rendre, bilan |
| `tp3-03-triggers.sql` | TP3 : les 3 triggers |
| `tp3-04-tests.sql` | TP3 : les 9 tests |
| `tp3-scenario-de-test.md` | TP3 : résultats des 9 tests |
| `rejouer-tout.sh` | Lance tout dans l'ordre |

---

## Installation (Ubuntu / WSL)

```bash
sudo apt-get update
sudo apt-get install -y mysql-server
set +H     # évite que bash interprète le « ! » du mot de passe
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'Root!2026';"
printf '[client]\nuser=root\npassword=Root!2026\n' > ~/.my.cnf && chmod 600 ~/.my.cnf
```

Après un redémarrage de WSL : `sudo service mysql start`.

## Lancer les scripts

Tout d'un coup :

```bash
./rejouer-tout.sh            # sans les 200 000 emprunts
./rejouer-tout.sh --volume   # avec, pour la partie index du TP2
```

Ou un par un, dans cet ordre :

```bash
mysql < base-01-schema.sql
mysql < base-02-donnees.sql
mysql < tp1-01-roles-et-comptes.sql
mysql < tp2-01-vues.sql
mysql < tp2-02-vue-modifiable.sql
mysql < base-03-volume.sql        # seulement pour les index
mysql < tp2-03-index.sql
mysql < tp3-01-fonctions.sql
mysql < tp3-02-procedures.sql
mysql < tp3-03-triggers.sql
mysql < tp3-04-tests.sql
```

Chaque script peut être relancé sans erreur. Les commandes censées **échouer** sont en commentaire, avec l'erreur obtenue écrite en dessous.

---

## TP1 — Rôles et comptes

**But :** chaque utilisateur peut faire exactement ce dont il a besoin, et rien de plus.

| Compte | Peut | Ne peut pas |
|---|---|---|
| `app_media` (l'application) | lire le catalogue, gérer les prêts | supprimer, lire email ou téléphone |
| `biblio_marie` (bibliothécaire) | tout ce que fait l'application, plus gérer les adhérents | créer des comptes |
| `stagiaire` | lire le catalogue et les noms des adhérents | lire email, téléphone ou date de naissance, écrire |
| `analyste` | lire les emprunts et le catalogue | lire les adhérents, écrire |

**Comment :**
- 3 rôles : `role_catalogue` (lire le catalogue), `role_prets` (gérer les prêts) et `role_adherents` (gérer les adhérents).
- Des droits **par colonne** pour cacher les données personnelles.
- `SET DEFAULT ROLE ALL` pour activer les rôles à chaque connexion.

**Résultat :** les 12 tests donnent le résultat attendu (voir `tp1-matrice-de-tests.md`).
- `ERROR 1143` : refus sur une colonne.
- `ERROR 1142` : refus sur une table.
- `ERROR 1227` : action d'administration interdite.

Comptes : `app_media` / `AppMedia!2026`, `biblio_marie` / `Biblio!2026`, `stagiaire` / `Stagiaire!2026`, `analyste` / `Analyste!2026`.

---

## TP2 — Vues et index

### Les vues

| Vue | Ce qu'elle montre |
|---|---|
| `v_catalogue` | chaque livre avec son nombre d'exemplaires, dont les disponibles |
| `v_adherent_public` | les adhérents sans leurs données personnelles |
| `v_emprunt_en_cours` | les emprunts pas encore rendus |
| `v_retard` | les emprunts en retard (construite sur la vue précédente) |
| `v_adherent_lyon` | les adhérents de Lyon. On ne peut y ajouter **que** des Lyonnais (`WITH CHECK OPTION`) |

- Le stagiaire n'a plus accès aux tables, seulement aux vues. Ça fonctionne parce qu'une vue s'exécute avec les droits de son créateur.
- `v_catalogue` n'est pas modifiable, car elle contient des calculs (`COUNT`, `SUM`).

### Les index

| Requête | Sans index | Avec index |
|---|---|---|
| Emprunts d'une journée | 200 000 lignes lues | 104 |
| Emprunts en cours | 200 000 lignes lues | 30 |
| Historique d'un adhérent | 5 070 lignes lues | 741 |

- **Index à deux colonnes** `(adherent_id, date_emprunt)` : la colonne testée avec `=` se met en premier.
- **`YEAR(date) = 2024` empêche d'utiliser l'index.** On écrit plutôt `date >= '2024-01-01' AND date < '2025-01-01'`.
- **Coût** : les index prennent environ 7 Mo de plus.

Détails dans `tp2-rapport-index.md`.

---

## TP3 — Emprunter et rendre

**Règle de répartition :** une **règle métier** va dans une **procédure**. Ce qui doit **toujours** être vrai va dans un **trigger**.

| Élément | Rôle |
|---|---|
| `f_nb_emprunts_en_cours` | nombre de livres pas encore rendus |
| `f_penalites_dues` | montant des pénalités impayées (0.00 s'il n'y en a pas) |
| `f_jours_de_retard` | jours de retard d'un emprunt |
| `p_emprunter` | vérifie 4 règles (adhérent actif, exemplaire libre, 5 livres maximum, 10 € de dette maximum), puis crée l'emprunt |
| `p_rendre` | enregistre le retour et facture 0,20 € par jour de retard |
| `p_bilan_adherent` | la fiche d'un adhérent, ses emprunts en cours et son total d'emprunts |
| trigger `BEFORE INSERT` | fixe le retour prévu à +14 jours |
| trigger `AFTER INSERT` | marque l'exemplaire comme sorti et l'enregistre dans l'historique |
| trigger `AFTER UPDATE` | au retour, marque l'exemplaire comme disponible et l'enregistre dans l'historique |

**Résultat :** les 9 tests passent (voir `tp3-scenario-de-test.md`).
- Chaque refus affiche un message clair, par exemple « Emprunt refusé : quota atteint, 5 documents maximum par adhérent. »
- En cas d'erreur, rien n'est enregistré.
- Un retour avec 72 jours de retard est facturé 14,40 €.
