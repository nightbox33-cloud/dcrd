# Auditoría ofensiva — fundación Decred (dcrd / dcrdex / dcrpool / dcrwallet)

Fecha: 2026-11-09 · Rama: `arena/594e9b1c-dcrd` · Base: `46e9df48109a167c4a1b5e6fafc4a6926498e7c6`

## VEREDICTO

**No crítico live.**

Ningún hallazgo pasa los 4 criterios. Lo que existe son (a) deltas release-vs-master que son
*defensivos* o *inalcanzables*, y (b) tres **panics remotos / DoS** en componentes live
(dcrwallet SPV, dcrpool) que **no drenan fondos de terceros** ⇒ quedan explícitamente fuera
del criterio de criticidad por la regla "DoS/liveness sin robo no es crítico".

---

## 1. Requisito previo: cobertura (NO completa — declarada)

| Espacio | Estado | Evidencia |
|---|---|---|
| GitHub `decred/*` | **89/89 clonados** (mirror blobless), SHA por repo en `clones.tsv` | `gh repo list decred` = 89, `isPrivate`=0, 5 archivados |
| GitHub repos privados | **0 accesibles** (la org no reporta privados a este token) → *bloqueado* | `orgs/decred.public_repos=89`, `total_private_repos=null` |
| Submódulos | 1 sin auditar: `btcpayserver-decred-plugin` → `submodules/btcpayserver` | `.gitmodules` |
| Git LFS | 0 repos con `filter=lfs` | `git for-each-ref` + `.gitattributes` |
| GitLab / Bitbucket / Gitea / Codeberg | **sin egress** (HTTP 000) → **bloqueado** | curl a `/api/v4/version` y raíces |
| Espacios personales de maintainers | **no clonados** (davecgh 63, jrick 85, jholdstock 70, dnldd 22 repos) | `users/<login>.public_repos` |
| Orgs inexistentes | `dcrdevs`, `decred-community`, `decredproject` → 404 | `gh api orgs/...` |

**No se declara cobertura completa.** Fuente de verdad usada: clones (nunca memoria/explorer).

## 2. Artefacto desplegado auditado

- `decred/dcrd` tag `release-v2.1.7` (objeto anotado `25542c1d`) → commit **`e07b5655`**
  ("release: Bump for 2.1.7", 2026-10-13). `release-v2.1` apunta al **mismo** commit.
- `go.mod` del tag fija: `blockchain/v5 v5.1.1` (=`e201209e`, padre `a38c0195`),
  `blockchain/stake/v5 v5.0.3` (=`7e3dd854`), `blockchain/standalone/v2 v2.3.0` (=`59e2c9d3`),
  `mixing v0.7.5` (=`46fc30ad`), `wire v1.8.0`, `txscript/v4 v4.1.2`, `database/v3 v3.0.3`.
- `decred-binaries` tag `v2.1.7` = `00edad64`; sus release notes declaran
  "Critical consensus-related security fix" y "Upgrade Mandatory".
- dcrwallet live: `release-v2.1` = `599b5850` ("Bump version to 2.1.7+release.local").
- dcrdex: `fc634606` (2026-03-31). dcrpool: `90d745f8` (2026-01-28). vspd: `a381bece`.

## 3. Mapa dirección / artefacto → repo + ruta + commit

| Artefacto | Valor live | Repo · ruta · commit |
|---|---|---|
| Tesorería / block-tax (P2SH org) | `a914f5916158e3e2c4551c1796708db8367207ed13bb87` = **`Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx`** | dcrd · `chaincfg/mainnetparams.go:571` · `e07b5655` |
| Claves sancionadas de tesorería (PiKeys) | `03f6e7041f…946c`, `0319a37405…86dd` | dcrd · `chaincfg/mainnetparams.go:576` · `e07b5655` |
| Premine bloque 1 | 3146 payouts × 5000 DCR = **1.680.000 DCR** | dcrd · `chaincfg/subsidytables.go:7` · `e07b5655` |
| Params de consenso | `CoinbaseMaturity=256`, `TicketMaturity=256`, `SVH=4096`, `TVI=288`, `TreasuryVoteIntervalMultiplier=12`, `TreasuryExpenditureWindow=2`, `Policy=6`, `Bootstrap=16000 DCR`, `MaxTAddsPerBlock=20` | dcrd · `chaincfg/mainnetparams.go`, `internal/blockchain/validate.go` · `e07b5655` |
| Agendas activas | `maxtreasuryspend` (DCP0013) passed/activa, vote version 11; también DCP0012, DCP0011, DCP0009, DCP0007, DCP0006 | dcrdata `/agendas` (solo como estado, no como fuente de código) |

Decodificador reproducible: `scripts/10_address_decode.py` (Base58Check con doble BLAKE-256).
Verificado cruzando una P2PKH conocida on-chain (`DsWkaiN8…`).

## 4. Inventario medido (script reproducible, no explorer)

`scripts/20_supply_replica.py` lee la tabla del premine del propio clone y replica
`CalcBlockSubsidy` + reparto DCP0010/DCP0012:

```
premine: 3146 payouts, 1680000.00000000 DCR
emitido 2..1130871: 16257551.38888827 DCR
supply incl. premine: 17937551.38888827 DCR
bloque 1130871: pow 0.04999928 | pos 4.44993525 (voto 0.88998705) | tesoreria 0.49999272
```

Los tres valores del bloque 1130871 **coinciden exactamente** con dcrdata ⇒ el modelo de
reparto está validado.

**Caveat de medición (importante):** dcrdata `/api/supply` devuelve
`supply_mined = 17.683.290,08033202` y `supply_ultimate = 20.999.999,9839432`.
`supply_mined` **no reconcilia** con mi réplica (Δ = 1.425.738,69 DCR sobre lo emitido, y
254.261,31 DCR por debajo de emitido+premine). Su SQL (`dcrdata`,
`db/dcrpg/internal/vinoutstmts.go:SelectCoinSupply`) suma `vins.value_in` con prev-hash nulo
para `tx_type IN (0,2,6)` y depende del parámetro de altura inicial, e incluye filas de ramas
laterales por la condición `(is_valid OR tx_tree != 0)`. **Conclusión: el "total coin supply"
público no sirve como inventario**; usar la suma de subsidios del clone.

Nota de honestidad: la constante que el propio repo se auto-verifica
(`blockchain/standalone/subsidy_test.go:1110` → `2099999999800912` atoms = 20.999.999,998
DCR) y el valor geométrico del subsidio (≈21.038.383 DCR con premine) difieren en ~38 k DCR.
Eso es contabilidad de truncamiento, **no** una vía de inflación: todas las vías de creación
de valor están cerradas (ver §5). Cualquier afirmación anterior de "38 k sobre el cap ⇒ bug"
**queda retirada**.

## 5. Vías de creación de valor: cerradas (con código del tag)

| Vía | Resultado |
|---|---|
| Stake tx gastando output del mismo bloque (SBSS) | Cerrada. `851ca169` (backport en la rama release) + `a38c0195` (módulo). Rechazo explícito `utxoEntry.BlockHeight() == txHeight` para `isStakeTx`, con 6 excepciones históricas hardcodeadas (`sbssViolations`: 1106817/1106831/1106837/1106854/1106860/1107195 + hash exacto de bloque). |
| Carried-forward fees del stake tree | Sin exploit. `checkTransactionsAndConnect`: `totalFees := int64(inputFees)`, y el `else { expAtomOut = totalFees }` (presente en live, eliminado en master) **solo aplica por debajo de `StakeValidationHeight`=4096** ⇒ historia. Además el agregado `totalAtomOutStake <= voteSubsidy*voters` y `checkStakeBaseAmounts` acotan por voto. |
| Treasurybase / TSpend creando UTXOs | Cerrado. `connectStakeTransaction`: treasurybase no añade ni gasta; TSpend no gasta inputs y añade outputs. `CheckTSpend` exige versión treasury, 1 input, ≥2 outputs, script exacto de 100 bytes (offsets 0/65/99), pubkey comprimida estricta, `OP_RETURN`+32B en out0 y `OP_TGEN` en el resto. |
| Política de gasto DCP0013 | Aplicada. `maxTreasuryExpenditureDCP0013`: `maxSpendable=(balance+spentRecent)*4/100`, floor `treasurySpendLimitFloor`, y cap final a `treasuryBalance`; `checkTSpendsExpenditure` rechaza balance negativo y `total > allowedToSpend`. |
| Revocaciones / tickets | Cerrado. `autorevocations` activa ⇒ el bloque **debe** incluir revocación de cada ticket missed/expirado (`ErrNoMissedTicketRevocation`/`ErrNoExpiredTicketRevocation`); `numRevocationPayments*2 != len(ticketOuts)-1` → `ErrBadNumPayees`; pagos atados a los commitments (`ErrMismatchedPayeeHash`, `ErrBadPayeeValue`) y fee forzado a 0 en revocaciones v≥2. |
| Voto apuntando a otro bloque | Cerrado. `votedHash != header.PrevBlock || votedHeight != header.Height-1` → `ErrVotesOnWrongBlock`; stakebase `ValueIn != CalcStakeVoteSubsidyV3(heightVotingOn)` → `ErrBadStakebaseAmountIn`. |
| Scripts: se salta coinbase por `PreviousOutPoint.Index == MaxUint32` | No explotable: TSpend/treasurybase ya validan firma fuera del script engine (`stake.CheckTSpend` + PiKeys) y el treasurybase se valida por `ValueIn` contra `CalcTreasurySubsidy`. |
| tickettreap `getByIndex` (`idx >= size`) | Inalcanzable: `lottery.go fetchWinners` valida `idx < 0 \|\| idx >= t.Len()` antes. El backport `7e1d0d00` **sí está** en el árbol live. |

## 6. Deltas release-vs-master auditados (ninguno crítico)

| Commit (master) | Qué es | ¿En live? | Por qué no es crítico |
|---|---|---|---|
| `9112e4e6` Remove incorrect cache assertion | Quita `AssertError` en `UtxoCache.spendEntry` cuando la entrada ya está gastada | **NO** | Escenario real: un *disapproval* deshace un gasto no flusheado y el mismo output se re-gasta en el bloque que desaprueba. En live ⇒ **panic del nodo** (assert). Es DoS, no robo; falla criterio "drena terceros". |
| `2115b56b` Consolidate zero conf tx detection | Reescribe `zeroConfOuts`/`addRegularInputUtxos` | **NO** | Live ya acota: `i >= inFlightIdx`, memoiza `!view.hasAnyRegularTxOut`, y solo evita commitear zero-conf al caché. No crea UTXOs. |
| `96a55a74` Improve stake spend violation handling | Generaliza las violaciones SBSS | **NO** | Live ya las cierra con `851ca169`; master solo mejora la gestión/asserts. |
| `37fd3a3e` Correct trsy agenda boundary | Reorg a través del límite de activación de tesorería con bloque desaprobado usa el estado de agenda equivocado | **NO** (2026-11-04) | El propio autor: "no realistic way to encounter … buried extremely deep in chain history". Requiere reorg en ~altura 1.0M+; resultado sería assert, no robo. |
| `63b6677c` / `e0eaa8fd` / `1364adc8` / `04bbebde` | Rechazo temprano de `ValueIn` absurdos y de input de revocación nulo | **SÍ** están (backports) | Verificado en el árbol live: `standalone/tx.go` (bloque "Input values in the fraud proof…") y `validate.go:482/500` (`vote/revocation ticket input refers to null previous output`). |
| `560d1c5f` Unsigned treasury vote counts | Contadores `int`→`uint32` | **NO** | El propio commit: "not an active issue"; cota real << 2^31. |
| `036b7090` tickettreap off-by-one | `>` → `>=` | **SÍ** (backport `7e1d0d00`) | Inalcanzable de todos modos. |
| `mixing/` (v0.7.5 vs master) | Solo `mixclient/blame.go`/`client.go` (endurecimiento de blame) | live = v0.7.5 | dcrd solo importa `mixing/mixpool` (`server.go:50`); `mixclient` es de wallet. Impacto: griefing/deanonimización, no valor. |

Herramienta: `scripts/30_delta_vs_live.sh` (no usa `git grep`/`git cherry`, que se cuelgan en
el mirror blobless). Lección clave incorporada al script: **la rama `release-v2.1` no es
subconjunto de master**; casi todo master está backportado con otro SHA y prefijo
`[release-v2.1]`, así que "commit solo-master" ≠ "falta en el binario".

## 7. Hallazgos vivos reales — pero NO críticos (no drenan terceros)

### 7.1 dcrwallet SPV: panic remoto por header con `Height = 0` (untrusted peer)
- Live: `dcrwallet` `release-v2.1` @ `599b5850`, `wallet/difficulty.go:validateHeaderChainDifficulties`:
  ```go
  if parent == nil && h.Height != 0 {   // ← un header con Height==0 deja parent == nil
      ...
  }
  err := w.checkDifficultyPositional(dbtx, h, parent, chain)  // parent nil ⇒ deref
  ```
  Llamado desde `spv/sync.go:1479` con cabeceras que llegan de **cualquier peer SPV**.
- Fix en master: `abb367b4` (2026-11-03) "a malicious SPV peer to deliberately send a header
  with height 0 and crash the wallet"; **no** está en `release-v2.1` (verificado con
  `git merge-base --is-ancestor`).
- Por qué no es crítico: crash del wallet del usuario, sin transferencia de valor. Criterio
  "DoS/liveness sin robo" ⇒ **fuera**.

### 7.2 dcrwallet: chequeo de política de tesorería del VSP contra el mapa equivocado
- `870ec621` (2026-10-26): `status.TSpendPolicy[newKey]` → `status.TreasuryPolicy[newKey]`.
  No está en live ⇒ al fijar el voto el wallet compara contra un mapa vacío y **fuerza un
  update innecesario**. Impacto: comportamiento incorrecto de UI/política, no robo.

### 7.3 dcrpool: el peso de la share viene del user-agent (dilución de pagos)
- `internal/pool/client.go:handleSubmitWorkRequest` **sí** exige superar el target de pool
  antes de `claimWeightedShare()` (comprobación A). Por tanto **no** se pueden acuñar shares
  sin PoW al menos a la dificultad de pool: mi hipótesis inicial de "share gratis" **queda
  descartada**.
- El defecto real es que el **peso** de la share se deriva de la identidad del minero, y esa
  identidad viene del **user-agent** del cliente (`identifyMiningClients`), no de nada
  verificado en servidor:
  `minerHashes = {cpu:5e3, decred-gominer:5e9, nicehash:20e10}` ⇒
  `ShareWeights[decred-gominer] = 1e6` frente a `cpu = 1`.
  `paymentmgr.sharePercentages` reparte el bloque proporcionalmente a la suma de esos pesos.
- `claimWeightedShare` bloquea `miner == CPU` en mainnet, pero como la identidad la declara el
  cliente, un atacante se anuncia `decred-gominer` y evita el bloqueo.
- Por qué no es crítico: es *griefing/dilución* dentro de una pool concreta, el operador puede
  expulsar y la víctima recupera su proporción al seguir minando. No hay delta > 0 estable
  contra inventario ajeno ⇒ falla el criterio de criticidad. Detalle en
  `scripts/50_repro_dcrpool_shares.md`.

### 7.4 dcrpool: recomendación
Derivar el peso de la dificultad asignada server-side a la conexión (no del UA) y deduplicar
shares por `(jobID, extraNonce2, nTime, nonce)` — hoy `shareID` es único por construcción
(nano + account + rand) y no hay dedup de submits.

## 8. Cobertura de otras áreas (estado)

- **dcrdex** (`fc634606`): server `Contract`/`Redemption` verifican que el contrato es P2SH
  cuyo `scriptHash == hash160(redeemScript)` y que `ExtractSwapDetails` da exactamente 97
  bytes con offsets fijos (`dex/networks/dcr/script.go:ExtractSwapDetails`). El server **no**
  valida destinatario/importe del *redeem* (`processRedeem` lo delega al cliente, hay TODO
  explícito) — no genera déficit de protocolo porque el cliente construye su propia salida.
  `processInit` sí valida `expectedAddr`, `checkVal`, `SecretHash`, dedup de coin/secret-hash y
  `LockTime >= matchTime+lockTimeX`. Sin hallazgo crítico.
- **mixing**: live = `mixing/v0.7.5`; solo `mixpool` corre en el nodo. Límites live:
  `maxOrphans=250`, `maxMessagesPerIdentity = 7*…`, `maxPostEvictionOrphans=75%`. Los 40
  commits de master son endurecimiento ⇒ DoS/griefing, no valor.
- **vspd** (`a381bece`): `internal/webapi/payfee.go` **sí** valida el pago: decodifica
  `ticket.FeeAddress` con `stdaddr`, exige un `TxOut` con el **mismo script y versión** y
  `feePaid >= ticket.FeeAmount`, y amarra el WIF de votación al `PkScript` del output 0 del
  ticket (`VotingRightsScript()` comparado byte a byte). También pasa
  `standalone.CheckTransactionSanity`. Sin hallazgo.
  Nota: solo cuenta el **primer** output que coincide con la dirección de fee (conservador).
- **politeia** (`dca5528`): pendiente.

## 9. Reproducción

```
audit_final/scripts/10_address_decode.py     # premine/org P2SH: Dcur2mcGjmENx4DhNqDctW5wJCVyT3Qeqkx
audit_final/scripts/20_supply_replica.py     # inventario medido desde el clone
audit_final/scripts/30_delta_vs_live.sh      # qué falta de verdad en el binario live
```
Requiere: `pip install --break-system-packages blake256`; mirror
`git clone --mirror --filter=blob:none https://github.com/decred/dcrd.git /tmp/foundation/dcrd.git`.

## 10. Limitaciones declaradas

- Sin toolchain Go ⇒ **no hay PoC ejecutable**; todo es análisis estático + réplicas Python.
- `/tmp` se vacía entre turnos ⇒ los clones se recrean; los scripts viven en el workspace.
- dcrdata solo accesible vía `fetch_page`; sus agregados no se usan como inventario.
- Sin cobertura de repos privados ni de espacios no-GitHub (bloqueados) ⇒ **no se declara
  cobertura completa**.
