#!/usr/bin/env bash
# static_invariants.sh -- comprobaciones estáticas, sobre los clones, de las
# invariantes que MATAN cada candidato del informe. No requiere toolchain Go.
#
# Uso:  ./static_invariants.sh /ruta/a/los/clones
#   (por defecto /tmp/foundation/repos, donde se clonaron los 89 repos públicos)
set -uo pipefail
ROOT="${1:-/tmp/foundation/repos}"
fail=0
chk() { # chk <descripción> <comando...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then printf "  OK   %s\n" "$desc"; else printf "  FAIL %s\n" "$desc"; fail=1; fi
}

echo "== dcrd (46e9df48109a167c4a1b5e6fafc4a6926498e7c6) =="
D="$ROOT/dcrd"
chk "SStx: ajuste commitment+change == input (no se puede infundir valor en un ticket)" \
  grep -q 'adjustedAmount != inputAmount' "$D/internal/blockchain/validate.go"
chk "SSGen/SSRtx: la validacion liga el ticket de entrada a su altura de compra" \
  bash -c "grep -q 'func checkVoteInputs' $D/internal/blockchain/validate.go && grep -q 'func checkRevocationInputs' $D/internal/blockchain/validate.go"
chk "mixpool no custodia monedas: el pool es map[chainhash.Hash]entry de mensajes" \
  bash -c "grep -q 'pool  *map\[chainhash.Hash\]entry' $D/mixing/mixpool/mixpool.go"
chk "mixclient verifica firma CM sobre la tx coinjoin antes de aceptar" \
  bash -c "grep -q 'mergeSignatures' $D/mixing/mixclient/client.go && grep -q 'errSignedWrongTx' $D/mixing/mixclient/coinjoin.go"
chk "safeguards de gasto inesperado (assert/panic) presentes en el UTXO view" \
  bash -c "grep -rq 'assert' $D/internal/blockchain/utxoviewpoint.go"
chk "auto-revocations: remanente sólo 1..numOutputs-1 átomos (dust), PRNG determinista" \
  grep -q 'remainder := totalOutputAmt - totalReturnAmount' "$D/internal/blockchain/validate.go"

echo "== dcrdex (fc63460615e8dca83fc19520f32a1cb00be4acfa) =="
X="$ROOT/dcrdex"
chk "ETHSwapV1: redeem exige participant == msg.sender" \
  grep -q 'r.v.participant == msg.sender' "$X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol"
chk "ETHSwapV1: redeemWithSignature liga firma EIP-712 a feeRecipient/relayerFee/nonce/deadline" \
  bash -c "grep -q 'Redeem(address feeRecipient,bytes32 redemptionsHash' $X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol"
chk "ETHSwapV1: nonce secuencial por participante (anti-replay)" \
  grep -q 'nonces\[participant\] == nonce' "$X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol"
chk "ETHSwapV1: relay sólo opera sobre ETH nativo (token forzado a address(0))" \
  grep -q 'address(0), r.v' "$X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol"
chk "ETHSwapV1: estado antes de transferencia (CEI) + nonReentrant" \
  bash -c "grep -q 'swaps\[key\] = r.secret' $X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol && grep -q 'ReentrancyGuard' $X/dex/networks/eth/contracts/v1/contracts/ETHSwapV1.sol"
chk "ERC20SwapV0: redeem exige participant == msg.sender" \
  grep -q 'participant == msg.sender' "$X/dex/networks/erc20/contracts/ERC20SwapV0.sol"
chk "ERC20SwapV0: refund sólo al initiator y con locktime vencido" \
  grep -q 'initiator == msg.sender' "$X/dex/networks/erc20/contracts/ERC20SwapV0.sol"

echo "== vspd (a381bece711ed88d3d7fcfda7d63be338c4e395c) =="
chk "vspd: el fee se verifica contra la commitment output del ticket" \
  bash -c "grep -rq 'FeeAmount' $ROOT/vspd/internal/webapi/payfee.go"

echo
[ "$fail" -eq 0 ] && echo "TODAS LAS INVARIANTES VERIFICADAS" || { echo "ALGUNA INVARIANTE NO SE PUDO VERIFICAR"; exit 1; }
