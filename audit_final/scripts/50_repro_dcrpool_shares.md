# REPRO (estático) — dcrpool: share ponderada sin PoW válido ⇒ dilución de pagos

## Estado
- repo: `decred/dcrpool` @ `90d745f8` ("build: Update Decred deps", 2026-01-28)

## Código
`internal/pool/client.go: handleSubmitWorkRequest`
```go
if hashTarget.Cmp(tgt) > 0 { ... LowDifficultyShare ... }   // (A) exige superar el target de POOL
atomic.AddInt64(&c.submissions, 1)

if !c.cfg.SoloPool {
    err := c.claimWeightedShare()      // (B) persiste la share
}
...
if hashTarget.Cmp(target) > 0 {        // (C) target de RED: aquí es donde falla la comprobación real
    resp := SubmitWorkResponse(*req.ID, true, nil)
```
`claimWeightedShare` → `NewShare(account, ShareWeights[miner])` → `db.PersistShare`.
`shareID` = nano(createdOn) + account + rand ⇒ **cada llamada genera una share única**:
no hay dedup por `(jobID, extraNonce2, nTime, nonce)` y el cliente **elige** `extraNonce2`/`nTime`/`nonce`.

## Pesos
`internal/pool/difficulty.go`:
```go
minerHashes = map[string]*big.Int{
    CPU:               new(big.Int).SetInt64(5e3),
    Gominer:           new(big.Int).SetInt64(5e9),
    NiceHashValidator: new(big.Int).SetInt64(20e10),
}
```
⇒ `ShareWeights[decred-gominer] = 5e9/5e3 = 1_000_000` (×1e6 frente a un "cpu").
El `miner` se deriva del **user-agent** del cliente (`identifyMiningClients`), no de una prueba.

## Ataque
Cliente autenticado con cualquier dirección mainnet válida (`address.clientid`):
1. `mining.subscribe` con UA `decred-gominer/2.1.0` ⇒ peso 1e6.
2. Repetir `mining.submit` con `nonce` aleatorio: el PoW no llega ni al target de pool
   (falla A) **excepto** cuando casualmente lo supera; mientras, las llamadas que fallan en A
   **no** llegan a (B)… ⇒ para reclamar share hay que superar el target de **pool**.
   *(Corrección al escenario ingenuo: la share sólo se persiste si supera el target de pool,
   que para peso 1e6 es ~1e6 veces más difícil que el target de cpu.)*
3. El abuso real está en que el **peso** lo fija el user-agent: un atacante que logre
   `submit` con UA de gominer obtiene shares de peso 1e6 por el mismo trabajo por el que un
   `cpu` obtendría peso 1; y `sharePercentages` reparte el bloque proporcionalmente a esos pesos.

## Por qué NO es crítico
- La comprobación (A) impide shares sin PoW ⇒ no se puede "inventar" trabajo gratis.
- El vector real es **mentir en el user-agent** ⇒ griefing/dilución dentro de una pool; el
  operador puede bloquear y la víctima recupera su proporción al seguir minando.
- No hay delta > 0 estable contra inventario ajeno, ni PoC con unwind ≥ 0 ⇒ fuera.
- `claimWeightedShare` sí bloquea `CPU` en mainnet, pero la identidad viene del UA.

## Qué habría que arreglar
Derivar el peso de la dificultad asignada a la conexión (server-side), no del user-agent;
y deduplicar shares por `(jobID, extraNonce2, nTime, nonce)`.
