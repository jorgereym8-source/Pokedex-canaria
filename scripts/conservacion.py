"""Conservación y normativa, con fuentes oficiales.

  - Red Natura 2000: espacios de Canarias (códigos ES70…) en cuyo formulario oficial figura
    la especie (Agencia Europea de Medio Ambiente, Natura 2000 tabular, versión end 2024 rev. 1).
  - Estado de conservación en la región macaronésica (artículo 17 de la Directiva Hábitats,
    periodo 2013-2018) y población y tendencia de las aves (artículo 12 de la Directiva Aves,
    2013-2018; se usa el informe de Canarias cuando España lo da por separado).
  - Tallas mínimas de captura en el caladero canario (Real Decreto 560/1995, anexo III,
    texto consolidado del BOE).
  - Especies introducidas: fecha o periodo de introducción, vías de introducción, vía de
    dispersión actual y área de origen, del «Compendio de fichas de la Base de especies
    introducidas en Canarias (2008-2011)» (Gobierno de Canarias, 2022).
  - Vulnerabilidad al cambio climático: solo si se rellena datos-propios/vulnerabilidad.csv.

Escribe en las fichas «natura2000», «art17», «art12», «tallaMinima», «introduccion» y
«vulnerabilidad». Cachés en datos/extra/.
"""

from __future__ import annotations

import csv
import difflib
import io
import json
import re
import sys
import time
import unicodedata
import zipfile
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
PROPIOS = RAIZ / "datos-propios" / "vulnerabilidad.csv"
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
HOY = date.today().isoformat()
DAV = "https://sdi.eea.europa.eu/datashare/public.php/dav/files/sptXqwkQr5g7Bp5/"
NATURA_ZIP = DAV + "eea_t_natura2000_p_2024_v01_r01/Natura2000_end2024_rev1_csv.zip"
ART12_DIR = "eea_t_art12-2013-2018_p_2013-2018_v01_r01/Article12_2020_dataset_20210401_csv/"
ART17_DIR = "eea_t_art17_p_2013-2018_v01_r00/Article17_2020_dataset_csv/"
COMPENDIO = "https://www.gobiernodecanarias.org/medioambiente/descargas/publicaciones/GOBCAN-2022-Compendio-fichas-especies-introducidas-2008-2011.zip"
BOE_TALLAS = "https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/BOE-A-1995-8639/texto"
RANGOS = {"subsp.", "ssp.", "var.", "f.", "×", "x", "s.", "str.", "sensu", "stricto"}

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=3, timeout=600, **kw):
    espera = 5
    for n in range(intentos):
        try:
            r = s.get(url, params=params, timeout=timeout, **kw)
            if r.status_code in (200, 204, 404):
                return r
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


def guardar_json(p: Path, d) -> None:
    p.write_text(json.dumps(d, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def caducado(fecha: str | None, dias: int) -> bool:
    if not fecha:
        return True
    try:
        return date.fromisoformat(fecha) < date.today() - timedelta(days=dias)
    except ValueError:
        return True


def norm(n: str) -> str:
    n = re.sub(r"\[.*?\]|\(.*?\)", " ", n or "")
    t = [w for w in n.replace("×", " ").split() if w.lower() not in RANGOS]
    out = t[:1]
    for w in t[1:]:
        if not w[:1].islower() or "." in w or w in ("ex", "et", "in", "de", "van", "von", "&"):
            break
        out.append(w)
    return " ".join(out[:3]).lower().strip()


def binomio(n: str) -> str:
    return " ".join(norm(n).split()[:2])


def leer_csv(texto: str) -> list[dict]:
    return list(csv.DictReader(io.StringIO(texto.lstrip("﻿"))))


# --------------------------------------------------------------- Natura 2000

def natura2000(cache: dict) -> dict:
    if not caducado(cache.get("fecha"), 60) and cache.get("especies"):
        return cache
    r = get(NATURA_ZIP, timeout=900)
    if not r or r.status_code != 200:
        print("Natura 2000 no disponible", flush=True)
        return cache
    z = zipfile.ZipFile(io.BytesIO(r.content))
    def tabla(sufijo):
        n = next((x for x in z.namelist() if x.upper().endswith(sufijo)), None)
        if not n:
            return []
        return [{k.upper(): v for k, v in f.items()} for f in leer_csv(z.read(n).decode("utf-8", "replace"))]
    sitios = {}
    for f in tabla("_NATURA2000SITES.CSV"):
        if f.get("SITECODE", "").startswith("ES70"):
            sitios[f["SITECODE"]] = {"nombre": f.get("SITENAME", "").strip(), "tipo": f.get("SITETYPE", "").strip()}
    especies = defaultdict(set)
    for suf in ("_SPECIES.CSV", "_OTHERSPECIES.CSV"):
        for f in tabla(suf):
            sc = f.get("SITECODE", "")
            if sc in sitios and f.get("SPECIESNAME"):
                if str(f.get("NONPRESENCEINSITE", "")).strip() in ("1", "true", "True"):
                    continue
                especies[norm(f["SPECIESNAME"])].add(sc)
    cache.clear()
    cache.update({"fecha": HOY, "sitios": sitios, "especies": {k: sorted(v) for k, v in especies.items()}})
    print(f"Natura 2000: {len(sitios)} espacios en Canarias, {len(especies)} nombres", flush=True)
    return cache


# ---------------------------------------------------------- artículos 12 y 17

ESTADO = {"FV": "favorable", "U1": "desfavorable-inadecuado", "U2": "desfavorable-malo", "XX": "desconocido"}
TEND_CONC = {"I": "mejorando", "+": "mejorando", "D": "empeorando", "-": "empeorando", "S": "estable", "=": "estable",
             "U": "tendencia desconocida", "X": "tendencia desconocida", "x": "tendencia desconocida"}
TEND_POB = {"I": "en aumento", "D": "en descenso", "S": "estable", "F": "fluctuante", "U": "incierta", "X": "desconocida"}
UNIDAD = {"p": "parejas", "i": "individuos", "cmales": "machos cantores", "bfemales": "hembras reproductoras",
          "males": "machos", "cfemales": "hembras con crías", "fronds": "frondes", "localities": "localidades"}
ESTACION = {"B": "reproductora", "W": "invernante", "P": "de paso"}


def dav_csv(ruta: str) -> list[dict]:
    r = get(DAV + ruta, timeout=900)
    if not r or r.status_code != 200:
        print(f"  no disponible: {ruta}", flush=True)
        return []
    return leer_csv(r.content.decode("utf-8", "replace"))


def estado_txt(v: str) -> tuple[str, str]:
    v = (v or "").strip()
    est = ESTADO.get(v[:2], "")
    ten = TEND_CONC.get(v[2:3], "") if len(v) > 2 else ""
    return est, ten


def articulos(cache: dict) -> dict:
    if not caducado(cache.get("fecha"), 180) and (cache.get("a12") or cache.get("a17")):
        return cache
    a12 = {}
    for f in dav_csv(ART12_DIR + "Article12_2020_data_birds.csv"):
        pais = f.get("country", "")
        if pais not in ("ES", "ESIC"):
            continue
        n = norm(f.get("speciesname", ""))
        temporada = f.get("season", "").strip()
        previo = a12.get(n)
        prioridad = (pais == "ESIC", temporada == "B")
        if previo and tuple(previo["_p"]) >= prioridad:
            continue
        unidad = f.get("population_size_unit", "").strip()
        mn, mx = f.get("population_size_min", "").strip(), f.get("population_size_max", "").strip()
        pob = ""
        if mn or mx:
            pob = f"{mn}–{mx}" if mn and mx and mn != mx else (mn or mx)
            pob = pob.replace(".0", "") + (f" {UNIDAD.get(unidad, unidad)}" if unidad else "")
        a12[n] = {"_p": prioridad, "ambito": "Canarias" if pais == "ESIC" else "España", "poblacion": pob,
                  "estacion": ESTACION.get(temporada, temporada), "fechaPoblacion": f.get("population_date", "").strip(),
                  "tendencia": TEND_POB.get(f.get("population_trend", "").strip()[:1], ""),
                  "tendenciaLarga": TEND_POB.get(f.get("population_trend_long", "").strip()[:1], "")}
    a17 = {}
    filas = dav_csv(ART17_DIR + "Article17_2020_data_species_regions.csv")
    concl = [c for c in (filas[0].keys() if filas else []) if c.startswith("conclusion_")]
    for f in filas:
        if f.get("country") != "ES" or f.get("region") != "MAC" or not concl:
            continue
        est, ten = estado_txt(f.get("conclusion_assessment", ""))
        if not est and f.get("conclusion_assessment_trend"):
            ten = TEND_CONC.get(f["conclusion_assessment_trend"].strip()[:1], "")
        if est:
            a17[norm(f.get("speciesname", ""))] = {"ambito": "España, región macaronésica", "estado": est,
                                                    "tendencia": ten or TEND_CONC.get(str(f.get("conclusion_assessment_trend", "")).strip()[:1], ""),
                                                    "parametros": {k.removeprefix("conclusion_"): ESTADO.get(str(f.get(k, ""))[:2], "")
                                                                   for k in ("conclusion_range", "conclusion_population", "conclusion_habitat", "conclusion_future")
                                                                   if f.get(k)}}
    for f in dav_csv(ART17_DIR + "Article17_2020_speciesEUassessment.csv"):
        if f.get("region") != "MAC":
            continue
        n = norm(f.get("assessment_speciesname", ""))
        if n in a17:
            continue
        est, _ = estado_txt(f.get("conclusion_assessment", ""))
        if est:
            a17[n] = {"ambito": "UE, región macaronésica", "estado": est,
                      "tendencia": TEND_CONC.get(str(f.get("conclusion_assessment_trend", "")).strip()[:1], ""),
                      "parametros": {k.removeprefix("conclusion_"): ESTADO.get(str(f.get(k, ""))[:2], "")
                                     for k in ("conclusion_range", "conclusion_population", "conclusion_habitat", "conclusion_future") if f.get(k)}}
    for v in a12.values():
        v.pop("_p", None)
    print(f"Art. 12: {len(a12)} aves · art. 17: {len(a17)} especies (MAC)", flush=True)
    cache.clear()
    cache.update({"fecha": HOY, "a12": a12, "a17": a17})
    return cache


# ------------------------------------------------------------- tallas mínimas

def tallas(cache: dict) -> dict:
    if not caducado(cache.get("fecha"), 30) and cache.get("filas"):
        return cache
    r = get(BOE_TALLAS, headers={"Accept": "application/xml"}, timeout=120)
    if not r or r.status_code != 200:
        print("BOE no disponible", flush=True)
        return cache
    t = r.content.decode("utf-8", "replace")
    i = t.find("caladero canario", t.find("ANEXO III"))
    j = t.find("ANEXO IV", i) if t.find("ANEXO IV", i) > 0 else len(t)
    seg = t[i:j]
    filas = []
    for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", seg, re.S):
        celdas = [re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", c)).strip() for c in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)]
        if len(celdas) >= 3 and re.search(r"\(([A-Z][a-z]+ [a-zA-Z.]+)\)", celdas[0]):
            sci = re.search(r"\(([A-Z][a-z]+ [a-zA-Z.]+)\)", celdas[0]).group(1)
            filas.append({"especie": celdas[0], "cientifico": sci, "local": celdas[1], "talla": celdas[2]})
    print(f"Tallas mínimas (caladero canario): {len(filas)} filas", flush=True)
    if filas:
        cache.clear()
        cache.update({"fecha": HOY, "filas": filas})
    return cache


def talla_de(nombre: str, filas: list[dict]) -> dict | None:
    g, *resto = binomio(nombre).split()
    ep = resto[0] if resto else ""
    mejor, puntos = None, 0.0
    for f in filas:
        fg, fe = (f["cientifico"].lower().split() + [""])[:2]
        if fg != g.lower():
            continue
        if fe in ("spp", "spp.", "sp", "sp."):
            if puntos < 0.75:
                mejor, puntos = f, 0.75
            continue
        p = difflib.SequenceMatcher(None, fe, ep).ratio()
        if p > puntos and p >= 0.8:
            mejor, puntos = f, p
    return mejor


# ----------------------------------------------------------------- compendio

SECCIONES = {
    "FECHA O PERIODO INTRODUCCIÓN": "fecha", "FECHA O PERIODO DE INTRODUCCIÓN": "fecha",
    "VÍAS Y CAUSAS DE INTRODUCCIÓN": "via", "PRINCIPAL VÍA DE DISPERSIÓN/PROPAGACIÓN ACTUAL": "dispersion",
}
SUB = {"Área de distribución natural": "origen", "Área de introducción en Canarias": "islas"}


def compendio(cache: dict, nombres: list[str]) -> dict:
    if not caducado(cache.get("fecha"), 365) and cache.get("fichas") is not None:
        return cache
    r = get(COMPENDIO, timeout=900)
    if not r or r.status_code != 200:
        print("Compendio no disponible", flush=True)
        return cache
    from pypdf import PdfReader
    z = zipfile.ZipFile(io.BytesIO(r.content))
    rd = PdfReader(io.BytesIO(z.read(z.namelist()[0])))
    if rd.is_encrypted:
        rd.decrypt("")
    lineas = []  # (página impresa, línea)
    for i, p in enumerate(rd.pages):
        try:
            txt = p.extract_text() or ""
        except Exception:  # noqa: BLE001
            continue
        for l in txt.splitlines():
            l = l.strip()
            if not l or l.startswith("Compendio de fichas de la") or l.startswith("PARTE I") or "índice de taxones" in l:
                continue
            lineas.append((i + 1, l))
    print(f"Compendio: {len(rd.pages)} páginas, {len(lineas)} líneas", flush=True)

    objetivos = {binomio(n): n for n in nombres}
    # Cada ficha empieza con el nombre científico y, pocas líneas después, «División» o «Filo»
    inicios = [k for k, (_, l) in enumerate(lineas) if l in ("División", "Filo")]
    fichas = {}
    for a, k in enumerate(inicios):
        cab = " ".join(l for _, l in lineas[max(0, k - 4):k])
        cab = cab.split("Fecha:")[-1]
        cab = re.sub(r"^\s*\d{4}\s*\d*\s*", "", cab)
        m = re.search(r"([A-Z][a-z]+(?: ×)? [a-z-]+(?: (?:subsp\.|var\.) [a-z-]+)?)", cab)
        if not m:
            continue
        clave = binomio(m.group(1))
        fin = inicios[a + 1] - 4 if a + 1 < len(inicios) else len(lineas)
        cuerpo = lineas[k:fin]
        datos, actual = {}, None
        for pag, l in cuerpo:
            t = l.lstrip(" y•").strip()
            mayus = re.sub(r"[^A-Za-zÁÉÍÓÚÑáéíóúñ]", "", t)
            if len(mayus) >= 6 and mayus.upper() == mayus:
                actual = SECCIONES.get(t.strip(), None)
                continue
            if t in SUB:
                actual = SUB[t]
                continue
            if l.startswith("y ") and actual in SUB.values():
                actual = None
            if t.startswith("Autor textos:"):
                datos["autor"] = t.split(":", 1)[1].strip()
                actual = None
                continue
            if t.startswith("Fecha:"):
                datos["ano"] = t.split(":", 1)[1].strip()[:4]
                break
            if actual and len(datos.get(actual, "")) < 400:
                datos[actual] = (datos.get(actual, "") + " " + t).strip()
        if any(datos.get(x) for x in ("fecha", "via", "dispersion", "origen")):
            datos["pagina"] = cuerpo[0][0] if cuerpo else None
            datos["nombre"] = m.group(1)
            fichas.setdefault(clave, datos)
    print(f"Compendio: {len(fichas)} fichas con datos de introducción", flush=True)
    cache.clear()
    cache.update({"fecha": HOY, "fichas": fichas})
    return cache


# ---------------------------------------------------------------------- main

def main() -> int:
    inicio = time.time()
    EXTRA.mkdir(parents=True, exist_ok=True)
    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    rutas = {e["c"]: DATOS / "fichas" / f"{e['c']}.json" for e in indice}
    fichas = {c: json.loads(p.read_text(encoding="utf-8")) for c, p in rutas.items()}

    c_nat = cargar_json(EXTRA / "natura2000.json", {})
    c_art = cargar_json(EXTRA / "articulos.json", {})
    c_tal = cargar_json(EXTRA / "tallas.json", {})
    c_com = cargar_json(EXTRA / "compendio.json", {})
    for nombre, fn, c, arg in (("natura2000", natura2000, c_nat, None), ("articulos", articulos, c_art, None),
                               ("tallas", tallas, c_tal, None)):
        try:
            fn(c)
        except Exception as e:  # noqa: BLE001
            print(f"Error en {nombre}: {e!r}", flush=True)
        guardar_json(EXTRA / f"{nombre}.json", c)
    try:
        compendio(c_com, [f["nombre"] for f in fichas.values() if f.get("nivel") == "introducido"])
    except Exception as e:  # noqa: BLE001
        print(f"Error en compendio: {e!r}", flush=True)
    guardar_json(EXTRA / "compendio.json", c_com)

    propios = {}
    if PROPIOS.exists():
        for f in csv.DictReader(PROPIOS.open(encoding="utf-8"), delimiter=";"):
            if (f.get("codigo") or "").strip() and any((f.get(k) or "").strip() for k in ("indice", "categoria")):
                propios[f["codigo"].strip()] = f

    cuenta = defaultdict(int)
    sitios = c_nat.get("sitios", {})
    for cod, f in fichas.items():
        for k in ("natura2000", "art17", "art12", "tallaMinima", "introduccion", "vulnerabilidad"):
            f.pop(k, None)
        n, bi = norm(f["nombre"]), binomio(f["nombre"])
        especie = n == bi

        cods = (c_nat.get("especies") or {}).get(n) or ((c_nat.get("especies") or {}).get(bi) if especie else None)
        if cods:
            f["natura2000"] = {"espacios": [{"codigo": x, "nombre": sitios[x]["nombre"], "tipo": sitios[x]["tipo"]} for x in cods if x in sitios],
                               "fuente": "Agencia Europea de Medio Ambiente · Natura 2000 (end 2024 rev. 1)",
                               "url": "https://natura2000.eea.europa.eu/"}
            cuenta["natura2000"] += 1

        a17 = (c_art.get("a17") or {}).get(n) or ((c_art.get("a17") or {}).get(bi) if especie else None)
        if a17:
            f["art17"] = {**a17, "periodo": "2013-2018", "fuente": "Informe del artículo 17 de la Directiva Hábitats (EEA)",
                          "url": "https://nature-art17.eionet.europa.eu/article17/species/summary/"}
            cuenta["art17"] += 1
        if f.get("grupo") == "Aves":
            a12 = (c_art.get("a12") or {}).get(n) or ((c_art.get("a12") or {}).get(bi) if especie else None)
            if a12:
                f["art12"] = {**a12, "periodo": "2013-2018", "fuente": "Informe del artículo 12 de la Directiva Aves (EEA)",
                              "url": "https://nature-art12.eionet.europa.eu/article12/summary"}
                cuenta["art12"] += 1

        if f.get("grupo") == "Peces" and c_tal.get("filas"):
            t = talla_de(f["nombre"], c_tal["filas"])
            if t:
                f["tallaMinima"] = {"valor": t["talla"] if re.search(r"[a-z]", t["talla"]) else f"{t['talla']} cm",
                                    "especieNorma": t["especie"], "local": t["local"],
                                    "norma": "Real Decreto 560/1995, anexo III (caladero canario), texto consolidado",
                                    "url": "https://www.boe.es/buscar/act.php?id=BOE-A-1995-8639"}
                cuenta["tallaMinima"] += 1

        if f.get("nivel") == "introducido":
            d = (c_com.get("fichas") or {}).get(bi)
            if d:
                f["introduccion"] = {k: d[k] for k in ("fecha", "via", "dispersion", "origen", "islas", "autor", "ano", "pagina", "nombre") if d.get(k)}
                f["introduccion"].update({"fuente": "Compendio de fichas de la Base de especies introducidas en Canarias (2008-2011), Gobierno de Canarias",
                                          "url": COMPENDIO})
                cuenta["introduccion"] += 1

        p = propios.get(cod)
        if p:
            f["vulnerabilidad"] = {"indice": (p.get("indice") or "").strip(), "categoria": (p.get("categoria") or "").strip(),
                                   "fuente": (p.get("fuente") or "Datos propios").strip(), "url": (p.get("url") or "").strip()}
            cuenta["vulnerabilidad"] += 1

    for c, f in fichas.items():
        rutas[c].write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    for e in indice:
        e.pop("n2", None)
        if fichas[e["c"]].get("natura2000"):
            e["n2"] = 1
    (DATOS / "indice.json").write_text(json.dumps(indice, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = cargar_json(DATOS / "meta.json", {})
    meta["conservacion"] = {"fecha": HOY, **cuenta}
    (DATOS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Conservación: {dict(cuenta)} · {round((time.time() - inicio) / 60, 1)} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
