#!/usr/bin/env bash
# verify_live_anchor.sh -- ancla el estado LIVE del stack Decred contra el código clonado.
#
# Requiere un dcrd con RPC habilitado (usuario/clave) y, opcionalmente, RPCs EVM.
# No se ejecutó dentro del sandbox de auditoría: el egress sólo permite
# github.com / codeload / api.github.com / npm / pypi, por lo que no hay
# conectividad a un nodo mainnet ni a un RPC de Ethereum/Base/Polygon.
#
# Uso:
#   DCRD_RPC=http://127.0.0.1:9109 DCRD_USER=u DCRD_PASS=p ./verify_live_anchor.sh
set -uo pipefail

DCRD_RPC="${DCRD_RPC:-http://127.0.0.1:9109}"
DCRD_USER="${DCRD_USER:-}"
DCRD_PASS="${DCRD_PASS:-}"

rpc() { # rpc <method> [params-json]
  curl -sS --max-time 20 -u "${DCRD_USER}:${DCRD_PASS}" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}" \
    "${DCRD_RPC}" | jq -c '.result // .error'
}

echo "== dcrd build / red / altura =="
rpc getinfo | jq -c '{version,protocolversion,network,blocks,connections}'
rpc getblockchaininfo | jq -c '{chain,blocks,bestblockhash,verificationprogress,initialblockdownload}'
rpc getbestblockhash
echo

echo "== agenda/despliegues activos (los que gatean reglas de consenso) =="
rpc getblockchaininfo | jq -c '.deployments // empty'

echo "== tesorería (inventario ajeno on-chain) =="
rpc gettreasurybalance '["current"]'
rpc gettreasurybalance '["pending"]'

echo "== parametros de red efectivos (deben coincidir con chaincfg/mainnetparams.go) =="
rpc getinfo | jq -c '{difficulty,testnet,relayfee}'
echo

echo "== muestra de bloque para corroborar reglas cableadas (votos, treasurybase) =="
best=$(rpc getbestblockhash | tr -d '"')
rpc getblock "$best" | jq -c '{height,tx:.tx|length,stake:.stx|length,votebits:.votebits,prevblockhash,finalstate}'
echo
echo "NOTA: si el nodo responde, comparar 'blocks' y 'bestblockhash' con el bloque"
echo "      citado en el informe; si no hay nodo accesible, el anclaje live queda BLOQUEADO."
