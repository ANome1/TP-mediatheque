#!/bin/bash
# Usage : ./rejouer-tout.sh [--volume]
set -e
cd "$(dirname "$0")"

run() { echo "== $1"; mysql --table < "$1" > /dev/null; }

run base-01-schema.sql
run base-02-donnees.sql
run tp1-01-roles-et-comptes.sql
run tp2-01-vues.sql
run tp2-02-vue-modifiable.sql
if [ "$1" = "--volume" ]; then
  run base-03-volume.sql
  run tp2-03-index.sql
fi
run tp3-01-fonctions.sql
run tp3-02-procedures.sql
run tp3-03-triggers.sql
run tp3-04-tests.sql
echo "Chaîne complète rejouée sans erreur."
