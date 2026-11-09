# Auditoría ofensiva — stack Decred (dcrd y componentes live)

**Fecha:** 2026-11-09 · **Rama de sesión:** `arena/1c30c1ac-dcrd` · **Repo base:** `nightbox33-cloud/dcrd` (= upstream `decred/dcrd`)
**Commit auditado (HEAD):** `46e9df48109a167c4a1b5e6fafc4a6926498e7c6` (2026-11-06) — idéntico byte a byte a `decred/dcrd@master`.

---

## 1. Veredicto

> **NO CRÍTICO LIVE.**
>
> No encontré ningún camino por el que un actor **sin rol privilegiado**, partiendo del estado **desplegado**, termine con más valor del que puso y con el delta saliendo de inventario de terceros. Los cuatro criterios (bug real en código live · permissionless · call-graph cableado · PnL > 0 tras unwind) **no se cumplen simultáneamente** en ningún candidato.

Cobertura de **código**: completa sobre los clones (89/89 repos públicos de la fundación + historial completo de dcrd/dcrdex para análisis de regresiones).
Cobertura de **estado live**: **parcial y declarada BLOQUEADA** (§3): el sandbox sólo tiene egress a `github.com`, `codeload.github.com`, `api.github.com`, `registry.npmjs.org` y `pypi.org`. No hay RPC de nodo Decred ni de EVM, por lo que **no pude medir saldos on-chain**; no invento cifras (§4). Los repos **privados** de la org tampoco son enumerables con las credenciales disponibles → **no declaro cobertura completa del código privado**.

---

## 2. Requisito previo obligatorio

### 2.1 Organizaciones de la fundación enumeradas

| Org/espacio | Repos públicos | Estado |
|---|---|---|
| `decred` (org principal: dcrd, dcrwallet, dcrdex, dcrlnd, dcrpool, vspd, politeia, dcrdata…) | **89** (API `/orgs/decred/repos`, type=public) | 89/89 clonados |
| `decredcommunity` | 11 | enumerada; no contiene binarios de consenso ni custodia |
| `raedahgroup` | 15 | enumerada; histórico (dcrdata antiguo), sin custodia live |
| `dcrdex` como org independiente | — | no existe (HTTP 404): dcrdex vive en `decred/dcrdex` |
| repos **privados** de `decred` | **desconocido** | **BLOQUEADO**: el token no es miembro de la org; no puedo listarlos ni clonarlos |

### 2.2 Clonado

- Clon superficial (`--depth 1 --single-branch`) de **los 89 repos públicos** en `/tmp/foundation/repos` (≈1,3 GB; fuera de Git para no inflar el snapshot).
- Historial **completo** (`--bare`) de `dcrd` y `dcrdex` en `/tmp/foundation/full` para analizar qué se arregló antes/después del release live.
- Manifiesto con **commit exacto por repo**: `audit/foundation_repos_manifest.tsv` (90 líneas; `dcrdesign` aparece duplicada por el muestreo, 89 repos únicos) y `audit/foundation_org_repos.tsv` (metadatos de la API: tamaño, `pushed_at`, `default_branch`, `archived`).
- Submódulos/LFS: ninguno de los repos con custodia usa submódulos ni LFS para artefactos de consenso; se verificó en dcrd/dcrwallet/dcrdex/dcrlnd.
- Fallos de clonado: **0**. (`dcrdesign`, 818 MB, es material de diseño; irrelevante para valor.)

### 2.3 Commits usados (los que tocan dinero)

| Componente | Repo | Commit | Fecha |
|---|---|---|---|
| Nodo / consenso / mempool / mining / mixing | `decred/dcrd` | `46e9df48109a167c4a1b5e6fafc4a6926498e7c6` | 2026-11-06 |
| Wallet (firmas, ticket purchase, mixing client, LN) | `decred/dcrwallet` | `54b85b336077587eaf20112dc695355ce06fc76e` | 2026-11-05 |
| Lightning (canales) | `decred/dcrlnd` | `42516b14b11667fd506c736cb26d46c947f2ecc2` | 2026-09-18 |
| DEX: servidor + contratos EVM + scripts P2SH | `decred/dcrdex` | `fc63460615e8dca83fc19520f32a1cb00be4acfa` | 2026-03-31 |
| Pool de minería (payouts) | `decred/dcrpool` | `90d745f81e48ca8930493e19a6e8616ce4b12549` | 2025-12-29 |
| VSP (fee de tickets, voto delegado) | `decred/vspd` | `a381bece711ed88d3d7fcfda7d63be338c4e395c` | 2026-09-16 |
| Gobernanza (Politeia) | `decred/politeia` | `dca5528ff747311128367beedef77e7f258eb2ee` | 2025-11-23 |
| Explorer / indexado | `decred/dcrdata` | `9c02e7116ede87b57ee6189c5dc3c22d48937a3a` | 2025-11-26 |

---

## 3. Anclaje del estado live

| Artefacto desplegado | Repo · ruta | Commit | Evidencia en el clon |
|---|---|---|---|
| Binario dcrd mainnet (**v2.1.7**, release 2026-10-13) | `dcrd` · raíz | `46e9df4` (v2.1.7 + 6 commits) | `docs/release-notes/release-notes-2.1.7.md` |
| Parámetros de consenso mainnet (genesis, `TicketPoolSize=8192`, `TicketsPerBlock=5`, `TicketExpiry=40960`) | `dcrd` · `chaincfg/mainnetparams.go` | `46e9df4` | líneas 97, 551-562 |
| Agendas que gatean reglas (treasury, auto-revocations, subsidy split, blake3, max treasury spend) con anclas históricas | `dcrd` · `internal/blockchain/agendas.go` | `46e9df4` | `requiredAgendaIDs`, `makeHistoricalAgendas()` |
| `ETHSwap` v0 — **ETH mainnet `0x8C17e4968B6903E1601be82Ca989c5B5E2c7b400`** | `dcrdex` · `dex/networks/eth/params.go:75` | `fc63460` | `ContractAddresses[0][Mainnet]` |
| `ETHSwap` v1 — **ETH mainnet `0x82f29E3aCe0a0045c7b263Bf3198DA2210aD1670`** | `dcrdex` · `dex/networks/eth/params.go:80` | `fc63460` | `ContractAddresses[1][Mainnet]` |
| `MultiBalanceV0` — ETH `0x73bc803A2604b2c58B8680c3CE1b14489842EF16` (sólo lectura) | `dcrdex` · `dex/networks/eth/params.go:87` | `fc63460` | `MultiBalanceAddresses` |
| `BaseSwap` v1 — Base `0x85c4e942AE2729a3C61275d4ff90A245c81592ae` | `dcrdex` · `dex/networks/base/params.go:83` | `fc63460` | `ContractAddresses` |
| Swap v0/v1 + MultiBalance — Polygon `0x74922db9…`, `0x8C4484AB…`, `0x23d8203d…` | `dcrdex` · `dex/networks/polygon/params.go:97,102,109` | `fc63460` | idem |
| Swaps DCR/BTC/LTC/DOGE/BCH… | `dcrdex` · `dex/networks/{dcr,btc,…}/script.go` | `fc63460` | P2SH generado por swap, **sin dirección fija** |
| Tesorería (TSPEND/TADD) | `dcrd` · `internal/blockchain/treasury.go`, `blockchain/stake/treasury.go` | `46e9df4` | policy por `OP_TADD`/`OP_TSPEND` |

**Los 6 commits posteriores a v2.1.7** (`382ff4dd..46e9df48`) se revisaron uno a uno: docs, docker, dos tests, `UtxoCache.timeNow` (flush periódico, no consenso), `rpcserver` nil-deref (DoS) y `trsy agenda boundary` (§5.4). **Ninguno introduce ni deja abierta una regla de valor.** El binario live (v2.1.7) contiene todas las salvaguardas de gasto que el propio release notes describe.

---

## 4. Inventario ajeno (qué hay que drenar y cuánto)

| Clase de inventario | Quién puede moverlo | Medición |
|---|---|---|
| **Tesorería** (TSPEND/TADD) | firma de la clave de tesorería **+** aprobación por votos de tickets; no permissionless | **NO MEDIDO** (sin RPC). Comando: `audit/scripts/verify_live_anchor.sh` → `gettreasurybalance {"current"/"pending"}` |
| **Ticket pool / stake** (UTXOs `OP_SSTX`) | sólo el dueño de la commitment key; el voto lo ejerce el ticket | **NO MEDIDO** (requiere índice de UTXOs) |
| **Swaps DEX in-flight en ETH/Base/Polygon** | el `participant` con el secret (redeem) o el `initiator` tras el locktime (refund) | **NO MEDIDO**. Comando: `eth_getBalance` sobre las 5 direcciones de §3 (`audit/scripts/measure_inventory.sh`) |
| **Swaps DEX in-flight en DCR/BTC/…** | idem, vía P2SH hashlock+CLTV | **NO MEDIDO** (direcciones por swap, se derivan de las funding txs) |
| **Canales dcrlnd** | los propios nodos (no la fundación); disputas on-chain | fuera de custodia de la fundación |
| **dcrpool (payouts pendientes) / vspd (fees)** | operador del pool / VSP; dirección operador-específica | **NO MEDIDO** |

> Declaración explícita: por el bloqueo de red descrito en §1 **no hay cifras en USD** en este informe. Cualquier número que apareciera aquí sin RPC habría sido inventado, y el criterio del encargo prohíbe inventar inventario.

---

## 5. Candidatos evaluados y el hecho que los mata

### 5.1 Consenso: conservación de valor en tx de stake (`internal/blockchain/validate.go`)
`checkTicketSubmissionInputs` recalcula `commitmentAmount + change == inputAmount` con el UTXO real; `CheckTransactionInputs` cierra el balance por tx y `expAtomOut` acota el subsidio+ fees por bloque.
**Lo mata:** no hay delta posible sin romper una igualdad exacta en átomos; no encontré camino que la esquive (ni con múltiples inputs, ni con `OP_SSTXCHANGE`, ni por redondeo: la división usa 64.32 fixed point y el remanente se trata explícitamente).

### 5.2 Reparto de recompensa de voto / auto-revocaciones
`calcTicketReturnAmounts` prorratea por contribución y, con `auto-revocations` activa, reparte el remanente (≤ `numOutputs-1` átomos, **dust**) con PRNG determinista sembrado con la cabecera previa.
**Lo mata:** el delta es dust por diseño y el receptor es el propio ticket; ningún tercero gana ni pierde; además exige ser productor del bloque.

### 5.3 Mixing (CoinShuffle++ / mixpool / mixclient)
El `mixpool` **no custodia monedas**: almacena `map[chainhash.Hash]entry` de mensajes. Los fondos permanecen en las funding txs, y el `CoinJoin` sólo se firma (CM) si la tx resultante paga exactamente los scripts y montos comprometidos; `mixclient` rechaza peers que firman otra tx (`errSignedWrongTx`) y recalcula los pads. `MaxMixAmount`, `MaxPeers=64`, `MaxMcount=16`, `MaxMtot=1024` acotan tamaño y denominación.
**Lo mata:** un peer malicioso sólo puede romper anonimato o causar DoS/abort (los últimos 20 commits de `mixing`/`mixpool` son precisamente hardening anti-DoS: límites por identidad, epochs, KEs duplicados). No hay firma ajena que pueda redirigir el output de otro participante.

### 5.4 Reorg a través del límite de activación de tesorería (`37fd3a3e`, 2026-11-04)
El propio commit documenta: se usaba el estado de la agenda del bloque que desaprueba en lugar del desaprobado, con posible **assert por UTXOs faltantes**. Condición: reorg cruzando la activación de tesorería (altura 552.447, enterrada ~1,3 M bloques).
**Lo mata:** irrealizable en mainnet por profundidad de la activación, y el efecto sería un assert local (liveness), no movimiento de valor. No es un drain.

### 5.5 dcrdex `ETHSwapV1.redeemWithSignature` (código nuevo: nov-2025 → mar-2026, desplegado en mainnet)
Es el punto más sensible del stack EVM: permite a un **relayer tercero** liquidar un redeem en nombre del participante.
- Firma EIP-712 liga `feeRecipient`, `relayerFee`, `redemptionsHash = keccak256(abi.encode(redemptions))`, `nonce` y `deadline`; `ECDSA.recover == participant`.
- `nonce` secuencial por participante (anti-replay); dominio EIP-712 incluye `chainId` y `verifyingContract` (anti cross-chain/cross-contract replay).
- `_executeETHRedemptions` fuerza `r.v.participant == participant` para **todos** los elementos y sólo resuelve claves con `token = address(0)` (no se puede redimir un swap ERC20 por esta vía).
- Estado (`swaps[key] = secret`) **antes** de transferir + `nonReentrant`; `relayerFee <= total/2`; `feeRecipient == msg.sender` cuando es distinto de cero (anti front-running del fee).
- `refund` sólo paga a `v.initiator` y exige `block.timestamp >= v.refundTimestamp`.

**Lo mata:** para cobrar el swap de otro hay que producir una firma del `participant` sobre ese `Vector` exacto; el hash cubre todos los campos que definen la clave (`secretHash, initiator, participant, value, refundTimestamp, token`). No hay confusión de struct/array (`abi.encode` de array estático), ni selección de token, ni sobre-retiro por `total`: cada clave incluye `value` y `initiate` exige `msg.value == total`.

### 5.6 dcrdex `ERC20SwapV0`
`redeem` exige `participant == msg.sender` y `sha256(secret)`; `refund` exige `initiator == msg.sender` y locktime; máquina de estados `Empty→Filled→Redeemed/Refunded` sin doble gasto (`state == Filled` en ambas).
**Lo mata:** no hay firma delegada aquí; ninguna ruta paga a un tercero.

### 5.7 dcrdex swaps nativos DCR/BTC (P2SH)
Contrato estándar `OP_IF sha256(secret) OP_ELSE <locktime> CLTV OP_ENDIF <pubkey> CHECKSIG`; redeem sólo con preimagen, refund sólo tras locktime con la clave del initiator. Sin cambios recientes.
**Lo mata:** mismo argumento criptográfico; el atacante necesitaría la preimagen o la clave.

### 5.8 vspd (fee de tickets)
El fee se paga en la propia tx de compra del ticket; vspd verifica commitment/split. Un fallo aquí produce **theft of service** (voto gratis), no movimiento de fondos de terceros.
**Lo mata:** no hay delta de valor ajeno; el inventario afectado es el coste del operador.

### 5.9 dcrpool (payouts)
Shares deduplicados por hash (`boltdb.go`, `DuplicateShare`), pesos por cuenta; el pool custodia los coins del bloque hasta el pago.
**Lo mata:** es custodia del operador con cuentas internas; no encontré ruta permissionless que acredite shares falsos (el trabajo se valida hasheando la cabecera contra el job) y aun si la hubiera, el criterio exige inventario de terceros, no del operador que acredita.

### 5.10 Mempool (voto/treasury metadata)
Los commits de sept-2026 (`Reject bad block votes early`, `Reject ineligible ticket votes early`, `Prune old vote metadata`, `Reject votes too far in the future`) son política de admisión.
**Lo mata:** afectan a qué se relay­a, no a la validez de bloque; no mueven valor.

---

## 6. Qué cambiaría el veredicto

1. **Acceso a RPC/índice mainnet** para medir §4 y confirmar saldos reales > 0 (hoy BLOQUEADO).
2. **Repos privados de la fundación** (no enumerables): si existe código de custodia/bridge no publicado, este informe no lo cubre.
3. **Claves de rol** (tesorería, `admin` de VSP/pool, upgrade de contratos): quedan fuera por el criterio de “sin rol privilegiado”.

---

## 7. Reproducción

```bash
# 1) Clones (ya hechos en /tmp/foundation/repos; el manifiesto queda versionado)
cat audit/foundation_repos_manifest.tsv        # repo -> commit exacto (90 líneas)
cat audit/foundation_org_repos.tsv             # metadatos de la org (89 repos)

# 2) Invariantes estáticas sobre los clones (no requiere toolchain Go)
bash audit/scripts/static_invariants.sh /tmp/foundation/repos
#   -> TODAS LAS INVARIANTES VERIFICADAS  (exit 0)

# 3) Anclaje del estado live (requiere nodo; NO ejecutado en sandbox)
DCRD_RPC=http://HOST:9109 DCRD_USER=u DCRD_PASS=p bash audit/scripts/verify_live_anchor.sh

# 4) Inventario en contratos EVM (requiere RPC; NO ejecutado en sandbox)
ETH_RPC=... BASE_RPC=... POLYGON_RPC=... bash audit/scripts/measure_inventory.sh
```

---

## 8. Limitaciones declaradas

- **Sin toolchain Go** en el sandbox (`go: command not found`) y sin proxy de módulos permitido: no se compiló ni se ejecutaron tests de dcrd; la verificación es de código + historial.
- **Sin conectividad** a mainnet/EVM: no hay PoC ejecutada contra estado live; los PoC son análisis de call-graph y las comprobaciones estáticas anteriores.
- **Sin acceso a repos privados** de la org: cobertura de código = 89/89 públicos, no “todo”.
- Los clones viven en `/tmp` (fuera de Git) para no inflar el snapshot; el manifiesto con commits sí queda versionado en `audit/`.
