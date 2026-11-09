#!/usr/bin/env bash
# measure_inventory.sh -- mide el inventario ajeno que el stack Decred custodia
# on-chain y en contratos EVM usados por DCRDEX.
#
# Direcciones tomadas de los clones (no de memoria):
#   dcrdex @ fc63460615e8dca83fc19520f32a1cb00be4acfa
#     dex/networks/eth/params.go:75  ETHSwap  v0 mainnet 0x8C17e4968B6903E1601be82Ca989c5B5E2c7b400
#     dex/networks/eth/params.go:80  ETHSwap  v1 mainnet 0x82f29E3aCe0a0045c7b263Bf3198DA2210aD1670
#     dex/networks/eth/params.go:87  MultiBalanceV0     0x73bc803A2604b2c58B8680c3CE1b14489842EF16
#     dex/networks/base/params.go:83 BaseSwap v1 mainnet 0x85c4e942AE2729a3C61275d4ff90A245c81592ae
#     dex/networks/polygon/params.go:97,102,109 Polygon v0/v1/MultiBalance
#
# Uso:  ETH_RPC=... BASE_RPC=... POLYGON_RPC=... ./measure_inventory.sh
set -uo pipefail

evm_balance() { # evm_balance <rpc> <addr> <etiqueta>
  local rpc="$1" addr="$2" label="$3"
  local wei
  wei=$(curl -sS --max-time 20 -H 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"$addr\",\"latest\"]}" \
        "$rpc" | jq -r '.result // "error"')
  printf "%-40s %-44s %s wei\n" "$label" "$addr" "$wei"
}

echo "== ETH mainnet: contratos de swap DCRDEX (custodia in-flight) =="
evm_balance "${ETH_RPC:-}" 0x8C17e4968B6903E1601be82Ca989c5B5E2c7b400 "ETHSwap v0"
evm_balance "${ETH_RPC:-}" 0x82f29E3aCe0a0045c7b263Bf3198DA2210aD1670 "ETHSwap v1"
echo "   (los tokens ERC20 se custodian en un ERC20Swap por token; sus direcciones"
echo "    se derivan en dcrdex/dex/networks/erc20 y deben enumerarse con eth_getStorageAt)"
echo
echo "== Base mainnet =="
evm_balance "${BASE_RPC:-}" 0x85c4e942AE2729a3C61275d4ff90A245c81592ae "BaseSwap v1"
echo
echo "== Polygon mainnet =="
evm_balance "${POLYGON_RPC:-}" 0x74922db9f530b22d7ebea8e6920e256cf3cc0542 "PolygonSwap v0"
evm_balance "${POLYGON_RPC:-}" 0x8C4484ABb1E003e5dDE399aFbBa8B9369f45AE3D "PolygonSwap v1"
echo
cat <<'EOF'
== Inventario NO medible sólo con RPC de nodo (requiere índice/explorer) ==
  * ticket pool (stake): sumar valor de todos los UTXO OP_SSTX vivos.
  * DEX DCR/BTC/LTC/DOGE swaps: son P2SH generados por swap, sin dirección fija;
    se enumeran desde los funding txs (getrawtransaction + script classification).
  * dcrlnd: capacidad de canales custodiada por los propios nodos, no por la fundación.
  * dcrpool / vspd: custodia operador-específica (no hay dirección de protocolo fija).
EOF
