"""Sonda: velocidad de las consultas de GBIF en Canarias con distintos filtros."""
import json
import time
from pathlib import Path

import requests

s = requests.Session()
s.headers.update({"User-Agent": "PokedexCanaria/0.1 (app personal sin fines comerciales)"})
out = Path("sonda")
out.mkdir(exist_ok=True)
res = []
POLY = "POLYGON((-18.5 27.4,-13.2 27.4,-13.2 29.5,-18.5 29.5,-18.5 27.4))"
for clave in (2468673, 2650829, 5284517, 3172358):
    for nombre, extra in (("geometria", {"geometry": POLY}),
                          ("rangos", {"decimalLatitude": "27.4,29.5", "decimalLongitude": "-18.5,-13.2"}),
                          ("gadm", {"gadmGid": "ESP.14_1"}),
                          ("provincia", {"country": "ES", "stateProvince": "Islas Canarias"})):
        p = {"taxonKey": clave, "hasCoordinate": "true", "limit": 300, **extra}
        t = time.time()
        try:
            r = s.get("https://api.gbif.org/v1/occurrence/search", params=p, timeout=120)
            j = r.json()
            res.append({"clave": clave, "filtro": nombre, "seg": round(time.time() - t, 2), "estado": r.status_code,
                        "count": j.get("count"), "n": len(j.get("results", [])), "bytes": len(r.content),
                        "gadm1": [x.get("gadm", {}).get("level1", {}).get("gid") for x in j.get("results", [])[:3]]})
        except Exception as e:  # noqa: BLE001
            res.append({"clave": clave, "filtro": nombre, "error": repr(e)})
        print(res[-1], flush=True)
(out / "_res.json").write_text(json.dumps(res, ensure_ascii=False, indent=1))
