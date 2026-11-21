"""Cuenta el trabajo pendiente a partir de datos/meta.json (para encadenar ejecuciones en Actions).

  python scripts/pendientes.py fichas         → fichas de Biota aún sin descargar
  python scripts/pendientes.py enriquecimiento → búsquedas pendientes de fotos, registros y sonidos
"""
import json
import sys
from pathlib import Path

meta = json.loads((Path(__file__).resolve().parent.parent / "datos" / "meta.json").read_text(encoding="utf-8"))
que = sys.argv[1] if len(sys.argv) > 1 else "fichas"
if que == "fichas":
    print(int(meta.get("fichasPendientes") or 0))
else:
    print(int((meta.get("fotos") or {}).get("pendientes_inat") or 0)
          + int((meta.get("registros") or {}).get("pendientes") or 0)
          + int((meta.get("sonidos") or {}).get("pendientes") or 0))
