# REPRO (estático, sin toolchain Go) — dcrwallet SPV panic por header con Height=0

## Estado live
- repo: `decred/dcrwallet`, rama `release-v2.1` @ `599b5850`
  ("[release-v2.1] Bump version to 2.1.7+release.local", 2026-10-12)
- el fix `abb367b4` ("wallet: Validate header heights against parents", 2026-11-03)
  **NO** es ancestro de `release-v2.1`:
  ```
  git -C /tmp/foundation/repos/dcrwallet.git merge-base --is-ancestor \
      abb367b4 release-v2.1 ; echo $?   # 1 == no está
  ```

## Código vulnerable (live)
`wallet/difficulty.go`:
```go
func (w *Wallet) validateHeaderChainDifficulties(dbtx walletdb.ReadTx,
        chain []*BlockNode, idx int) ([]*BlockNode, error) {
    ...
    var parent *wire.BlockHeader
    for ; idx < len(chain); idx++ {
        h := n.Header
        if parent == nil && h.Height != 0 {    // <-- Height==0 => parent sigue nil
            ...
        }
        err := w.checkDifficultyPositional(dbtx, h, parent, chain) // deref de parent
```

`checkDifficultyPositional` usa `prevNode.Height` / `prevNode.Bits` sin nil-check
(al menos en la rama `isBlake3PowAgendaForcedActive()` y en `calcNextBlake256Diff`).

## Camino desde un peer no confiable
`spv/sync.go:1479`:
```go
fullsc, err := s.sidechains.FullSideChain(newBlocks)
...
_, err = s.wallet.ValidateHeaderChainDifficulties(ctx, fullsc, 0)
```
`newBlocks` se construye con cabeceras recibidas del peer (`s.wallet.BlockInMainChain`
solo exige que el **prev** esté en main chain, no que `Height` sea coherente).

## Cadena de ataque (sin rol privilegiado)
1. El wallet SPV se conecta a un peer del atacante (SPV descubre peers por addrman/seeds).
2. El peer envía un lote de cabeceras donde la primera declara `Height = 0` pero
   `PrevBlock` = una cabecera real de main chain.
3. `ValidateHeaderChainDifficulties` deja `parent == nil` y llama a
   `checkDifficultyPositional` ⇒ nil deref ⇒ **panic y caída del proceso wallet**.

## Por qué NO es crítico
- No hay transferencia de valor ni firma inducida: el wallet no firma nada por este camino.
- Es un DoS del nodo/wallet del propio usuario ⇒ criterio "DoS/liveness sin robo" ⇒ fuera.

## Cómo verificarlo cuando haya Go
```bash
cd /tmp/foundation/repos/dcrwallet.git && git checkout 599b5850
go test ./wallet -run TestValidateHeaderChainDifficulties
# o un test mínimo que llame a validateHeaderChainDifficulties con chain[0].Height==0
# y prev in main chain, esperando panic (nil deref) en checkDifficultyPositional
```

## Fix (no presente en live)
Volver incondicional el lookup del parent y rechazar `h.Height != parent.Height+1`.
