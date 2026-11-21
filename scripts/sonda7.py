"""Sonda: contornos reales de las islas desde OpenStreetMap (líneas de costa vía Overpass).

Une las líneas de costa, forma los polígonos de cada isla e islote, los simplifica un poco
y guarda un GeoJSON en sonda/islas.geojson (© OpenStreetMap contributors, ODbL).
"""
import json
import time
from pathlib import Path

import requests
from shapely.geometry import LineString, mapping
from shapely.ops import linemerge, polygonize, unary_union

out = Path("sonda")
out.mkdir(exist_ok=True)
Q = """[out:json][timeout:300];
way["natural"="coastline"](27.55,-18.25,29.5,-13.3);
out geom;"""
datos = None
for url in ("https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"):
    for _ in range(3):
        try:
            r = requests.post(url, data={"data": Q}, timeout=400, headers={"User-Agent": "PokedexCanaria/0.1"})
            if r.status_code == 200:
                datos = r.json()
                break
        except Exception as e:  # noqa: BLE001
            print("error", url, e, flush=True)
        time.sleep(20)
    if datos:
        break
lineas = [LineString([(p["lon"], p["lat"]) for p in w["geometry"]]) for w in datos["elements"] if w.get("geometry")]
print("líneas de costa:", len(lineas), flush=True)
polis = list(polygonize(linemerge(unary_union(lineas))))
print("polígonos:", len(polis), flush=True)
feats = []
for p in polis:
    km2 = p.area * 111.3 * 111.3 * 0.88
    if km2 < 0.05:
        continue
    s = p.simplify(0.0004, preserve_topology=True)
    feats.append({"type": "Feature", "properties": {"km2": round(km2, 2), "cx": round(p.centroid.x, 4), "cy": round(p.centroid.y, 4),
                                                    "puntos": len(s.exterior.coords)}, "geometry": mapping(s)})
feats.sort(key=lambda f: -f["properties"]["km2"])
(out / "islas.geojson").write_text(json.dumps({"type": "FeatureCollection", "features": feats}))
for f in feats[:20]:
    print(f["properties"], flush=True)
