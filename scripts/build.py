#!/usr/bin/env python3
# scripts/build.py | Aurum
# Alternativa en Python para verificar el bundle
import pathlib, hashlib

root = pathlib.Path(__file__).parent.parent
aurum = root / "Aurum.lua"
loader = root / "loader.lua"

if not aurum.exists():
    print("[aurum] Aurum.lua no encontrado")
    raise SystemExit(1)

data = aurum.read_bytes()
print(f"[aurum] Aurum.lua: {len(data)} bytes, {data.count(b chr(10))+1} líneas")
print(f"[aurum] SHA256: {hashlib.sha256(data).hexdigest()[:16]}")
print(f"[aurum] loader.lua: {loader.stat().st_size} bytes" if loader.exists() else "loader.lua missing")
print("[aurum] build OK (bundle pre-generado)")
