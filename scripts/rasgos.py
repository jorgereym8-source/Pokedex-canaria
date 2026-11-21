"""Rasgos de cada especie por grupo, con su fuente.

  - Todos: etimología del nombre (Wikipedia en español).
  - Plantas: forma vital y clima (WCVP, Kew), distribución mundial nativa e introducida
    (WCVP), número cromosomático (Chromosome Counts Database, si responde).
  - Aves: morfología, dieta, nivel trófico, hábitat, estilo de vida y migración (AVONET);
    dieta en porcentajes y actividad (EltonTraits); envergadura (Wikipedia).
  - Mamíferos: dieta y actividad (EltonTraits); envergadura de murciélagos (Wikipedia).
  - Aves, mamíferos, reptiles y anfibios: reproducción (AnAge).
  - Peces: profundidad, hábitat, nivel trófico, peligrosidad, interés pesquero,
    vulnerabilidad a la pesca, resiliencia y migración (FishBase).

Escribe en cada ficha «rasgos» (lista de filas {grupo, k, v, fuente, url}), «mundo» y
«etimologia». Se ejecuta en GitHub Actions después de enriquecer.py.
"""

from __future__ import annotations

import csv
import io
import json
import re
import sys
import time
import zipfile
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import quote

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
HOY = date.today().isoformat()
RANGOS = {"subsp.", "var.", "f.", "×", "x", "nothosubsp."}

ANAGE = "https://genomics.senescence.info/species/dataset.zip"
AVONET = "https://ndownloader.figshare.com/files/34480856"
ELTON_AVES = "https://esapubs.org/archive/ecol/E095/178/BirdFuncDat.txt"
ELTON_MAM = "https://esapubs.org/archive/ecol/E095/178/MamFuncDat.txt"
WCVP = "https://sftp.kew.org/pub/data-repositories/WCVP/wcvp.zip"
FB = "https://huggingface.co/datasets/cboettig/fishbase/resolve/main/data/fb/v23.05/parquet/"
CCDB = "https://ccdb.tau.ac.il/services/countsFull/"

URL_FUENTE = {
    "AnAge": "https://genomics.senescence.info/species/",
    "AVONET": "https://doi.org/10.1111/ele.13898",
    "EltonTraits": "https://doi.org/10.1890/13-1917.1",
    "WCVP (Kew)": "https://powo.science.kew.org/",
    "FishBase": "https://www.fishbase.se/",
    "CCDB": "https://ccdb.tau.ac.il/",
}

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=3, timeout=300, **kw):
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


def caducado(fecha: str | None, dias: int) -> bool:
    if not fecha:
        return True
    try:
        return date.fromisoformat(fecha) < date.today() - timedelta(days=dias)
    except ValueError:
        return True


def binomio(nombre: str) -> str:
    return " ".join([t for t in nombre.split() if t not in RANGOS][:2])


def flt(x):
    try:
        v = float(str(x).replace(",", "."))
        return None if v != v else v  # NaN
    except (TypeError, ValueError):
        return None


def num(v: float, dec: int = 1) -> str:
    t = f"{v:,.{dec}f}".replace(",", " ").replace(".", ",").replace(" ", ".")
    return t[:-(dec + 1)] if dec and t.endswith("," + "0" * dec) else t


def dias_texto(d: float) -> str:
    if d >= 730:
        return f"{num(d / 365, 1)} años"
    if d >= 60:
        return f"{num(d / 30.4, 1)} meses"
    return f"{num(d, 0)} días"


def fila(grupo, k, v, fuente, url=None):
    return {"grupo": grupo, "k": k, "v": v, "fuente": fuente, "url": url or URL_FUENTE.get(fuente, "")}


# ---------------------------------------------------------------------- AnAge

def anage() -> dict:
    r = get(ANAGE)
    if not r or r.status_code != 200:
        print("AnAge no disponible", flush=True)
        return {}
    z = zipfile.ZipFile(io.BytesIO(r.content))
    nombre = [n for n in z.namelist() if n.endswith(".txt")][0]
    out = {}
    for f in csv.DictReader(io.StringIO(z.read(nombre).decode("latin-1")), delimiter="\t"):
        out[f"{f['Genus']} {f['Species']}"] = f
    print(f"AnAge: {len(out)} especies", flush=True)
    return out


def rasgos_anage(f: dict) -> list[dict]:
    filas = []
    url = f"https://genomics.senescence.info/species/entry.php?species={f['Genus']}_{f['Species']}"
    fem, mac = flt(f.get("Female maturity (days)")), flt(f.get("Male maturity (days)"))
    if fem or mac:
        if fem and mac and abs(fem - mac) > 30:
            v = f"hembras {dias_texto(fem)}, machos {dias_texto(mac)}"
        else:
            v = dias_texto(fem or mac)
        filas.append(fila("Reproducción", "Madurez sexual", v, "AnAge", url))
    ges = flt(f.get("Gestation/Incubation (days)"))
    if ges:
        k = "Incubación" if f.get("Class") in ("Aves", "Reptilia", "Amphibia") else "Gestación"
        filas.append(fila("Reproducción", k, dias_texto(ges), "AnAge", url))
    pu = flt(f.get("Litter/Clutch size"))
    if pu:
        k = "Huevos por puesta" if f.get("Class") in ("Aves", "Reptilia", "Amphibia") else "Crías por parto"
        filas.append(fila("Reproducción", k, num(pu, 1), "AnAge", url))
    pa = flt(f.get("Litters/Clutches per year"))
    if pa:
        filas.append(fila("Reproducción", "Puestas o partos al año", num(pa, 1), "AnAge", url))
    pn = flt(f.get("Birth weight (g)"))
    if pn:
        filas.append(fila("Reproducción", "Peso al nacer o eclosionar", f"{num(pn, 1)} g", "AnAge", url))
    return filas


# --------------------------------------------------------------------- AVONET

NICHO = {"Frugivore": "frugívoro (frutos)", "Granivore": "granívoro (semillas)", "Nectarivore": "nectarívoro (néctar)",
         "Herbivore aquatic": "herbívoro acuático", "Herbivore terrestrial": "herbívoro terrestre",
         "Invertivore": "invertebrados", "Vertivore": "vertebrados terrestres", "Aquatic predator": "depredador acuático",
         "Scavenger": "carroñero", "Omnivore": "omnívoro"}
NIVEL_TROF = {"Herbivore": "herbívoro", "Carnivore": "carnívoro", "Omnivore": "omnívoro", "Scavenger": "carroñero"}
HABITAT_AV = {"Forest": "bosque", "Woodland": "bosque abierto", "Shrubland": "matorral", "Grassland": "pastizal",
              "Desert": "desierto", "Rock": "roquedos", "Human Modified": "medios humanizados", "Wetland": "humedales",
              "Riverine": "ríos", "Coastal": "costa", "Marine": "mar abierto"}
ESTILO = {"Aerial": "aéreo (caza en vuelo)", "Terrestrial": "terrestre (en el suelo)", "Insessorial": "en ramas y arbustos",
          "Aquatic": "acuático", "Generalist": "generalista"}
MIGRA = {"1": "sedentaria", "2": "migradora parcial", "3": "migradora"}


def avonet() -> dict:
    r = get(AVONET)
    if not r or r.status_code != 200:
        print("AVONET no disponible", flush=True)
        return {}
    import openpyxl
    wb = openpyxl.load_workbook(io.BytesIO(r.content), read_only=True, data_only=True)
    out = {}
    for hoja, col in (("AVONET2_eBird", "Species2"), ("AVONET1_BirdLife", "Species1"), ("AVONET3_BirdTree", "Species3")):
        ws = wb[hoja]
        filas = ws.iter_rows(values_only=True)
        cab = [str(c) for c in next(filas)]
        for v in filas:
            d = dict(zip(cab, v))
            n = d.get(col)
            if n and n not in out:
                out[n] = d
    print(f"AVONET: {len(out)} nombres", flush=True)
    return out


def rasgos_avonet(d: dict, nombre: str) -> list[dict]:
    filas = []
    url = "https://doi.org/10.1111/ele.13898"
    ala, pico, cola, masa = flt(d.get("Wing.Length")), flt(d.get("Beak.Length_Culmen")), flt(d.get("Tail.Length")), flt(d.get("Mass"))
    if ala:
        filas.append(fila("Morfología", "Longitud del ala", f"{num(ala / 10, 1)} cm", "AVONET", url))
    if cola:
        filas.append(fila("Morfología", "Longitud de la cola", f"{num(cola / 10, 1)} cm", "AVONET", url))
    if pico:
        filas.append(fila("Morfología", "Longitud del pico", f"{num(pico, 1)} mm", "AVONET", url))
    if masa:
        filas.append(fila("Morfología", "Peso medio", f"{num(masa, 1)} g" if masa < 1000 else f"{num(masa / 1000, 2)} kg", "AVONET", url))
    hwi = flt(d.get("Hand-Wing.Index"))
    if hwi:
        filas.append(fila("Morfología", "Índice mano-ala", f"{num(hwi, 1)} (más alto = alas más largas y apuntadas)", "AVONET", url))
    if d.get("Trophic.Niche") in NICHO:
        filas.append(fila("Alimentación", "Nicho trófico", NICHO[d["Trophic.Niche"]], "AVONET", url))
    if d.get("Trophic.Level") in NIVEL_TROF:
        filas.append(fila("Alimentación", "Nivel trófico", NIVEL_TROF[d["Trophic.Level"]], "AVONET", url))
    if d.get("Habitat") in HABITAT_AV:
        filas.append(fila("Ecología", "Hábitat principal", HABITAT_AV[d["Habitat"]], "AVONET", url))
    if d.get("Primary.Lifestyle") in ESTILO:
        filas.append(fila("Ecología", "Estilo de vida", ESTILO[d["Primary.Lifestyle"]], "AVONET", url))
    m = str(d.get("Migration") or "").split(".")[0]
    if m in MIGRA:
        filas.append(fila("Ecología", "Migración (en su área global)", MIGRA[m], "AVONET", url))
    return filas


# ---------------------------------------------------------------- EltonTraits

DIETA = {"Diet-Inv": "invertebrados", "Diet-Vend": "aves y mamíferos", "Diet-Vect": "reptiles y anfibios",
         "Diet-Vfish": "peces", "Diet-Vunk": "vertebrados", "Diet-Scav": "carroña", "Diet-Fruit": "frutos",
         "Diet-Nect": "néctar y polen", "Diet-Seed": "semillas", "Diet-PlantO": "otras partes de plantas"}
ESTRATO_AV = {"ForStrat-watbelowsurf": "bajo el agua", "ForStrat-wataroundsurf": "en la superficie del agua",
              "ForStrat-ground": "en el suelo", "ForStrat-understory": "en el sotobosque", "ForStrat-midhigh": "a media altura",
              "ForStrat-canopy": "en las copas", "ForStrat-aerial": "en el aire"}
ESTRATO_MAM = {"G": "en el suelo", "S": "en el suelo y los árboles", "Ar": "en los árboles", "A": "en el aire", "M": "en el mar"}


def elton(url: str) -> dict:
    r = get(url)
    if not r or r.status_code != 200:
        print(f"EltonTraits no disponible: {url}", flush=True)
        return {}
    out = {}
    for f in csv.DictReader(io.StringIO(r.content.decode("latin-1")), delimiter="\t"):
        if f.get("Scientific"):
            out[f["Scientific"].strip()] = f
    print(f"EltonTraits {url.rsplit('/', 1)[-1]}: {len(out)}", flush=True)
    return out


def rasgos_elton(d: dict, aves: bool) -> list[dict]:
    filas = []
    url = "https://doi.org/10.1890/13-1917.1"
    partes = sorted(((flt(d.get(k)) or 0, v) for k, v in DIETA.items()), reverse=True)
    partes = [(p, v) for p, v in partes if p >= 10]
    if partes:
        filas.append(fila("Alimentación", "Dieta", ", ".join(f"{v} {num(p, 0)} %" for p, v in partes), "EltonTraits", url))
    if aves:
        est = sorted(((flt(d.get(k)) or 0, v) for k, v in ESTRATO_AV.items()), reverse=True)
        est = [v for p, v in est if p >= 20]
        if est:
            filas.append(fila("Alimentación", "Dónde busca el alimento", ", ".join(est), "EltonTraits", url))
        noc = str(d.get("Nocturnal", "")).strip()
        if noc in ("0", "1"):
            filas.append(fila("Ecología", "Actividad", "nocturna" if noc == "1" else "diurna", "EltonTraits", url))
    else:
        if d.get("ForStrat-Value") in ESTRATO_MAM:
            filas.append(fila("Alimentación", "Dónde busca el alimento", ESTRATO_MAM[d["ForStrat-Value"]], "EltonTraits", url))
        act = [t for k, t in (("Activity-Nocturnal", "nocturna"), ("Activity-Crepuscular", "crepuscular"), ("Activity-Diurnal", "diurna"))
               if str(d.get(k, "")).strip() == "1"]
        if act:
            filas.append(fila("Ecología", "Actividad", " y ".join(act), "EltonTraits", url))
    return filas


# ------------------------------------------------------------------- FishBase

PELAG = {"reef-associated": "asociado a arrecifes y fondos rocosos", "demersal": "demersal (vive cerca del fondo)",
         "pelagic-neritic": "pelágico costero", "pelagic-oceanic": "pelágico oceánico", "pelagic": "pelágico",
         "benthopelagic": "bentopelágico (fondo y columna de agua)", "bathydemersal": "fondos profundos",
         "bathypelagic": "aguas profundas"}
PELIGRO = {"harmless": "inofensivo", "venomous": "venenoso (puede picar)", "traumatogenic": "puede causar heridas",
           "poisonous to eat": "tóxico si se come", "reports of ciguatera poisoning": "hay casos de ciguatera",
           "potential pest": "posible plaga", "other": "otros riesgos"}
IMPORTANCIA = {"highly commercial": "muy comercial", "commercial": "comercial", "minor commercial": "comercial menor",
               "subsistence fisheries": "pesca de subsistencia", "of no interest": "sin interés pesquero",
               "of potential interest": "interés potencial"}
RESIL = {"Very low": "muy baja (población tarda más de 14 años en duplicarse)", "Low": "baja (4,5 a 14 años)",
         "Medium": "media (1,4 a 4,4 años)", "High": "alta (menos de 15 meses)"}
ANACAT = {"oceanodromous": "migrador dentro del mar", "anadromous": "sube a los ríos a reproducirse",
          "catadromous": "baja al mar a reproducirse", "amphidromous": "se mueve entre ríos y mar",
          "potamodromous": "migrador en agua dulce", "non-migratory": "no migrador"}


def fishbase() -> dict:
    try:
        import pandas as pd
        sp = pd.read_parquet(FB + "species.parquet", columns=["SpecCode", "Genus", "Species", "DemersPelag", "AnaCat",
                                                             "DepthRangeShallow", "DepthRangeDeep", "DepthRangeComShallow",
                                                             "DepthRangeComDeep", "Vulnerability", "Importance", "Dangerous",
                                                             "GameFish", "Aquarium", "PriceCateg"])
        es = pd.read_parquet(FB + "estimate.parquet", columns=["SpecCode", "Troph", "seTroph", "TempPrefMin", "TempPrefMax"])
        st = pd.read_parquet(FB + "stocks.parquet", columns=["SpecCode", "Resilience", "Level"])
    except Exception as e:  # noqa: BLE001
        print(f"FishBase no disponible: {e}", flush=True)
        return {}
    st = st.sort_values("Level").drop_duplicates("SpecCode")
    df = sp.merge(es, on="SpecCode", how="left").merge(st[["SpecCode", "Resilience"]], on="SpecCode", how="left")
    out = {f"{r['Genus']} {r['Species']}": r for r in df.to_dict("records")}
    print(f"FishBase: {len(out)} especies", flush=True)
    return out


def rasgos_fishbase(d: dict) -> list[dict]:
    filas = []
    url = f"https://www.fishbase.se/summary/{d['SpecCode']}"
    if d.get("DemersPelag") in PELAG:
        filas.append(fila("Ecología", "Dónde vive", PELAG[d["DemersPelag"]], "FishBase", url))
    p1, p2 = flt(d.get("DepthRangeShallow")), flt(d.get("DepthRangeDeep"))
    if p1 is not None or p2:
        v = f"{num(p1 or 0, 0)}–{num(p2, 0)} m" if p2 else f"desde {num(p1, 0)} m"
        c1, c2 = flt(d.get("DepthRangeComShallow")), flt(d.get("DepthRangeComDeep"))
        if c2:
            v += f" (habitual {num(c1 or 0, 0)}–{num(c2, 0)} m)"
        filas.append(fila("Ecología", "Profundidad", v, "FishBase", url))
    t1, t2 = flt(d.get("TempPrefMin")), flt(d.get("TempPrefMax"))
    if t1 is not None and t2:
        filas.append(fila("Ecología", "Temperatura preferida del agua", f"{num(t1, 1)}–{num(t2, 1)} °C", "FishBase", url))
    if d.get("AnaCat") in ANACAT:
        filas.append(fila("Ecología", "Migración", ANACAT[d["AnaCat"]], "FishBase", url))
    tr = flt(d.get("Troph"))
    if tr:
        filas.append(fila("Alimentación", "Nivel trófico", f"{num(tr, 1)} (2 = herbívoro; 4,5 = gran depredador)", "FishBase", url))
    if d.get("Dangerous") in PELIGRO:
        filas.append(fila("Para las personas", "Peligrosidad", PELIGRO[d["Dangerous"]], "FishBase", url))
    if d.get("Importance") in IMPORTANCIA:
        filas.append(fila("Pesca", "Interés pesquero", IMPORTANCIA[d["Importance"]], "FishBase", url))
    if str(d.get("GameFish")) in ("-1", "1", "-1.0", "1.0"):
        filas.append(fila("Pesca", "Pesca recreativa", "especie de interés deportivo", "FishBase", url))
    vu = flt(d.get("Vulnerability"))
    if vu:
        filas.append(fila("Pesca", "Vulnerabilidad a la pesca", f"{num(vu, 0)} de 100", "FishBase", url))
    if d.get("Resilience") in RESIL:
        filas.append(fila("Pesca", "Resiliencia", RESIL[d["Resilience"]], "FishBase", url))
    return filas


# ----------------------------------------------------------------------- WCVP

FORMA_ES = {
    "annual": "anual", "biennial": "bienal", "perennial": "perenne", "monocarpic": "monocárpica", "succulent": "suculenta",
    "subshrub": "subarbusto", "shrub": "arbusto", "tree": "árbol", "climber": "trepadora", "climbing": "trepadora",
    "geophyte": "geófito", "tuberous": "tuberoso", "bulbous": "bulboso", "rhizomatous": "rizomatoso", "hydrophyte": "hidrófito",
    "helophyte": "helófito", "epiphyte": "epífito", "lithophyte": "litófito", "parasite": "parásita", "hemiparasite": "hemiparásita",
    "holoparasite": "holoparásita", "hemicryptophyte": "hemicriptófito", "chamaephyte": "caméfito", "therophyte": "terófito",
    "nanophanerophyte": "nanofanerófito", "phanerophyte": "fanerófito", "hemiepiphyte": "hemiepífito", "bamboo": "bambú",
    "or": "o", "and": "y", "cl.": "trepadora", "aquatic": "acuática", "semisucculent": "semisuculenta", "stoloniferous": "estolonífera",
    "scrambling": "apoyante", "liana": "liana", "single": "de tallo único", "stemmed": "", "evergreen": "perennifolia",
    "deciduous": "caducifolia", "perennating": "perennante", "rosette": "roseta", "herb": "hierba", "herbaceous": "herbácea",
}
CLIMA_ES = {"subtropical": "subtropical", "temperate": "templado", "desert or dry shrubland": "desierto o matorral seco",
            "seasonally dry tropical": "tropical estacionalmente seco", "wet tropical": "tropical húmedo",
            "montane tropical": "tropical de montaña", "subalpine or subarctic": "subalpino o subártico",
            "subarctic": "subártico", "subalpine": "subalpino"}
REGION_ES = {
    "Macaronesia": "Macaronesia", "Northern Africa": "norte de África", "Southwestern Europe": "suroeste de Europa",
    "Southeastern Europe": "sureste de Europa", "Middle Europe": "centro de Europa", "Northern Europe": "norte de Europa",
    "Eastern Europe": "este de Europa", "Western Asia": "oeste de Asia", "Caucasus": "Cáucaso", "Middle Asia": "Asia central",
    "Arabian Peninsula": "península arábiga", "Siberia": "Siberia", "Russian Far East": "Lejano Oriente ruso", "Mongolia": "Mongolia",
    "China": "China", "Eastern Asia": "Asia oriental", "Indian Subcontinent": "subcontinente indio", "Indo-China": "Indochina",
    "Malesia": "Malesia", "Papuasia": "Papuasia", "Australia": "Australia", "New Zealand": "Nueva Zelanda",
    "Southwestern Pacific": "Pacífico suroeste", "South-Central Pacific": "Pacífico centro-sur", "Northwestern Pacific": "Pacífico noroeste",
    "North-Central Pacific": "Pacífico centro-norte", "West Tropical Africa": "África tropical occidental",
    "West-Central Tropical Africa": "África tropical centro-occidental", "Northeast Tropical Africa": "África tropical nororiental",
    "East Tropical Africa": "África tropical oriental", "South Tropical Africa": "África tropical meridional",
    "Southern Africa": "sur de África", "Middle Atlantic Ocean": "islas del Atlántico central", "Western Indian Ocean": "oeste del Índico",
    "Subarctic America": "América subártica", "Western Canada": "oeste de Canadá", "Eastern Canada": "este de Canadá",
    "Northwestern U.S.A.": "noroeste de EE. UU.", "North-Central U.S.A.": "centro-norte de EE. UU.", "Northeastern U.S.A.": "noreste de EE. UU.",
    "Southwestern U.S.A.": "suroeste de EE. UU.", "South-Central U.S.A.": "centro-sur de EE. UU.", "Southeastern U.S.A.": "sureste de EE. UU.",
    "Mexico": "México", "Central America": "Centroamérica", "Caribbean": "Caribe", "Northern South America": "norte de Sudamérica",
    "Western South America": "oeste de Sudamérica", "Brazil": "Brasil", "Southern South America": "sur de Sudamérica",
    "Subantarctic Islands": "islas subantárticas", "Antarctic Continent": "Antártida",
}
AREA_ES = {
    "Canary Is.": "Canarias", "Madeira": "Madeira", "Selvagens": "Salvajes", "Azores": "Azores", "Cape Verde": "Cabo Verde",
    "Morocco": "Marruecos", "Algeria": "Argelia", "Tunisia": "Túnez", "Libya": "Libia", "Egypt": "Egipto",
    "Western Sahara": "Sáhara Occidental", "Mauritania": "Mauritania", "Spain": "España peninsular", "Portugal": "Portugal",
    "Baleares": "Baleares", "France": "Francia", "Corse": "Córcega", "Italy": "Italia", "Sicilia": "Sicilia", "Sardegna": "Cerdeña",
    "Greece": "Grecia", "Kriti": "Creta", "East Aegean Is.": "islas del Egeo oriental", "Turkey": "Turquía", "Cyprus": "Chipre",
    "Lebanon-Syria": "Líbano y Siria", "Palestine": "Palestina", "Gibraltar": "Gibraltar", "Malta": "Malta",
}


def wcvp() -> tuple[dict, dict, dict]:
    r = get(WCVP, timeout=900)
    if not r or r.status_code != 200:
        print("WCVP no disponible", flush=True)
        return {}, {}, {}
    z = zipfile.ZipFile(io.BytesIO(r.content))
    nombres, por_id = {}, {}
    with z.open("wcvp_names.csv") as fh:
        for f in csv.DictReader(io.TextIOWrapper(fh, encoding="utf-8"), delimiter="|"):
            if f["taxon_rank"] not in ("Species", "Subspecies", "Variety", "Form"):
                continue
            d = {k: f[k] for k in ("plant_name_id", "ipni_id", "taxon_status", "lifeform_description", "climate_description",
                                   "accepted_plant_name_id", "taxon_name", "powo_id")}
            por_id[f["plant_name_id"]] = d
            n = f["taxon_name"]
            if n not in nombres or f["taxon_status"] == "Accepted":
                nombres[n] = d
    dist = defaultdict(list)
    with z.open("wcvp_distribution.csv") as fh:
        for f in csv.DictReader(io.TextIOWrapper(fh, encoding="utf-8"), delimiter="|"):
            dist[f["plant_name_id"]].append((f["region"], f["area"], f["introduced"] == "1", f["extinct"] == "1", f["location_doubtful"] == "1"))
    print(f"WCVP: {len(nombres)} nombres, {len(dist)} con distribución", flush=True)
    return nombres, por_id, dist


def traducir_forma(t: str) -> str:
    if not t:
        return ""
    palabras = []
    for w in re.split(r"(\s+|,)", t):
        if not w.strip() or w == ",":
            palabras.append(w)
            continue
        palabras.append(FORMA_ES.get(w.lower(), w))
    return re.sub(r"\s+", " ", "".join(palabras)).strip()


def mundo_wcvp(d: dict, dist: dict) -> dict | None:
    filas = dist.get(d["plant_name_id"]) or []
    if not filas:
        return None
    nat = [x for x in filas if not x[2] and not x[3] and not x[4]]
    intro = [x for x in filas if x[2]]
    def areas(lst):
        vistos = []
        for reg, area, *_ in lst:
            t = AREA_ES.get(area) or REGION_ES.get(reg, reg)
            if t not in vistos:
                vistos.append(t)
        return vistos
    def regiones(lst):
        vistos = []
        for reg, *_ in lst:
            t = REGION_ES.get(reg, reg)
            if t not in vistos:
                vistos.append(t)
        return vistos
    return {"nativa": areas(nat) if len(nat) <= 8 else regiones(nat), "introducida": regiones(intro),
            "nAreasNativa": len(nat), "nAreasIntroducida": len(intro)}


# ----------------------------------------------------------------------- CCDB

def ccdb(generos: list[str], cache: dict) -> None:
    pend = [g for g in generos if caducado(cache.get(g, {}).get("fecha"), 180)]
    print(f"CCDB: {len(pend)} géneros por consultar", flush=True)
    fallos = 0
    for g in pend:
        r = get(CCDB, params={"genus": g, "format": "json"}, intentos=1, timeout=60)
        if not r or r.status_code != 200:
            fallos += 1
            if fallos >= 5:
                print("CCDB no responde; se deja para la próxima ejecución", flush=True)
                return
            continue
        try:
            datos = r.json()
        except ValueError:
            continue
        lista = datos.get("data", datos) if isinstance(datos, dict) else datos
        por = defaultdict(lambda: {"2n": set(), "n": set()})
        for x in lista or []:
            nom = (x.get("resolved_name") or x.get("matched_name") or x.get("original_name") or "").strip()
            for k, cl in (("sporophytic", "2n"), ("gametophytic", "n")):
                v = str(x.get(k) or "").strip()
                if v and v.lower() not in ("none", "nan", "-"):
                    por[nom][cl].add(v)
            ori = (x.get("original_name") or "").strip()
            if ori and ori != nom:
                por[ori]["2n"] |= por[nom]["2n"]
                por[ori]["n"] |= por[nom]["n"]
        cache[g] = {"fecha": HOY, "taxones": {k: {"2n": sorted(v["2n"])[:6], "n": sorted(v["n"])[:6]} for k, v in por.items()}}
        time.sleep(1)


# ----------------------------------------------------------------- Wikipedia

ENV_RE = re.compile(r"envergadura(?: alar)?(?: de| que va de| entre| es de| alcanza| que alcanza| puede alcanzar| media de| máxima de)?\s*"
                    r"(?:los\s*|unos\s*|hasta\s*)?(\d+(?:[.,]\d+)?)(?:\s*(?:-|–|a|y)\s*(\d+(?:[.,]\d+)?))?\s*(cm|mm|m)\b", re.I)


def envergadura(texto: str) -> str | None:
    m = ENV_RE.search(texto or "")
    if not m:
        return None
    a, b, u = flt(m.group(1)), flt(m.group(2)), m.group(3).lower()
    if not a:
        return None
    return f"{num(a, 1)}–{num(b, 1)} {u}" if b else f"{num(a, 1)} {u}"


def etimologia(wp: dict) -> dict | None:
    t = (wp or {}).get("etim")
    if not t:
        return None
    t = re.sub(r"\n{2,}", "\n", t.replace("\u200b", "")).strip()
    return {"texto": t[:1200], "fuente": "Wikipedia en español", "url": wp.get("url", "")}


# ---------------------------------------------------------------------- main

def main() -> int:
    inicio = time.time()
    EXTRA.mkdir(parents=True, exist_ok=True)
    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    rutas = {e["c"]: DATOS / "fichas" / f"{e['c']}.json" for e in indice}
    fichas = {c: json.loads(p.read_text(encoding="utf-8")) for c, p in rutas.items()}
    hay = lambda g: any(f.get("grupo") == g for f in fichas.values())  # noqa: E731

    ag = anage()
    av = avonet() if hay("Aves") else {}
    el_av = elton(ELTON_AVES) if hay("Aves") else {}
    el_ma = elton(ELTON_MAM) if hay("Mamíferos") else {}
    fb = fishbase() if hay("Peces") else {}
    plantas = [f for f in fichas.values() if f.get("reino") == "Flora"]
    wn, wid, wd = wcvp() if plantas else ({}, {}, {})
    c_ccdb = cargar_json(EXTRA / "ccdb.json", {})
    if plantas:
        try:
            ccdb(sorted({f["nombre"].split()[0] for f in plantas}), c_ccdb)
        finally:
            (EXTRA / "ccdb.json").write_text(json.dumps(c_ccdb, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    wp = cargar_json(EXTRA / "wikipedia.json", {})

    cuenta = defaultdict(int)
    for cod, f in fichas.items():
        for k in ("rasgos", "mundo", "etimologia"):
            f.pop(k, None)
        nombre, bi = f["nombre"], binomio(f["nombre"])
        grupo = f.get("grupo")
        filas: list[dict] = []

        if f.get("reino") == "Fauna":
            a = ag.get(bi)
            if a and grupo in ("Aves", "Mamíferos", "Reptiles", "Anfibios"):
                filas += rasgos_anage(a)
            if grupo == "Aves":
                d = av.get(bi)
                if d:
                    filas += rasgos_avonet(d, bi)
                e = el_av.get(bi)
                if e:
                    filas += rasgos_elton(e, True)
            if grupo == "Mamíferos":
                e = el_ma.get(bi)
                if e:
                    filas += rasgos_elton(e, False)
            if grupo in ("Aves", "Mamíferos"):
                env = envergadura((wp.get(bi) or {}).get("texto", ""))
                if env:
                    filas.append(fila("Morfología", "Envergadura", env, "Wikipedia en español", (wp.get(bi) or {}).get("url")))
            if grupo == "Peces":
                d = fb.get(bi)
                if d:
                    filas += rasgos_fishbase(d)
        else:
            d = wn.get(nombre) or wn.get(bi)
            nivel = "taxon" if wn.get(nombre) else "especie"
            if d:
                acc = wid.get(d["accepted_plant_name_id"]) if d["taxon_status"] != "Accepted" else d
                acc = acc or d
                url = f"https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:{acc['ipni_id']}" if acc.get("ipni_id") else URL_FUENTE["WCVP (Kew)"]
                nota = "" if nivel == "taxon" else f" (de {bi})"
                if acc.get("lifeform_description"):
                    filas.append(fila("Forma de vida", "Forma vital", traducir_forma(acc["lifeform_description"]) + nota, "WCVP (Kew)", url))
                if acc.get("climate_description"):
                    filas.append(fila("Forma de vida", "Clima", CLIMA_ES.get(acc["climate_description"], acc["climate_description"]), "WCVP (Kew)", url))
                m = mundo_wcvp(acc, wd)
                if m:
                    f["mundo"] = {**m, "fuente": "WCVP (Kew)", "url": url, "nivel": nivel,
                                  "nombre": acc.get("taxon_name") if acc.get("taxon_name") != nombre else None}
                    cuenta["mundo"] += 1
            tax = (c_ccdb.get(nombre.split()[0]) or {}).get("taxones", {})
            cr = tax.get(nombre) or tax.get(bi)
            if cr and (cr.get("2n") or cr.get("n")):
                partes = []
                if cr.get("2n"):
                    partes.append("2n = " + ", ".join(cr["2n"]))
                if cr.get("n"):
                    partes.append("n = " + ", ".join(cr["n"]))
                filas.append(fila("Genética", "Número cromosomático", "; ".join(partes), "CCDB",
                                  f"https://ccdb.tau.ac.il/search/?genus={quote(nombre.split()[0])}"))

        et = etimologia(wp.get(bi))
        if et:
            f["etimologia"] = et
            cuenta["etimologia"] += 1
        if filas:
            f["rasgos"] = filas
            cuenta["con_rasgos"] += 1
            for x in filas:
                cuenta[x["fuente"]] += 1

    for cod, f in fichas.items():
        rutas[cod].write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = cargar_json(DATOS / "meta.json", {})
    meta["rasgos"] = {"fecha": HOY, **cuenta}
    (DATOS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Rasgos: {dict(cuenta)} · {round((time.time() - inicio) / 60, 1)} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
