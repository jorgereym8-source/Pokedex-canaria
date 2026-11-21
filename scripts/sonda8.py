"""Sonda: niveles de la búsqueda divulgativa de Biota y número de taxones de invertebrados."""
import csv
import io
import json
import re
import time
from collections import Counter
from pathlib import Path

import requests

BIOTA = "https://www.biodiversidadcanarias.es/biota"
s = requests.Session()
s.headers.update({"User-Agent": "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"})
out = Path("sonda")
out.mkdir(exist_ok=True)
res = {}
r = s.get(f"{BIOTA}/especies", timeout=60)
html = r.text
(out / "especies.html").write_text(html)
for m in re.finditer(r'<select[^>]*(?:name|id)="([^"]*)"[^>]*>(.*?)</select>', html, re.S):
    res["select_" + m.group(1)] = re.findall(r'<option[^>]*value="([^"]*)"[^>]*>\s*([^<]*?)\s*</option>', m.group(2))
res["scripts_niveles"] = sorted(set(re.findall(r'["\'](/biota/[^"\']*(?:level|nivel|Level)[^"\']*)["\']', html)))[:20]
print(json.dumps(res, ensure_ascii=False)[:3000], flush=True)


def exportar(params):
    p = dict(params, searchSpeciesTabs="divulgativeSearch")
    r = s.get(f"{BIOTA}/especies/export", params=p, timeout=300)
    filas = list(csv.reader(io.StringIO(r.content.decode("cp1252", errors="replace")), delimiter=";"))
    return filas


niveles1 = [v for v, t in res.get("select_selectLevel1", []) if v.strip()]
conteos = {}
for v in niveles1:
    if v in ("2", "8"):
        continue
    filas = exportar({"selectLevel1": v})
    cab = filas[0] if filas else []
    ic = cab.index("Clase") if "Clase" in cab else None
    im = cab.index("Medio") if "Medio" in cab else None
    io_ = next((i for i, c in enumerate(cab) if c.strip().startswith("Origen")), None)
    ie = next((i for i, c in enumerate(cab) if c.strip().startswith("Endemicidad")), None)
    cuerpo = [f for f in filas[1:] if f and f[0].strip()]
    conteos[v] = {"n": len(cuerpo), "cab": cab,
                  "clases": Counter(f[ic] for f in cuerpo if ic is not None and ic < len(f)).most_common(40),
                  "medio": Counter(f[im] for f in cuerpo if im is not None and im < len(f)).most_common(5),
                  "endemicos": sum(1 for f in cuerpo if ie is not None and ie < len(f) and f[ie].strip().startswith("End")),
                  "origen": Counter(f[io_] for f in cuerpo if io_ is not None and io_ < len(f)).most_common(8)}
    print(v, conteos[v]["n"], conteos[v]["clases"][:8], flush=True)
    time.sleep(3)
res["conteos"] = conteos
(out / "_res.json").write_text(json.dumps(res, ensure_ascii=False, indent=1))
