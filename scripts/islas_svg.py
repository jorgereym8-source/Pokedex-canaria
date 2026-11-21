"""Genera js/islas.js con los contornos reales de las islas para el mapa de distribución.

Fuente: líneas de costa de OpenStreetMap (© OpenStreetMap contributors, ODbL), obtenidas con
scripts/sonda7.py y guardadas en scripts/islas_osm.geojson. Proyección equirectangular
centrada en 28,3° N. Los islotes (La Graciosa, Alegranza, Montaña Clara y Lobos) se dibujan
con la isla a la que pertenecen en Biota.
"""
import json
import math
from pathlib import Path

from shapely.geometry import shape

RAIZ = Path(__file__).resolve().parent.parent
CENTROS = {"T": (-16.5566, 28.2906), "F": (-14.0367, 28.4052), "C": (-15.5934, 27.9548), "L": (-13.6423, 29.0242),
           "P": (-17.8578, 28.6897), "G": (-17.2325, 28.1174), "H": (-18.0063, 27.7463),
           "L:La Graciosa": (-13.5092, 29.2524), "L:Alegranza": (-13.5117, 29.3992), "F:Lobos": (-13.8216, 28.7502),
           "L:Montaña Clara": (-13.5349, 29.298)}
TOL = 0.0015
LAT0 = 28.3
K = math.cos(math.radians(LAT0))
LON_MIN, LON_MAX, LAT_MIN, LAT_MAX = -18.22, -13.30, 27.60, 29.45
ANCHO = 360
M = 8
ESC = (ANCHO - 2 * M) / ((LON_MAX - LON_MIN) * K)
ALTO = round((LAT_MAX - LAT_MIN) * ESC + 2 * M)


def P(lon, lat):
    return (M + (lon - LON_MIN) * K * ESC, M + (LAT_MAX - lat) * ESC)


def main():
    g = json.loads((RAIZ / "scripts" / "islas_osm.geojson").read_text())
    islas, cajas = {}, {}
    for f in g["features"]:
        pr = f["properties"]
        if pr["km2"] < 1:
            continue
        cod = next((k for k, (x, y) in CENTROS.items() if abs(x - pr["cx"]) < 0.01 and abs(y - pr["cy"]) < 0.01), None)
        if not cod:
            continue
        base = cod.split(":")[0]
        s = shape(f["geometry"]).simplify(TOL, preserve_topology=True)
        pts = [P(x, y) for x, y in s.exterior.coords]
        d = "M" + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z"
        islas.setdefault(base, []).append(d)
        if ":" not in cod:
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            cajas[base] = [round(min(xs), 1), round(min(ys), 1), round(max(xs), 1), round(max(ys), 1)]
    # barra de escala de 50 km
    km50 = 50 / (111.32 * K) * K * ESC
    datos = {"ancho": ANCHO, "alto": ALTO, "islas": islas, "cajas": cajas, "km50": round(km50, 1)}
    js = ("// Contornos de las islas: © OpenStreetMap contributors (ODbL). Generado por scripts/islas_svg.py\n"
          f"export const MAPA = {json.dumps(datos, ensure_ascii=False, separators=(',', ':'))};\n")
    (RAIZ / "js" / "islas.js").write_text(js, encoding="utf-8")
    print(f"js/islas.js: {len(js)} bytes, {ANCHO}x{ALTO}", cajas)


if __name__ == "__main__":
    main()
