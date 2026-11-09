#!/usr/bin/env bash
# repro_baseline.sh — anclaje mínimo de la auditoría (Decred / dcrd)
#
# 1) Verifica que el fork auditado y decred/dcrd comparten commit y árbol.
# 2) Muestra la allowlist histórica de violaciones "same-block stake spend".
# 3) Localiza con file:line cada invariante de conservación de valor citado
#    en audit/INFORME-2026-11-09.md.
#
# Uso:  ./audit/repro_baseline.sh [ruta_al_clon_de_reference]
#       (por defecto /home/user/audit/upstream-dcrd, si existe)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-/home/user/audit/upstream-dcrd}"
EXPECT_COMMIT="46e9df48109a167c4a1b5e6fafc4a6926498e7c6"
EXPECT_TREE="78a0943fb6f417e96b8704c8a91ee83c5cdecdd3"

hr() { printf '%s\n' "------------------------------------------------------------"; }
ok() { printf '  [ OK ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; FAILED=1; }
FAILED=0

hr
echo "1) Anclaje de código (fork == fundación)"
hr
FORK_C="$(git -C "$REPO" rev-parse HEAD)"
FORK_T="$(git -C "$REPO" rev-parse 'HEAD^{tree}')"
echo "  fork  : commit $FORK_C tree $FORK_T"
[ "$FORK_C" = "$EXPECT_COMMIT" ] && ok "commit del fork coincide" || bad "commit del fork NO coincide"
[ "$FORK_T" = "$EXPECT_TREE" ] && ok "árbol del fork coincide" || bad "árbol del fork NO coincide"

if [ -d "$REF/.git" ] || git -C "$REF" rev-parse --git-dir >/dev/null 2>&1; then
  REF_C="$(git -C "$REF" rev-parse HEAD)"
  REF_T="$(git -C "$REF" rev-parse 'HEAD^{tree}')"
  echo "  ref   : commit $REF_C tree $REF_T"
  [ "$FORK_T" = "$REF_T" ] && ok "árbol idéntico a decred/dcrd (sin parche local)" \
                          || bad "el fork difiere de decred/dcrd"
else
  echo "  (sin clon de referencia en $REF — omitido; para regenerarlo:)"
  echo "    git clone https://github.com/decred/dcrd.git $REF"
fi

hr
echo "2) Allowlist histórica SBSS (same-block stake spend)"
hr
grep -n -A12 'sbssViolations = map\[int64\]\*chainhash.Hash{' "$REPO/internal/blockchain/validate.go" \
  | sed 's/^/  /'
echo "  Chequeo que rechaza el patrón (debe existir y no ser incondicional):"
grep -n -B2 -A8 'isStakeTx && utxoEntry.BlockHeight() == txHeight' "$REPO/internal/blockchain/validate.go" \
  | sed 's/^/  /'

hr
echo "3) Invariantes de conservación de valor (file:line esperado)"
hr
declare -a CHECKS=(
  "txscript/opcode.go:2436|OP_CHECKSIG verifica firma contra pubkey"
  "txscript/opcode.go:2560|OP_CHECKMULTISIG"
  "blockchain/standalone/tx.go:218|rechazo de inputs duplicados en una tx"
  "internal/blockchain/validate.go:950|rechazo de tx duplicadas en un bloque"
  "internal/blockchain/validate.go:2712|ticket: commitment + change == input"
  "internal/blockchain/validate.go:2991|redeemer paga al hash comprometido"
  "internal/blockchain/validate.go:3024|redeemer paga el monto comprometido"
  "internal/blockchain/validate.go:3102|vote stakebase == subsidy"
  "internal/blockchain/validate.go:3354|TSPEND valueIn == commitment"
  "internal/blockchain/validate.go:3601|fraud proof: ValueIn == amount del UTXO"
  "internal/blockchain/validate.go:3675|sólo vote/revocation gastan OP_SSTX"
  "internal/blockchain/validate.go:3685|OP_TADD no es gastable"
  "internal/blockchain/validate.go:3755|total in >= total out"
  "internal/blockchain/validate.go:4118|coinbase = workSubsidy(+fees) del variant activo"
  "internal/blockchain/validate.go:4163|treasurybase ValueIn == CalcTreasurySubsidy"
  "internal/blockchain/validate.go:4198|tope agregado de subsidy de votos"
  "internal/blockchain/validate.go:4315|TSPEND requiere votos"
  "internal/blockchain/validate.go:4329|gasto agregado TSPEND <= balance treasury"
  "internal/blockchain/subsidy.go:125|treasurybase output == subsidio exacto"
  "internal/blockchain/utxoviewpoint.go:618|addSBSSViolations (sólo alturas allowlist)"
  "internal/blockchain/utxoviewpoint.go:981|removeSBSSViolations (no persiste el output)"
  "internal/blockchain/utxocache.go:552|Commit del UTXO set desde la vista"
  "blockchain/standalone/subsidy.go:349|variantes de split (100 % en todas)"
  "chaincfg/mainnetparams.go:123|proporciones mainnet 6/3/1"
)
for entry in "${CHECKS[@]}"; do
  spec="${entry%%|*}"; desc="${entry#*|}"
  file="${spec%%:*}"; line="${spec##*:}"
  text="$(awk -v n="$line" 'NR==n' "$REPO/$file" 2>/dev/null | sed 's/^[[:space:]]*//')"
  if [ -n "$text" ]; then
    printf '  [ OK ] %-52s %s:%s\n         %s\n' "$desc" "$file" "$line" "$text"
  else
    printf '  [FAIL] %-52s %s:%s (vacío/ausente)\n' "$desc" "$file" "$line"
    FAILED=1
  fi
done

hr
if [ "$FAILED" -eq 0 ]; then
  echo "RESULTADO: anclaje OK. Código auditado == decred/dcrd ${EXPECT_COMMIT:0:8}."
else
  echo "RESULTADO: hay discrepancias — revisar antes de dar el veredicto por bueno."
fi
echo "Nota: este script NO toca la red de Decred; el estado live (altura, versión"
echo "      de binario, balances) requiere RPC y no está cubierto aquí."
hr
exit "$FAILED"
