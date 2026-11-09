#!/usr/bin/env bash
# Determina QUE falta de verdad en el binario live.
#
# Leccion aprendida (importante): la rama release-v2.1 NO es un subconjunto de
# master. Casi todos los parches de master estan backporteados a release-v2.1
# con OTRO SHA y el prefijo "[release-v2.1] " en el asunto. Por tanto
# "commit solo-master" != "falta en el binario live". Hay que comparar
# (a) contenido de ficheros y (b) asuntos normalizados.
#
# No usar `git grep` ni `git cherry` sobre el mirror blobless: se cuelgan.
#
# Uso: ./30_delta_vs_live.sh /tmp/foundation/dcrd.git
set -euo pipefail
REPO="${1:-/tmp/foundation/dcrd.git}"
cd "$REPO"

LIVE=$(git rev-parse release-v2.1.7^{})
MASTER=$(git rev-parse master)
CONSENSUS_PATHS=(internal/blockchain blockchain/stake blockchain/standalone txscript wire internal/mempool)

echo "live   : $LIVE  $(git log -1 --format='%ci' $LIVE)"
echo "master : $MASTER"
echo

echo "== 1) diff de CONTENIDO en rutas de consenso (live vs master) =="
git diff --stat "$LIVE" "$MASTER" -- "${CONSENSUS_PATHS[@]}" | tail -40
echo

echo "== 2) asuntos de master que NO tienen backport en la rama release =="
git log --format='%s' "$LIVE".."$MASTER" -- "${CONSENSUS_PATHS[@]}" \
  | sed 's/^/MASTER\t/' | sort -u > /tmp/.master_subjects
git log --format='%s' "$MASTER".."$LIVE" -- "${CONSENSUS_PATHS[@]}" \
  | sed -e 's/^\[release-v2\.1\] //' -e 's/^/REL\t/' | sort -u > /tmp/.release_subjects
# normaliza: quita el prefijo y compara el resto del asunto
awk -F'\t' '{print $2}' /tmp/.release_subjects | sort -u > /tmp/.release_only
awk -F'\t' '{print $2}' /tmp/.master_subjects | sort -u > /tmp/.master_only
echo "--- en master y sin backport equivalente en release:"
comm -23 /tmp/.master_only /tmp/.release_only
echo

echo "== 3) ficheros de consenso con contenido distinto =="
git diff --name-only "$LIVE" "$MASTER" -- "${CONSENSUS_PATHS[@]}"
