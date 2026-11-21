"""Completa las fotos de Biota con fotos de licencia libre y enlaza cada planta con
«Especies Vegetales en Canarias».

Fuentes:
  - Wikimedia Commons: la imagen principal del taxón en Wikidata (P18), con el autor y la
    licencia que constan en Commons (todas libres: CC0, CC BY, CC BY-SA, dominio público…).
  - iNaturalist: las fotos del taxón con licencia CC0, CC BY, CC BY-SA, CC BY-NC o CC BY-NC-SA.
    Se descartan las de «todos los derechos reservados» y las ND (sin obras derivadas).
  - Especies Vegetales en Canarias (endemicascanarias.com, Gerardo G. Casanova y colaboradores):
    solo el enlace a su ficha. Sus fotos tienen © y la web pide el consentimiento expreso del
    autor para usarlas, así que no se copian ni se muestran.

Las fotos no se descargan: la app las carga desde Commons e iNaturalist con su crédito.
Se consultan primero los taxones sin fotos en Biota. Cachés en datos/extra/ (inat.json,
commons.json, evc.json) para no repetir miles de consultas cada mes.

Uso:
  python scripts/fotos.py
  python scripts/fotos.py --max-inat 200   # prueba
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
import unicodedata
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import unquote, urljoin

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
HOY = date.today().isoformat()
INAT = "https://api.inaturalist.org/v1"
EVC = "https://endemicascanarias.com"
MAX_FOTOS = 5  # fotos libres por taxón
LIC_INAT = {"cc0": "CC0", "cc-by": "CC BY", "cc-by-sa": "CC BY-SA", "cc-by-nc": "CC BY-NC", "cc-by-nc-sa": "CC BY-NC-SA"}
LIC_URL = {
    "CC0": "https://creativecommons.org/publicdomain/zero/1.0/deed.es",
    "CC BY": "https://creativecommons.org/licenses/by/4.0/deed.es",
    "CC BY-SA": "https://creativecommons.org/licenses/by-sa/4.0/deed.es",
    "CC BY-NC": "https://creativecommons.org/licenses/by-nc/4.0/deed.es",
    "CC BY-NC-SA": "https://creativecommons.org/licenses/by-nc-sa/4.0/deed.es",
}
RANGOS = {"subsp.", "var.", "f.", "subvar.", "nothosubsp."}
OPEN_DATA = "https://inaturalist-open-data.s3.amazonaws.com/photos/"

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=4, **kw):
    espera = 3
    for n in range(intentos):
        try:
            r = s.get(url, params=params, timeout=60, **kw)
            if r.status_code in (200, 204, 404):
                return r
            if r.status_code == 429:
                time.sleep(int(r.headers.get("Retry-After", 30)))
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


def guardar_json(p: Path, datos) -> None:
    p.write_text(json.dumps(datos, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def caducado(fecha: str | None, dias: int) -> bool:
    if not fecha:
        return True
    try:
        return date.fromisoformat(fecha) < date.today() - timedelta(days=dias)
    except ValueError:
        return True


def sin_rango(nombre: str) -> str:
    """«Dracaena draco subsp. draco» → «Dracaena draco draco» (como escribe iNaturalist)."""
    return " ".join(t for t in nombre.split() if t not in RANGOS)


def norm(nombre: str) -> str:
    return sin_rango(nombre).replace("×", "x").replace(" x ", " ").lower().strip()


def binomio(nombre: str) -> str:
    return " ".join(t for t in sin_rango(nombre).replace("× ", "×").split()[:2]).replace("×", "× ")


def slug(nombre: str) -> str:
    t = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode().lower()
    t = t.replace("×", " ").replace(".", " ")
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


def limpiar_autor(a: str) -> str:
    m = re.match(r"No machine-readable author provided\.\s*(.+?) assumed", a)
    if m:
        a = m.group(1)
    a = re.sub(r"^(User|Usuario):", "", a).strip(" .")
    a = re.sub(r"\s*\[\d+\]\s*$", "", a)
    return a or "Autor en Wikimedia Commons"


def texto_plano(h: str, maximo: int = 80) -> str:
    t = re.sub(r"<[^>]+>", " ", h or "")
    t = re.sub(r"\s+", " ", html.unescape(t)).strip()
    return t if len(t) <= maximo else t[: maximo - 1].rstrip() + "…"


# ------------------------------------------------------------------ iNaturalist

def buscar_inat(nombre: str, flora: bool) -> dict | None:
    r = get(f"{INAT}/taxa", params={"q": sin_rango(nombre), "per_page": 10, "is_active": "true"})
    if not r or r.status_code != 200:
        return None
    objetivo = norm(nombre)
    mejor = None
    for t in r.json().get("results", []):
        reino_ok = (t.get("iconic_taxon_name") == "Plantae") == flora and t.get("iconic_taxon_name") != "Fungi"
        if not reino_ok:
            continue
        if norm(t.get("name", "")) == objetivo:
            return t
        if mejor is None and norm(t.get("matched_term") or "") == objetivo:
            mejor = t  # coincide con un sinónimo
    return mejor


def fotos_inat(ids: list[int], taxones: dict) -> None:
    for i in range(0, len(ids), 30):
        lote = ids[i:i + 30]
        r = get(f"{INAT}/taxa/{','.join(map(str, lote))}")
        time.sleep(1)
        if not r or r.status_code != 200:
            continue
        for t in r.json().get("results", []):
            fotos = []
            for tp in t.get("taxon_photos") or []:
                p = tp.get("photo") or {}
                lic = LIC_INAT.get(p.get("license_code") or "")
                url = p.get("medium_url") or p.get("url") or ""
                if not lic or not url:
                    continue
                atr = p.get("attribution") or ""
                m = re.match(r"\(c\)\s*(.+?),\s*(?:some|all) rights reserved", atr) or re.search(r"uploaded by (.+)$", atr)
                autor = (m.group(1) if m else atr).strip()
                dims = p.get("original_dimensions") or {}
                fotos.append({"id": p.get("id"), "url": re.sub(r"/(square|small|thumb|medium|large|original)\.", "/medium.", url),
                              "autor": autor[:80], "lic": lic, "an": dims.get("width"), "al": dims.get("height")})
                if len(fotos) >= MAX_FOTOS:
                    break
            taxones[str(t["id"])] = {"fecha": HOY, "fotos": fotos}


def inaturalist(objetivos: list[tuple[str, bool]], cache: dict, maximo: int) -> None:
    nombres = cache.setdefault("nombres", {})
    taxones = cache.setdefault("taxones", {})
    pendientes = [(n, fl) for n, fl in objetivos if caducado(nombres.get(n, {}).get("fecha"), 180)]
    print(f"iNaturalist: {len(pendientes)} nombres por buscar (máximo {maximo} en esta ejecución)", flush=True)
    for k, (n, flora) in enumerate(pendientes[:maximo]):
        t = buscar_inat(n, flora)
        nivel = "taxon"
        if not t and binomio(n) != n:
            t = buscar_inat(binomio(n), flora)
            nivel = "especie"
        nombres[n] = {"fecha": HOY, "id": t["id"], "nombre": t["name"], "nivel": nivel} if t else {"fecha": HOY, "id": None}
        if k % 250 == 0:
            print(f"  {k}/{min(len(pendientes), maximo)}", flush=True)
        time.sleep(1)
    ids = sorted({v["id"] for v in nombres.values() if v.get("id")} - {int(k) for k, v in taxones.items() if not caducado(v.get("fecha"), 180)})
    print(f"iNaturalist: fotos de {len(ids)} taxones", flush=True)
    fotos_inat(ids, taxones)


# -------------------------------------------------------- Wikidata + Commons

def commons(nombres: list[str], cache: dict) -> None:
    por_nombre = cache.setdefault("nombres", {})
    archivos = cache.setdefault("archivos", {})
    pendientes = [n for n in nombres if caducado(por_nombre.get(n, {}).get("fecha"), 120)]
    print(f"Wikidata (P18): {len(pendientes)} nombres por consultar", flush=True)
    for i in range(0, len(pendientes), 150):
        lote = pendientes[i:i + 150]
        valores = " ".join('"' + n.replace('"', "") + '"' for n in lote)
        q = f"SELECT ?name ?img WHERE {{ VALUES ?name {{ {valores} }} ?item wdt:P225 ?name; wdt:P18 ?img. }}"
        r = None
        for _ in range(3):
            r = get("https://query.wikidata.org/sparql", params={"query": q, "format": "json"})
            if r and r.status_code == 200:
                break
            time.sleep(10)
        if not r or r.status_code != 200:
            continue
        for n in lote:
            por_nombre[n] = {"fecha": HOY, "archivo": None}
        for b in r.json()["results"]["bindings"]:
            n = b["name"]["value"]
            if not por_nombre[n].get("archivo"):
                por_nombre[n]["archivo"] = unquote(b["img"]["value"].rsplit("/", 1)[-1])
        time.sleep(1.5)

    pend = sorted({v["archivo"] for v in por_nombre.values() if v.get("archivo")} - {k for k, v in archivos.items() if not caducado(v.get("fecha"), 120)})
    print(f"Commons: datos de {len(pend)} archivos", flush=True)
    for i in range(0, len(pend), 50):
        lote = pend[i:i + 50]
        r = get("https://commons.wikimedia.org/w/api.php", params={
            "action": "query", "prop": "imageinfo", "iiprop": "url|extmetadata|size", "format": "json", "formatversion": "2",
            "iiextmetadatafilter": "Artist|LicenseShortName|LicenseUrl|Credit|UsageTerms", "titles": "|".join(f"File:{a}" for a in lote)})
        time.sleep(1)
        if not r or r.status_code != 200:
            continue
        q = r.json().get("query", {})
        renombres = {x["to"]: x["from"] for x in q.get("normalized", [])}
        for p in q.get("pages", []):
            titulo = p.get("title", "")
            archivo = renombres.get(titulo, titulo).removeprefix("File:")
            ii = (p.get("imageinfo") or [{}])[0]
            em = ii.get("extmetadata") or {}
            val = lambda k: (em.get(k) or {}).get("value", "")  # noqa: E731
            lic = texto_plano(val("LicenseShortName"), 40)
            if not ii or not lic:
                archivos[archivo] = {"fecha": HOY, "ok": False}
                continue
            autor = texto_plano(val("Artist")) or texto_plano(val("Credit")) or "Autor en Wikimedia Commons"
            archivos[archivo] = {"fecha": HOY, "ok": True, "autor": autor, "lic": lic, "licUrl": val("LicenseUrl"),
                                 "pagina": ii.get("descriptionurl", ""), "an": ii.get("width"), "al": ii.get("height")}


# ------------------------------------------------ Especies Vegetales en Canarias

def evc(cache: dict) -> dict:
    if not caducado(cache.get("fecha"), 30) and cache.get("fichas") and cache.get("version") == 2:
        return cache["fichas"]
    fichas: dict[str, dict] = {}
    vistas, cola = set(), [f"{EVC}/es/listado-todas?limit=0", f"{EVC}/es/listado-todas"]
    while cola and len(vistas) < 150:
        url = cola.pop(0)
        if url in vistas:
            continue
        vistas.add(url)
        r = get(url)
        time.sleep(2)
        if not r or r.status_code != 200:
            continue
        for href, texto in re.findall(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', r.text, re.S):
            href = html.unescape(href)
            if ("/allcategories-" in href and "/colaboradores/" not in href) or re.match(r"/es/orquideas/[a-z]+-[a-z]", href):
                u = urljoin(EVC, href).replace("://www.", "://")
                sl = u.rstrip("/").rsplit("/", 1)[-1]
                fichas.setdefault(sl, {"url": u, "texto": texto_plano(texto, 120)})
            elif "listado-todas" in href and re.search(r"[?&](start|limitstart)=\d+", href):
                cola.append(urljoin(EVC, href))
    print(f"Especies Vegetales en Canarias: {len(fichas)} fichas en {len(vistas)} páginas", flush=True)
    if fichas:
        cache.clear()
        cache.update({"fecha": HOY, "version": 2, "fichas": fichas})
    return cache.get("fichas", {})


def indice_evc(fichas: dict) -> dict:
    """Slug → URL, por la dirección y también por el nombre que muestra el enlace."""
    por = {}
    for k, v in fichas.items():
        por.setdefault(k, v["url"])
        nombre = re.split(r"[(\[]", v.get("texto", ""))[0].strip()
        if re.match(r"^[A-Z][a-z]+ (?:× |x )?[a-z-]+", nombre):
            por.setdefault(slug(nombre), v["url"])
    return por


def buscar_evc(nombre: str, fichas: dict) -> str | None:
    candidatos = [slug(nombre)] + ([slug(nombre.replace("×", "x"))] if "×" in nombre else [])
    for sl in candidatos:
        if sl in fichas:
            return fichas[sl]
    partes = sin_rango(nombre).split()
    if len(partes) == 2:  # especie en Biota, solo la subespecie típica en la web
        for r in ("subsp", "var"):
            k = f"{candidatos[0]}-{r}-{slug(partes[1])}"
            if k in fichas:
                return fichas[k]
    for sl in candidatos:
        for k, v in fichas.items():
            if k.startswith(sl + "-") and not re.match(r"(subsp|var|f|ssp|x)-", k[len(sl) + 1:]):
                return v  # p. ej. «lysimachia-wildpretii-pelletiera-wildpretii»
    return None


# ---------------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-inat", type=int, default=2300, help="búsquedas nuevas en iNaturalist por ejecución")
    args = ap.parse_args()
    EXTRA.mkdir(parents=True, exist_ok=True)
    inicio = time.time()

    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    rutas = {e["c"]: DATOS / "fichas" / f"{e['c']}.json" for e in indice}
    fichas = {c: json.loads(p.read_text(encoding="utf-8")) for c, p in rutas.items()}

    c_inat = cargar_json(EXTRA / "inat.json", {})
    c_com = cargar_json(EXTRA / "commons.json", {})
    c_evc = cargar_json(EXTRA / "evc.json", {})

    # Primero los taxones sin fotos en Biota
    orden = sorted(indice, key=lambda e: (bool(e.get("img")), e.get("no", 0)))
    objetivos = [(e["n"], e.get("re") == "Flora") for e in orden]
    nombres_wd = sorted({e["n"] for e in indice} | {binomio(e["n"]) for e in indice})

    try:
        commons(nombres_wd, c_com)
    finally:
        guardar_json(EXTRA / "commons.json", c_com)
    try:
        inaturalist(objetivos, c_inat, args.max_inat)
    finally:
        guardar_json(EXTRA / "inat.json", c_inat)
    try:
        f_evc = indice_evc(evc(c_evc))
    finally:
        guardar_json(EXTRA / "evc.json", c_evc)

    cuenta = {"con_fotos_libres": 0, "sin_biota_completadas": 0, "commons": 0, "inaturalist": 0, "evc": 0}
    sin_foto = sum(1 for e in indice if not e.get("img"))
    for e in indice:
        cod, f = e["c"], fichas[e["c"]]
        f.pop("fotosLibres", None)
        f.pop("evc", None)
        e.pop("fl", None)
        e.pop("ev", None)
        lista: list[dict] = []

        # Commons: primero el taxón exacto; si es subespecie sin foto, la de la especie
        for n, nivel in ((e["n"], "taxon"), (binomio(e["n"]), "especie")):
            if nivel == "especie" and (lista or n == e["n"]):
                break
            a = (c_com.get("nombres", {}).get(n) or {}).get("archivo")
            info = c_com.get("archivos", {}).get(a or "") or {}
            if a and info.get("ok"):
                lista.append({"fuente": "Wikimedia Commons", "archivo": a, "autor": limpiar_autor(info["autor"]), "lic": info["lic"],
                              "licUrl": info.get("licUrl", ""), "pagina": info.get("pagina", ""), "nivel": nivel,
                              **({"taxon": n} if nivel == "especie" else {})})

        # iNaturalist
        t = dict(c_inat.get("nombres", {}).get(e["n"]) or {})
        if t.get("id") and t.get("nivel") == "taxon" and norm(t["nombre"]) != norm(e["n"]):
            t["nivel"] = "sinonimo"  # iNaturalist lo trata con otro nombre: se indica en el pie de foto
        if t.get("id"):
            for p in (c_inat.get("taxones", {}).get(str(t["id"])) or {}).get("fotos", []):
                if len(lista) >= MAX_FOTOS:
                    break
                lista.append({"fuente": "iNaturalist", "url": p["url"], "autor": p["autor"], "lic": p["lic"],
                              "licUrl": LIC_URL.get(p["lic"], ""), "pagina": f"https://www.inaturalist.org/photos/{p['id']}",
                              "nivel": t.get("nivel", "taxon"), **({"taxon": t["nombre"]} if t.get("nivel") != "taxon" else {})})

        if lista:
            f["fotosLibres"] = lista
            cuenta["con_fotos_libres"] += 1
            cuenta["commons"] += any(x["fuente"] == "Wikimedia Commons" for x in lista)
            cuenta["inaturalist"] += any(x["fuente"] == "iNaturalist" for x in lista)
            if not e.get("img"):
                cuenta["sin_biota_completadas"] += 1
            x = lista[0]
            if x["fuente"] == "Wikimedia Commons":
                e["fl"] = "c:" + x["archivo"]
            else:
                e["fl"] = "i:" + x["url"].removeprefix(OPEN_DATA) if x["url"].startswith(OPEN_DATA) else x["url"]

        if e.get("re") == "Flora" and f_evc:
            u = buscar_evc(e["n"], f_evc)
            if u:
                f["evc"] = {"url": u, "titulo": "Especies Vegetales en Canarias",
                            "autoria": "Gerardo G. Casanova y colaboradores"}
                e["ev"] = 1
                cuenta["evc"] += 1

    for cod, f in fichas.items():
        rutas[cod].write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (DATOS / "indice.json").write_text(json.dumps(indice, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = cargar_json(DATOS / "meta.json", {})
    meta["fotos"] = {"fecha": HOY, **cuenta, "sin_fotos_biota": sin_foto,
                     "pendientes_inat": sum(1 for n, _ in objetivos if caducado(c_inat.get("nombres", {}).get(n, {}).get("fecha"), 180))}
    guardar_json(DATOS / "meta.json", meta)
    print(f"Fotos libres: {cuenta} · sin fotos en Biota: {sin_foto} · {round((time.time() - inicio) / 60, 1)} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
