"""Completa las fichas con categoría UICN, tamaño, forma, peso, longevidad y ciclo de vida.

Fuentes (por orden de preferencia, cada dato guarda la suya):
  - Tabla propia: datos-propios/tamanos.csv (si existe; manda sobre todo lo demás)
  - UICN: Lista Roja de la UICN a través de GBIF (api.gbif.org, versión publicada en GBIF)
  - Peces: FishBase (tabla «species», vía rfishbase en HuggingFace)
  - Longevidad y peso de vertebrados: AnAge (Human Ageing Genomic Resources)
  - Especies protegidas: texto de «Claves de identificación» de Centinela
  - Wikidata (altura, longitud, masa, esperanza de vida)
  - Wikipedia en español (sección de descripción)

Se ejecuta en GitHub Actions después de scripts/descargar.py. Usa cachés en datos/extra/
para no repetir miles de consultas cada mes.

Uso:
  python scripts/enriquecer.py
  python scripts/enriquecer.py --limite 50   # prueba
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
PROPIOS = RAIZ / "datos-propios" / "tamanos.csv"
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
FISHBASE = "https://huggingface.co/datasets/cboettig/fishbase/resolve/main/data/fb/v23.05/parquet/species.parquet"
ANAGE = "https://genomics.senescence.info/species/dataset.zip"
HOY = date.today().isoformat()

UICN_ES = {
    "EX": "Extinta", "EW": "Extinta en estado silvestre", "CR": "En peligro crítico", "EN": "En peligro",
    "VU": "Vulnerable", "NT": "Casi amenazada", "LC": "Preocupación menor", "DD": "Datos insuficientes",
    "NE": "No evaluada",
}
RANGOS = {"subsp.", "var.", "f.", "×", "x"}

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=4, **kw):
    espera = 3
    for n in range(intentos):
        try:
            r = s.get(url, params=params, timeout=120, **kw)
            if r.status_code in (200, 204, 404):
                return r
            if r.status_code == 429:
                time.sleep(int(r.headers.get("Retry-After", espera)))
        except requests.RequestException as e:  # noqa: PERF203
            if n == intentos - 1:
                print(f"  sin respuesta {url}: {e}", flush=True)
                return None
        time.sleep(espera)
        espera *= 2
    return None


def binomio(nombre: str) -> str:
    return " ".join([t for t in nombre.split() if t not in RANGOS][:2])


def num(x: str) -> float:
    return float(x.replace(",", "."))


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


# ------------------------------------------------------------------ GBIF / UICN

def uicn_gbif(fichas: dict, cache: dict) -> None:
    pendientes = [c for c, f in fichas.items() if caducado(cache.get(c, {}).get("fecha"), 90)]
    print(f"GBIF/UICN: {len(pendientes)} por consultar ({len(fichas) - len(pendientes)} en caché)", flush=True)

    def una(cod):
        f = fichas[cod]
        reino = "Plantae" if f.get("reino") == "Flora" else "Animalia"
        r = get("https://api.gbif.org/v1/species/match", params={"name": f["nombre"], "kingdom": reino})
        out = {"fecha": HOY, "v": 3}
        if not r or r.status_code != 200:
            return cod, out
        m = r.json()
        if m.get("matchType") not in ("EXACT", "FUZZY") or m.get("confidence", 0) < 90:
            return cod, {**out, "sinCoincidencia": m.get("matchType")}
        clave = m.get("acceptedUsageKey") or m.get("usageKey")
        out.update({"clave": clave, "claveEspecie": m.get("speciesKey"), "rango": m.get("rank"), "nombreGbif": m.get("scientificName")})
        probados = set()
        for k in (clave, m.get("speciesKey")):
            if not k or k in probados:
                continue
            probados.add(k)
            ri = get(f"https://api.gbif.org/v1/species/{k}/iucnRedListCategory")
            if ri and ri.status_code == 200 and ri.text.strip():
                j = ri.json()
                if j.get("code"):
                    out["uicn"] = {"codigo": j["code"], "iucnId": j.get("iucnTaxonID"), "nombre": j.get("scientificName", "")}
                    break
        return cod, out

    with ThreadPoolExecutor(6) as ex:
        for n, (cod, res) in enumerate(ex.map(una, pendientes), 1):
            cache[cod] = res
            if n % 500 == 0:
                print(f"  GBIF {n}/{len(pendientes)}", flush=True)


# --------------------------------------------------------------------- FishBase

def fishbase() -> dict:
    try:
        import pandas as pd
        r = get(FISHBASE)
        if not r or r.status_code != 200:
            return {}
        df = pd.read_parquet(io.BytesIO(r.content), columns=["Genus", "Species", "Length", "LTypeMaxM", "Weight", "LongevityWild", "SpecCode"])
    except Exception as e:  # noqa: BLE001
        print(f"FishBase no disponible: {e}", flush=True)
        return {}
    out = {}
    for row in df.itertuples(index=False):
        out[f"{row.Genus} {row.Species}"] = {
            "longitud": float(row.Length) if row.Length == row.Length and row.Length else None,
            "tipoLongitud": row.LTypeMaxM if isinstance(row.LTypeMaxM, str) else "",
            "peso": float(row.Weight) if row.Weight == row.Weight and row.Weight else None,
            "longevidad": float(row.LongevityWild) if row.LongevityWild == row.LongevityWild and row.LongevityWild else None,
            "codigo": int(row.SpecCode),
        }
    print(f"FishBase: {len(out)} especies", flush=True)
    return out


# ------------------------------------------------------------------------ AnAge

def anage() -> dict:
    r = get(ANAGE)
    if not r or r.status_code != 200:
        print("AnAge no disponible", flush=True)
        return {}
    z = zipfile.ZipFile(io.BytesIO(r.content))
    nombre = [n for n in z.namelist() if n.endswith(".txt")][0]
    filas = list(csv.DictReader(io.StringIO(z.read(nombre).decode("latin-1")), delimiter="\t"))
    out = {}
    for f in filas:
        def v(k):
            try:
                return float(f.get(k) or "")
            except ValueError:
                return None
        out[f"{f['Genus']} {f['Species']}"] = {
            "longevidad": v("Maximum longevity (yrs)"), "origen": f.get("Specimen origin", ""),
            "calidad": f.get("Data quality", ""), "peso": v("Adult weight (g)"), "id": f.get("HAGRID"),
        }
    print(f"AnAge: {len(out)} especies", flush=True)
    return out


# --------------------------------------------------------------------- Wikidata

UNIDADES = {"Q11573": 1, "Q174728": 0.01, "Q174789": 0.001, "Q828224": 1000,  # m, cm, mm, km
            "Q11570": 1, "Q41803": 0.001, "Q191118": 1000,  # kg, g, t
            "Q577": 1, "Q5151": 1 / 12, "Q573": 1 / 365, "Q23387": 1 / 52}  # año, mes, día, semana


def wikidata(nombres: list[str], cache: dict) -> None:
    pendientes = [n for n in nombres if caducado(cache.get(n, {}).get("fecha"), 120)]
    print(f"Wikidata: {len(pendientes)} nombres por consultar", flush=True)
    for i in range(0, len(pendientes), 120):
        lote = pendientes[i:i + 120]
        valores = " ".join('"' + n.replace('"', "") + '"' for n in lote)
        q = f"""SELECT ?name ?item ?p ?v ?u WHERE {{
          VALUES ?name {{ {valores} }}
          ?item wdt:P225 ?name.
          VALUES ?p {{ "P2048" "P2043" "P2067" "P2250" "P4214" }}
          ?item ?pp ?st. ?st ?psv ?val.
          ?prop wikibase:directClaim ?dc; wikibase:claim ?pp; wikibase:statementValue ?psv.
          FILTER(STRAFTER(STR(?prop), "entity/") = ?p)
          ?val wikibase:quantityAmount ?v; wikibase:quantityUnit ?u.
        }}"""
        r = None
        for _ in range(3):
            r = get("https://query.wikidata.org/sparql", params={"query": q, "format": "json"})
            if r and r.status_code == 200:
                break
            time.sleep(10)
        for n in lote:
            cache[n] = {"fecha": HOY}
        if not r or r.status_code != 200:
            continue
        for b in r.json()["results"]["bindings"]:
            n = b["name"]["value"]
            u = b["u"]["value"].rsplit("/", 1)[-1]
            if u not in UNIDADES:
                continue
            valor = float(b["v"]["value"]) * UNIDADES[u]
            clave = {"P2048": "altura", "P2043": "longitud", "P2067": "masa", "P2250": "esperanza", "P4214": "longevidad"}[b["p"]["value"]]
            cache[n].setdefault(clave, valor)
            cache[n]["item"] = b["item"]["value"].rsplit("/", 1)[-1]
        time.sleep(1.5)


# -------------------------------------------------------------- textos (es)

ORGANOS = (r"hoja|flor|pétalo|fruto|semilla|sépalo|corola|cáliz|cálice|inflorescencia|bráctea|espiga|espiguilla|pedúnculo|pedicelo|"
           r"limbo|folíolo|foliolo|cápsula|aquenio|pico|cola|ala|huevo|cabeza|tarso|aleta|antena|raíz|raíce|bulbo|fronde|pinna|"
           r"racimo|panícula|capítulo|estambre|espina|lámina|pecíolo|peciolo|vaina|legumbre|baya|drupa|nuez|gluma|lema|segmento|"
           r"lóbulo|diente|pelo|escama|tubérculo|rizoma|cono|piña|aguja|acícula|estípula|nervio|garra|uña|oreja|pata|cresta|"
           r"dedo|antebrazo|trago|uropatagio|patagio|pie|cuello|hocico")
ORG_RE = re.compile(rf"\b(?:{ORGANOS})(?:s|es)?\b")
TODO_RE = re.compile(r"\b(planta|arbusto|árbol|ejemplar|individuo|adulto|adultos|mata|cuerpo total|total|porte|tallos?|cañas?)\b")
EXCLUIR_RE = re.compile(r"profundidad|diámetro|grosor|ancho|anchura|espesor|distancia|separad|siembra|sembrar|circunferencia|perímetro|altitud|metros sobre|m s\. ?n\. ?m|msnm|cota|kilómetro")
MEDIDA = re.compile(
    r"(\d+(?:[.,]\d+)?)(?:\s*(?:-|–|a|y|hasta)\s*(\d+(?:[.,]\d+)?))?\s*(milímetros|mm|centímetros|cm|metros|m)\b(?!²|2)(.{0,40})",
    re.I | re.S)
FACTOR = {"mm": 0.001, "milímetros": 0.001, "cm": 0.01, "centímetros": 0.01, "m": 1, "metros": 1}
RANGO = {"Flora": (0.02, 70), "Aves": (0.07, 1.5), "Reptiles": (0.03, 3), "Anfibios": (0.02, 0.3), "Mamíferos": (0.03, 35), "Peces": (0.01, 20)}
ETIQ_PLANTA = re.compile(r"altura|alto|alta|talla|porte|alcanza|alcanzan|mide|miden|crece|crecen|de hasta|llega")


def cita_frase(texto: str, ini: int, fin: int) -> str:
    """La frase que contiene la medida, sin restos de formato de Wikipedia."""
    cortes = [(texto.rfind(". ", 0, ini), 2), (texto.rfind("\n", 0, ini), 1), (texto.rfind("==", 0, ini), 2)]
    a = max((p + d for p, d in cortes if p >= 0), default=0)
    if ini - a > 140:
        a = texto.find(" ", ini - 120) + 1
    b = min([x for x in (texto.find(". ", fin), texto.find("\n", fin)) if x >= 0] or [len(texto)])
    if b - fin > 90:
        b = texto.rfind(" ", fin, fin + 90)
    frase = re.sub(r"\s+", " ", texto[a:b]).strip(" =,;")
    return frase[0].upper() + frase[1:] if frase else frase


def medidas(texto: str, animal: bool, grupo: str = "") -> dict | None:
    """Primera medida del organismo entero en un texto (ignora órganos, profundidades, envergaduras…)."""
    lo, hi = RANGO.get(grupo, RANGO["Flora"] if not animal else (0.01, 35))
    for m in MEDIDA.finditer(texto):
        antes = texto[max(0, m.start() - 70):m.start()].lower()
        despues = (m.group(4) or "").lower()
        cerca = antes[-45:]
        org = ORG_RE.search(cerca)
        if org and not TODO_RE.search(cerca[-30:]):
            # En plantas en roseta (tajinastes) la inflorescencia marca la altura de la planta
            if not (not animal and org.group(0).startswith("inflorescencia") and m.group(3).lower() in ("m", "metros")):
                continue
        if EXCLUIR_RE.search(cerca[-35:] + " " + despues[:25]):
            continue
        if re.search(r"(\d\s*(por|x|×)\s*$)", antes[-8:]) or re.match(r"\s*(por|x|×)\s*\d", despues):
            continue  # «9 por 4 cm»: dimensiones de un órgano
        # La etiqueta más cercana decide qué se mide
        etiquetas = [(cerca.rfind(k), k) for k in ("envergadura", "longitud", "largo", "altura", "alto", "talla", "mide", "alcanza")]
        previa = max(etiquetas)[1] if max(etiquetas)[0] >= 0 else ""
        siguiente = re.match(r"\s*(de\s+)?(envergadura|longitud|largo|altura|alto|alta|talla)", despues)
        etiqueta = siguiente.group(2) if siguiente else previa
        if etiqueta == "envergadura":
            continue
        if animal:
            if not re.search(r"longitud|largo|mide|miden|medir|talla|tamaño|alcanza|de hasta|de unos|cuerpo|total", cerca + " " + despues) \
                    and not re.search(r"\b(pájaro|ave|lagarto|pez|ballena|delfín|murciélago|rata|musaraña|tortuga|culebra|rana|ejemplar|adulto)\b", cerca):
                continue
        else:
            if etiqueta in ("largo", "longitud") and not re.search(r"\btallos?\b|\bcañas?\b|\bplanta\b", cerca):
                continue
            if not (ETIQ_PLANTA.search(cerca[-30:] + " " + despues[:20]) or re.match(r"\s*(de\s+)?(altura|alto|alta)", despues)
                    or re.search(r"\b(arbusto|árbol|planta|hierba|mata|semiarbusto|subarbusto|matorral|tallos?)\b[^.]{0,25}$", cerca)):
                continue
        f = FACTOR[m.group(3).lower()]
        a = num(m.group(1)) * f
        b = num(m.group(2)) * f if m.group(2) else None
        if b is not None and b < a:
            a, b = b, a
        maximo = b or a
        if not (lo <= maximo <= hi):
            continue
        tipo = "longitud" if animal else "altura"
        if re.search(r"cabeza[- ]cuerpo|cabeza y cuerpo|hocico[- ]cloaca|lhc|svl", cerca + despues):
            tipo = "longitud cabeza-cuerpo"
        cita = cita_frase(texto, m.start(), m.end() - len(m.group(4) or ""))
        return {"min": round(a, 3) if b else None, "max": round(maximo, 3), "tipo": tipo, "cita": cita}
    return None


FORMAS_TXT = [
    ("palmera", r"\bpalmera\b"), ("helecho", r"\bhelecho"), ("roseta", r"\broseta\b"),
    ("cactiforme", r"cactiforme|candelabro"),
    ("árbol", r"\bárbol|arbórea|arbóreo|porte arbóreo|(?<!nano)fanerófito"),
    ("trepadora", r"trepadora|enredadera|liana|voluble"),
    ("arbusto", r"\barbusto|arbustiva|arbustivo|subarbusto|semiarbusto|sufrútice|mata\b|matorral|caméfito|nanofanerófito"),
    ("hierba", r"\bhierba|herbácea|herbáceo|gramínea|geófito|bulbosa|terófito|hemicriptófito|planta anual|planta perenne"),
]


def forma_texto(texto: str) -> str | None:
    t = texto.lower()[:400]
    for forma, patron in FORMAS_TXT:
        if re.search(patron, t):
            return forma
    return None


def ciclo_texto(texto: str) -> str | None:
    t = texto.lower()
    if re.search(r"monocárpic", t):
        return "Monocárpica (florece una vez y muere)"
    if re.search(r"\bbienal", t):
        return "Bienal"
    if re.search(r"(planta|hierba|especie|herbácea|es)\s+anual|\bterófito|\banuales\b", t):
        return "Anual"
    if re.search(r"perenne|vivaz|perennifoli|leñosa|leñoso|árbol|arbusto", t):
        return "Perenne"
    return None


def wikipedia(binomios: list[str], cache: dict) -> None:
    # v2: guarda también la sección de etimología
    pendientes = [b for b in binomios if caducado(cache.get(b, {}).get("fecha"), 180) or cache.get(b, {}).get("v") != 3]
    print(f"Wikipedia: {len(pendientes)} artículos por consultar", flush=True)

    def una(nombre):
        r = get("https://es.wikipedia.org/w/api.php", params={
            "action": "query", "prop": "extracts|info", "explaintext": 1, "redirects": 1, "format": "json", "titles": nombre})
        out = {"fecha": HOY, "v": 2}
        if not r or r.status_code != 200:
            return nombre, out
        paginas = list(r.json().get("query", {}).get("pages", {}).values())
        if not paginas or "missing" in paginas[0]:
            return nombre, out
        p = paginas[0]
        texto = p.get("extract") or ""
        genero = nombre.split()[0]
        if genero.lower() not in texto[:1500].lower() or "puede referirse a" in texto[:300]:
            return nombre, out
        partes = re.split(r"\n==+\s*", texto)
        intro = partes[0]
        desc = next((x for x in partes[1:] if re.match(r"(descripción|morfología|características)", x, re.I)), "")
        etim = next((x for x in partes[1:] if re.match(r"etimolog", x, re.I)), "")
        if not etim:
            # En muchas fichas de plantas la etimología va dentro de «Taxonomía» como un párrafo titulado
            m = re.search(r"\n\s*Etimolog[íi]a\s*\n(.+?)(?=\n\s*(?:Sinonimia|Nombres? comunes?|Citolog[íi]a|Variedades|Referencias|Véase también|"
                          r"Enlaces externos|Bibliograf[íi]a|Especies|Subespecies|Taxones infraespecíficos)\s*\n|\n==|$)", texto, re.S)
            etim = ("Etimología\n" + m.group(1)) if m else ""
        out.update({"titulo": p.get("title"), "url": f"https://es.wikipedia.org/wiki/{quote(p.get('title', '').replace(' ', '_'))}",
                    "texto": (intro[:600] + "\n" + desc[:2500]).strip()})
        if etim:
            out["etim"] = re.sub(r"^etimolog[íi]a\s*=*\s*", "", etim, flags=re.I).strip()[:1500]
        return nombre, out

    with ThreadPoolExecutor(3) as ex:
        for n, (nombre, res) in enumerate(ex.map(una, pendientes), 1):
            cache[nombre] = res
            if n % 300 == 0:
                print(f"  Wikipedia {n}/{len(pendientes)}", flush=True)


# ------------------------------------------------------------------- formas

FAM_ANIMAL = {
    "tortuga": {"Cheloniidae", "Dermochelyidae", "Testudinidae", "Emydidae", "Geoemydidae"},
    "serpiente": {"Colubridae", "Typhlopidae", "Boidae", "Pythonidae", "Lamprophiidae", "Natricidae"},
    "cetaceo": {"Delphinidae", "Balaenopteridae", "Physeteridae", "Ziphiidae", "Kogiidae", "Phocoenidae", "Balaenidae"},
    "murcielago": {"Vespertilionidae", "Molossidae", "Rhinolophidae", "Pteropodidae"},
    "foca": {"Phocidae", "Otariidae"},
    "raya": {"Rajidae", "Dasyatidae", "Myliobatidae", "Torpedinidae", "Mobulidae", "Gymnuridae", "Rhinobatidae", "Narcinidae"},
}


def forma_animal(f: dict) -> str:
    fam = (f.get("taxonomia") or {}).get("Familia", "")
    for forma, familias in FAM_ANIMAL.items():
        if fam in familias:
            return {"foca": "mamifero"}.get(forma, forma)
    g = f.get("grupo")
    if g == "Aves":
        return "ave"
    if g == "Reptiles":
        return "lagarto"
    if g == "Anfibios":
        return "rana"
    if g == "Mamíferos":
        return "mamifero"
    if g == "Peces":
        return "tiburon" if f.get("subgrupo") == "Cartilaginosos" else "pez"
    return "mamifero"


def forma_planta(f: dict, texto_forma: str | None, altura: float | None) -> str:
    fam = (f.get("taxonomia") or {}).get("Familia", "")
    gen = f["nombre"].split()[0]
    if f.get("grupo") == "Helechos":
        return "helecho"
    if fam == "Arecaceae":
        return "palmera"
    if f["nombre"].startswith(("Euphorbia canariensis", "Euphorbia handiensis")):
        return "cactiforme"
    if gen in {"Aeonium", "Greenovia", "Aichryson", "Monanthes"} or f["nombre"].startswith(("Echium wildpretii", "Echium simplex", "Echium pininana", "Echium auberianum")):
        return "roseta"
    if texto_forma:
        return texto_forma
    if fam in {"Pinaceae", "Cupressaceae", "Lauraceae", "Aquifoliaceae", "Myricaceae", "Oleaceae", "Salicaceae", "Theaceae", "Taxaceae"} and (altura or 5) > 3:
        return "árbol"
    if altura is not None:
        return "árbol" if altura >= 4 else "arbusto" if altura >= 0.6 else "hierba"
    return "planta"


# ----------------------------------------------------------------- composición

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limite", type=int, default=0)
    args = ap.parse_args()
    EXTRA.mkdir(parents=True, exist_ok=True)
    inicio = time.time()

    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    if args.limite:
        indice = indice[: args.limite]
    fichas = {e["c"]: json.loads((DATOS / "fichas" / f"{e['c']}.json").read_text(encoding="utf-8")) for e in indice}

    c_gbif = cargar_json(EXTRA / "gbif.json", {})
    c_wd = cargar_json(EXTRA / "wikidata.json", {})
    c_wp = cargar_json(EXTRA / "wikipedia.json", {})

    uicn_gbif(fichas, c_gbif)
    fb = fishbase() if any(f.get("grupo") == "Peces" for f in fichas.values()) else {}
    ag = anage()
    binomios = sorted({binomio(f["nombre"]) for f in fichas.values()})
    wikidata(binomios, c_wd)
    wikipedia(binomios, c_wp)

    propios = {}
    if PROPIOS.exists():
        for fila in csv.DictReader(PROPIOS.open(encoding="utf-8"), delimiter=";"):
            if fila.get("codigo"):
                propios[fila["codigo"].strip()] = fila

    tabla = []
    cuenta = {"uicn": 0, "tamano": 0, "peso": 0, "longevidad": 0, "ciclo": 0}
    for cod, f in fichas.items():
        animal = f.get("reino") == "Fauna"
        grupo = f.get("grupo") if animal else "Flora"
        bi = binomio(f["nombre"])
        sub = bi != f["nombre"]
        wd, wp = c_wd.get(bi, {}), c_wp.get(bi, {})
        cent = ((f.get("centinela") or {}).get("secciones") or {}).get("Claves de identificación", "")
        primera = re.split(r"(?<=[a-záéíóú\)])\.\s", cent)[0] if cent else ""
        for k in ("uicn", "tamano", "peso", "longevidad", "ciclo", "forma"):
            f.pop(k, None)

        # UICN
        g = c_gbif.get(cod, {})
        if g.get("uicn"):
            u = g["uicn"]
            f["uicn"] = {"codigo": u["codigo"], "categoria": UICN_ES.get(u["codigo"], u["codigo"]),
                         "nivel": "especie" if (sub and f["nombre"].split()[-1] not in u.get("nombre", "")) else "taxón",
                         "fuente": "Lista Roja de la UICN (versión 2022-2) vía GBIF",
                         "url": f"https://www.gbif.org/species/{g.get('clave')}" if g.get("clave") else None,
                         "iucnId": u.get("iucnId")}
        if g.get("clave"):
            f["gbifClave"] = g["clave"]

        # Tamaño
        tam = None
        if animal and f.get("grupo") == "Peces" and fb.get(bi, {}).get("longitud"):
            x = fb[bi]
            tipo = {"TL": "longitud total", "SL": "longitud estándar", "FL": "longitud a la horquilla", "WD": "anchura del disco"}.get(x["tipoLongitud"], "longitud")
            tam = {"min": None, "max": round(x["longitud"] / 100, 3), "tipo": f"{tipo} máxima", "fuente": "FishBase",
                   "url": f"https://www.fishbase.se/summary/{x['codigo']}"}
        if not tam and primera:
            t = medidas(primera, animal, grupo) or medidas(cent[:600], animal, grupo)
            if t:
                tam = {**t, "fuente": "Centinela (claves de identificación)", "url": f"https://www.biodiversidadcanarias.es/centinela/especie/{cod}"}
        if not tam and (wd.get("altura") or wd.get("longitud")):
            v = wd.get("longitud") if animal and wd.get("longitud") else (wd.get("altura") or wd.get("longitud"))
            lo, hi = RANGO.get(grupo, (0.01, 70))
            if lo <= v <= hi:
                tam = {"min": None, "max": round(v, 3), "tipo": "longitud" if animal else "altura", "fuente": "Wikidata",
                       "url": f"https://www.wikidata.org/wiki/{wd.get('item')}"}
        if not tam and wp.get("texto"):
            t = medidas(wp["texto"], animal, grupo)
            if t:
                tam = {**t, "fuente": "Wikipedia (es)", "url": wp.get("url")}
        if tam:
            if sub and tam["fuente"] in ("FishBase", "Wikidata", "Wikipedia (es)"):
                tam["nivel"] = "especie"
            f["tamano"] = tam

        # Peso
        if animal:
            if f.get("grupo") == "Peces" and fb.get(bi, {}).get("peso"):
                f["peso"] = {"kg": round(fb[bi]["peso"] / 1000, 4), "tipo": "máximo", "fuente": "FishBase"}
            elif ag.get(bi, {}).get("peso"):
                f["peso"] = {"kg": round(ag[bi]["peso"] / 1000, 4), "tipo": "adulto", "fuente": "AnAge",
                             "url": f"https://genomics.senescence.info/species/entry.php?species={quote(bi.replace(' ', '_'))}"}

        # Longevidad (animales) y ciclo de vida (plantas)
        if animal:
            if ag.get(bi, {}).get("longevidad"):
                a = ag[bi]
                f["longevidad"] = {"anos": a["longevidad"], "tipo": "máxima registrada",
                                   "origen": {"captivity": "en cautividad", "wild": "en libertad"}.get(a["origen"], ""),
                                   "fuente": "AnAge", "url": f"https://genomics.senescence.info/species/entry.php?species={quote(bi.replace(' ', '_'))}"}
            elif f.get("grupo") == "Peces" and fb.get(bi, {}).get("longevidad"):
                f["longevidad"] = {"anos": fb[bi]["longevidad"], "tipo": "máxima en libertad", "origen": "", "fuente": "FishBase"}
            elif wd.get("longevidad") or wd.get("esperanza"):
                f["longevidad"] = {"anos": round(wd.get("longevidad") or wd.get("esperanza"), 1), "tipo": "máxima" if wd.get("longevidad") else "esperanza de vida",
                                   "origen": "", "fuente": "Wikidata", "url": f"https://www.wikidata.org/wiki/{wd.get('item')}"}
        else:
            c = ciclo_texto(cent) if cent else None
            fuente = "Centinela"
            if not c and wp.get("texto"):
                c, fuente = ciclo_texto(wp["texto"]), "Wikipedia (es)"
            if c:
                f["ciclo"] = {"valor": c, "fuente": fuente}

        # Forma (para la silueta del diagrama)
        if animal:
            f["forma"] = {"valor": forma_animal(f), "fuente": "Grupo y familia"}
        else:
            tf = forma_texto(primera) if primera else None
            fuente = "Centinela"
            if not tf and wp.get("texto"):
                tf, fuente = forma_texto(wp["texto"]), "Wikipedia (es)"
            f["forma"] = {"valor": forma_planta(f, tf, (f.get("tamano") or {}).get("max")), "fuente": fuente if tf else "Familia o tamaño"}

        # Tabla propia: manda sobre todo
        p = propios.get(cod)
        if p:
            def fl(k):
                try:
                    return float((p.get(k) or "").replace(",", "."))
                except ValueError:
                    return None
            if fl("tamano_max_m"):
                f["tamano"] = {"min": fl("tamano_min_m"), "max": fl("tamano_max_m"), "tipo": p.get("medida") or ("longitud" if animal else "altura"),
                               "fuente": p.get("fuente") or "Tabla propia"}
            if p.get("forma"):
                f["forma"] = {"valor": p["forma"].strip(), "fuente": p.get("fuente") or "Tabla propia"}
            if fl("longevidad_anos"):
                f["longevidad"] = {"anos": fl("longevidad_anos"), "tipo": "máxima", "origen": "", "fuente": p.get("fuente") or "Tabla propia"}
            if p.get("ciclo"):
                f["ciclo"] = {"valor": p["ciclo"].strip(), "fuente": p.get("fuente") or "Tabla propia"}

        for k in cuenta:
            cuenta[k] += 1 if f.get(k) else 0
        (DATOS / "fichas" / f"{cod}.json").write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        tabla.append({
            "codigo": cod, "nombre": f["nombre"], "comun": (f.get("comunes") or [""])[0], "grupo": f.get("grupo"),
            "forma": f["forma"]["valor"], "tamano_min_m": (f.get("tamano") or {}).get("min") or "",
            "tamano_max_m": (f.get("tamano") or {}).get("max") or "", "medida": (f.get("tamano") or {}).get("tipo", ""),
            "fuente_tamano": (f.get("tamano") or {}).get("fuente", ""), "peso_kg": (f.get("peso") or {}).get("kg", ""),
            "fuente_peso": (f.get("peso") or {}).get("fuente", ""), "longevidad_anos": (f.get("longevidad") or {}).get("anos", ""),
            "fuente_longevidad": (f.get("longevidad") or {}).get("fuente", ""), "ciclo": (f.get("ciclo") or {}).get("valor", ""),
            "uicn": (f.get("uicn") or {}).get("codigo", ""),
        })

    # Índice: categoría UICN, forma y tamaño
    for e in indice:
        f = fichas[e["c"]]
        e["ui"] = (f.get("uicn") or {}).get("codigo", "")
        e["fm"] = (f.get("forma") or {}).get("valor", "")
        e["tm"] = (f.get("tamano") or {}).get("max")
    if not args.limite:
        (DATOS / "indice.json").write_text(json.dumps(indice, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    with (DATOS / "tamanos.csv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(tabla[0].keys()), delimiter=";")
        w.writeheader()
        w.writerows(sorted(tabla, key=lambda x: (x["grupo"] or "", x["nombre"])))

    for nombre, c in (("gbif.json", c_gbif), ("wikidata.json", c_wd), ("wikipedia.json", c_wp)):
        (EXTRA / nombre).write_text(json.dumps(c, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    meta = cargar_json(DATOS / "meta.json", {})
    meta["enriquecido"] = {"fecha": datetime.now(timezone.utc).isoformat(timespec="seconds"), "conDato": cuenta, "taxones": len(fichas),
                           "uicnPorCategoria": {k: sum(1 for e in indice if e.get("ui") == k) for k in UICN_ES}}
    (DATOS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Enriquecidas {len(fichas)} fichas en {(time.time() - inicio) / 60:.1f} min: {cuenta}", flush=True)
    print("UICN:", meta["enriquecido"]["uicnPorCategoria"], flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
