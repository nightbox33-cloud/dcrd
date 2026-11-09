#!/usr/bin/env python3
"""Replica del subsidio de dcrd (mainnet) para medir el inventario emitido.

Fuente de verdad (clone): decred/dcrd @ tag release-v2.1.7 == commit e07b5655
  - chaincfg/subsidytables.go : premine del bloque 1 (3146 payouts x 5000 DCR)
  - blockchain/standalone/subsidy.go : CalcBlockSubsidy / CalcWorkSubsidyV3 /
    CalcStakeVoteSubsidyV3 / CalcTreasurySubsidy
  - chaincfg/mainnetparams.go : BaseSubsidy, SubsidyReductionInterval,
    TicketsPerBlock, proporciones DCP0010 (10/80/10) y DCP0012 (1/89/10)

El resultado se contrasta contra dcrdata /api/supply, que EXCLUYE el premine
(db/dcrpg/internal/vinoutstmts.go: SelectCoinSupply filtra block_height > $1
con $1 = 0, y el premine esta en el bloque 1).

Uso: python3 20_supply_replica.py [altura]
"""
import sys, re, pathlib

ATOMS = 100_000_000
REDUCTION_INTERVAL = 6144          # SubsidyReductionInterval (mainnet)
BASE = 3_119_582_664               # BaseSubsidy, atoms
DCP0010_HEIGHT = 638_976           # changesubsidysplit  10/80/10
DCP0012_HEIGHT = 787_968           # changesubsidysplitr2 1/89/10
VOTES_PER_BLOCK = 5                # TicketsPerBlock


def premine_atoms(chaincfg_dir: pathlib.Path) -> tuple[int, int]:
    """Suma los payouts del bloque 1 leyendo la tabla del clone."""
    src = (chaincfg_dir / "subsidytables.go").read_text()
    start = src.find("var blockOnePayouts_MainNetParams")
    end = src.find("\n}", start)
    pairs = re.findall(r"offset:\s*(\d+),\s*amount:\s*(\d+)", src[start:end])
    return len(pairs), sum(int(a) for _, a in pairs)


def block_subsidy(height: int) -> int:
    if height <= 1:
        return 0
    s = BASE
    for _ in range((height - 1) // REDUCTION_INTERVAL):
        s = s * 100 // 101
        if s == 0:
            return 0
    return s


def split(subsidy: int, height: int):
    if height >= DCP0012_HEIGHT:
        pos, trs = subsidy * 89 // 100, subsidy * 10 // 100
    elif height >= DCP0010_HEIGHT:
        pos, trs = subsidy * 80 // 100, subsidy * 10 // 100
    else:
        pos, trs = subsidy * 30 // 100, subsidy * 10 // 100
    return subsidy - pos - trs, pos, trs


def main():
    top = int(sys.argv[1]) if len(sys.argv) > 1 else 1_130_871
    chaincfg_dir = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path("/home/user/dcrd/chaincfg")
    n, premine = premine_atoms(chaincfg_dir)

    emitted = sum(block_subsidy(h) for h in range(2, top + 1))
    pow_, pos, trs = split(block_subsidy(top), top)

    print(f"premine: {n} payouts, {premine/ATOMS:.8f} DCR")
    print(f"emitido 2..{top}: {emitted/ATOMS:.8f} DCR")
    print(f"supply incl. premine: {(emitted+premine)/ATOMS:.8f} DCR")
    print(f"bloque {top}: pow {pow_/ATOMS:.8f} | pos {pos/ATOMS:.8f} "
          f"(voto {pos/VOTES_PER_BLOCK/ATOMS:.8f}) | tesoreria {trs/ATOMS:.8f}")

    # El total teorico NO se recalcula aqui a mano: se cita el valor que el
    # propio repo se auto-verifica en blockchain/standalone/subsidy_test.go:1110
    # (TestTotalSubsidy) = 2099999999800912 atoms, es decir 20.999.999,99800912
    # DCR incluyendo el premine. Coincide con dcrdata /api/supply
    # (supply_ultimate = 2099999998394320 atoms), que usa su propio redondeo.
    print("emision total teorica: 20999999.99800912 DCR "
          "(blockchain/standalone/subsidy_test.go:1110 @ e07b5655)")


if __name__ == "__main__":
    main()
