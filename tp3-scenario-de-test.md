# TP3 — Scénario de test

Script : `tp3-04-tests.sql`. Base neuve, test fait le 2026-10-15.

| # | Ce que je fais | Attendu | Obtenu |
|---|---|---|---|
| T1 | Emprunter un exemplaire libre (`MED-00001`) pour un adhérent en règle (n°9) | emprunt créé | ✅ emprunt n°131, retour prévu à +14 jours, exemplaire indisponible, ligne dans l'historique |
| T2 | Emprunter le même exemplaire pour un autre adhérent | refus | ✅ `Emprunt refusé : cet exemplaire est déjà emprunté.` |
| T3 | Emprunter pour un adhérent inactif (n°7) | refus | ✅ `Emprunt refusé : l'inscription de cet adhérent n'est plus active.` |
| T4 | Emprunter le code `MED-99999` | refus | ✅ `Emprunt refusé : code-barres inconnu, aucun exemplaire ne porte ce code.` |
| T5 | 5 emprunts pour le même adhérent, puis un 6e | refus du 6e | ✅ `Emprunt refusé : quota atteint, 5 documents maximum par adhérent.` |
| T6 | Emprunter pour l'adhérent n°5, qui doit 12 € | refus | ✅ `Emprunt refusé : 12.00 € de pénalités impayées (10 € maximum).` |
| T7 | `INSERT` direct dans `emprunt`, sans dates | dates remplies, exemplaire indisponible | ✅ emprunté aujourd'hui, retour à +14 jours, exemplaire indisponible |
| T8 | Rendre un emprunt en retard (`MED-00107`) | pénalité créée | ✅ 72 jours de retard, soit **14,40 €** (72 × 0,20), exemplaire de nouveau disponible |
| T9 | Rendre le même exemplaire une 2e fois | refus | ✅ `Retour refusé : aucun emprunt en cours pour le code-barres MED-00107.` |

Tous les refus renvoient `ERROR 1644 (45000)`. Après un refus, aucune donnée n'est modifiée : la transaction est annulée.

## Conclusion

**1. Avec un `INSERT` direct (T7), qu'est-ce qui reste garanti, et qu'est-ce qui ne l'est plus ?**

> - **Garanti** (grâce aux triggers) : les dates (14 jours), l'exemplaire marqué indisponible, l'historique.
> - **Plus garanti** (règles de la procédure) : adhérent actif, exemplaire libre, quota de 5, pénalités.

**2. Quelle règle pourrait changer de place ?**

> « L'exemplaire doit être disponible » pourrait passer dans le trigger `BEFORE INSERT`. Même un `INSERT` direct ne pourrait plus prêter un exemplaire déjà sorti. Il faudrait alors retirer cette règle de la procédure, pour ne pas la vérifier deux fois.
