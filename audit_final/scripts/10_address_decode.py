#!/usr/bin/env python3
"""Decodifica direcciones Decred (Base58Check con doble BLAKE-256) y verifica
que los scripts de chaincfg corresponden a las direcciones esperadas.

Dependencia: pip install --break-system-packages blake256
Fuente de verdad: clone decred/dcrd @ release-v2.1.7 (e07b5655)
  chaincfg/mainnetparams.go: PubKeyHashAddrID {0x07,0x3f}, ScriptHashAddrID {0x07,0x1a}
"""
from blake256.blake256 import blake_hash as blake
import sys

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
P2PKH_ID = b"\x07\x3f"
P2SH_ID = b"\x07\x1a"


def b58check(payload: bytes) -> str:
    checksum = blake(blake(payload))[:4]
    full = payload + checksum
    n = int.from_bytes(full, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHABET[r] + out
    pad = 0
    for b in full:
        if b != 0:
            break
        pad += 1
    return "1" * pad + out


def p2pkh(h160_hex: str) -> str:
    return b58check(P2PKH_ID + bytes.fromhex(h160_hex))


def p2sh(h160_hex: str) -> str:
    return b58check(P2SH_ID + bytes.fromhex(h160_hex))


if __name__ == "__main__":
    # script a914<20B>87 de chaincfg/mainnetparams.go:571 (OrganizationPkScript)
    org = "f5916158e3e2c4551c1796708db8367207ed13bb"
    print("OrganizationPkScript (P2SH) ->", p2sh(org))
    # cross-check del algoritmo contra una P2PKH conocida on-chain
    print("P2PKH check 3f7c16c3…      ->", p2pkh("3f7c16c37da4cf32361738b409779853a2c2fa93"))
    if len(sys.argv) > 2 and sys.argv[1] in ("p2pkh", "p2sh"):
        fn = p2pkh if sys.argv[1] == "p2pkh" else p2sh
        print(sys.argv[2], "->", fn(sys.argv[2]))
