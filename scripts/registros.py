"""Rango de altitud y primer registro a partir de los registros de GBIF en Canarias.

  - Altitud (especies terrestres): se toman hasta 900 registros con coordenadas precisas
    (incertidumbre ≤ 1 km) dentro de Canarias y se mide la altitud de cada punto en el
    modelo digital del terreno Copernicus GLO-90 (90 m). Se da el intervalo del 5 % al 95 %
    para no dejarse llevar por puntos mal georreferenciados, y también el mínimo y el máximo.
  - Primer registro (especies introducidas): el año más antiguo con registros en GBIF dentro
    de Canarias y el tipo de registro (pliego de herbario, observación…).

Escribe en las fichas «altitud» y «primerRegistro». Cachés en datos/extra/registros.json.
"""

from __future__ import annotations

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
DEM_DIR = Path("/tmp/dem")
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
HOY = date.today().isoformat()
CANARIAS = "POLYGON((-18.5 27.4,-13.2 27.4,-13.2 29.5,-18.5 29.5,-18.5 27.4))"
TESELAS = [(27, 19), (27, 18), (27, 17), (27, 16), (27, 14), (27, 13), (28, 19), (28, 18), (28, 17), (28, 16), (28, 15),
           (28, 14), (28, 13), (29, 14)]
TIPO = {"PRESERVED_SPECIMEN": "pliego o ejemplar de colección", "HUMAN_OBSERVATION": "observación", "MATERIAL_SAMPLE": "muestra",
        "OCCURRENCE": "registro", "MACHINE_OBSERVATION": "registro automático", "LIVING_SPECIMEN": "ejemplar vivo en colección",
        "OBSERVATION": "observación", "MATERIAL_CITATION": "cita bibliográfica", "FOSSIL_SPECIMEN": "fósil"}

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=4):
    espera = 3
    for n in range(intentos):
        try:
            r = s.get(url, params=params, timeout=120)
            if r.status_code in (200, 204, 404):
                return r
            if r.status_code == 429:
                time.sleep(30)
        except requests.RequestException as e:  # noqa: PERF203
            if n == intentos - 1:
                print(f"  sin respuesta {url}: {e}", flush=True)
                return None
        time.sleep(espera)
        espera *= 2
    return None


def cargar_json(p: Path, defecto):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return defecto


def caducado(fecha: str | None, dias: int) -> bool:
    if not fecha:
        return True
    try:
        return date.fromisoformat(fecha) < date.today() - timedelta(days=dias)
    except ValueError:
        return True


# ------------------------------------------------------------------- DEM

def cargar_dem():
    import rasterio
    DEM_DIR.mkdir(parents=True, exist_ok=True)
    datos = []
    for lat, lon in TESELAS:
        n = f"Copernicus_DSM_COG_30_N{lat:02d}_00_W{lon:03d}_00_DEM"
        p = DEM_DIR / f"{n}.tif"
        if not p.exists():
            r = get(f"https://copernicus-dem-90m.s3.amazonaws.com/{n}/{n}.tif")
            if not r or r.status_code != 200:
                print(f"  falta la tesela {n}", flush=True)
                continue
            p.write_bytes(r.content)
        ds = rasterio.open(p)
        datos.append((ds, ds.read(1), ds.bounds))
    print(f"DEM: {len(datos)} teselas", flush=True)

    def altitud(lat: float, lon: float) -> float | None:
        for ds, arr, b in datos:
            if b.left <= lon < b.right and b.bottom < lat <= b.top:
                fila, col = ds.index(lon, lat)
                if 0 <= fila < arr.shape[0] and 0 <= col < arr.shape[1]:
                    v = float(arr[fila, col])
                    return None if v < -100 else v
        return None
    return altitud


# ------------------------------------------------------------------ GBIF

def puntos(clave: int) -> tuple[list, int]:
    pts, total = [], 0
    for offset in (0, 300, 600):
        r = get("https://api.gbif.org/v1/occurrence/search", params={
            "taxonKey": clave, "geometry": CANARIAS, "hasCoordinate": "true", "hasGeospatialIssue": "false",
            "occurrenceStatus": "PRESENT", "limit": 300, "offset": offset})
        if not r or r.status_code != 200:
            break
        j = r.json()
        total = j.get("count", 0)
        for o in j.get("results", []):
            inc = o.get("coordinateUncertaintyInMeters")
            if inc is not None and inc > 1000:
                continue
            if o.get("decimalLatitude") is None:
                continue
            pts.append((o["decimalLatitude"], o["decimalLongitude"]))
        if j.get("endOfRecords") or offset + 300 >= total:
            break
    return pts, total


def primer_registro(clave: int) -> dict | None:
    r = get("https://api.gbif.org/v1/occurrence/search", params={
        "taxonKey": clave, "geometry": CANARIAS, "limit": 0, "facet": "year", "facetLimit": 1000, "year": f"1600,{date.today().year}"})
    if not r or r.status_code != 200:
        return None
    anos = [int(c["name"]) for f in r.json().get("facets", []) for c in f.get("counts", []) if c["name"].isdigit()]
    if not anos:
        return None
    ano = min(anos)
    r = get("https://api.gbif.org/v1/occurrence/search", params={"taxonKey": clave, "geometry": CANARIAS, "year": ano, "limit": 1})
    tipo, url = "", f"https://www.gbif.org/occurrence/search?taxon_key={clave}&year={ano}&geometry={CANARIAS}"
    if r and r.status_code == 200 and r.json().get("results"):
        o = r.json()["results"][0]
        tipo = TIPO.get(o.get("basisOfRecord", ""), "")
        url = f"https://www.gbif.org/occurrence/{o['key']}"
    return {"ano": ano, "tipo": tipo, "url": url}


def percentil(v: list[float], p: float) -> float:
    v = sorted(v)
    k = (len(v) - 1) * p
    i = int(k)
    return v[i] + (v[min(i + 1, len(v) - 1)] - v[i]) * (k - i)


def r10(x: float) -> int:
    return int(round(x / 10) * 10)


def main() -> int:
    inicio = time.time()
    EXTRA.mkdir(parents=True, exist_ok=True)
    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    rutas = {e["c"]: DATOS / "fichas" / f"{e['c']}.json" for e in indice}
    fichas = {c: json.loads(p.read_text(encoding="utf-8")) for c, p in rutas.items()}
    cache = cargar_json(EXTRA / "registros.json", {})

    pend = [(c, f) for c, f in fichas.items() if f.get("gbifClave") and caducado(cache.get(c, {}).get("fecha"), 180)]
    print(f"GBIF: {len(pend)} taxones por consultar", flush=True)
    altitud = cargar_dem() if pend else None

    def uno(cf):
        c, f = cf
        out = {"fecha": HOY}
        clave = f["gbifClave"]
        if f.get("medio") == "Terrestre":
            pts, total = puntos(clave)
            alts = [a for a in (altitud(la, lo) for la, lo in pts) if a is not None and a > 0]
            out["total"] = total
            if len(alts) >= 5:
                out["alt"] = {"p5": r10(percentil(alts, 0.05)), "p95": r10(percentil(alts, 0.95)),
                              "min": r10(min(alts)), "max": r10(max(alts)), "n": len(alts)}
        if f.get("nivel") == "introducido":
            pr = primer_registro(clave)
            if pr:
                out["primer"] = pr
        return c, out

    try:
        with ThreadPoolExecutor(4) as ex:
            for k, (c, out) in enumerate(ex.map(uno, pend), 1):
                cache[c] = out
                if k % 250 == 0:
                    print(f"  {k}/{len(pend)}", flush=True)
                    (EXTRA / "registros.json").write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    finally:
        (EXTRA / "registros.json").write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    n_alt = n_pr = 0
    for c, f in fichas.items():
        f.pop("altitud", None)
        f.pop("primerRegistro", None)
        d = cache.get(c) or {}
        clave = f.get("gbifClave")
        if d.get("alt"):
            a = d["alt"]
            f["altitud"] = {**a, "fuente": "Registros de GBIF en Canarias y modelo del terreno Copernicus GLO-90",
                            "url": f"https://www.gbif.org/occurrence/search?taxon_key={clave}&geometry={CANARIAS}"}
            n_alt += 1
        if d.get("primer"):
            f["primerRegistro"] = {**d["primer"], "fuente": "GBIF"}
            n_pr += 1
    for c, f in fichas.items():
        rutas[c].write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = cargar_json(DATOS / "meta.json", {})
    meta["registros"] = {"fecha": HOY, "altitud": n_alt, "primerRegistro": n_pr}
    (DATOS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Registros: altitud {n_alt}, primer registro {n_pr} · {round((time.time() - inicio) / 60, 1)} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
