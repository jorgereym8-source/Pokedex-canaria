"""Descarga los datos de la Pokédex Canaria desde las webs oficiales.

Fuentes:
  - Biota (Banco de Datos de Biodiversidad de Canarias): exportaciones oficiales por grupo
    (CSV) y la ficha de cada especie.
  - Centinela: ficha de las especies protegidas.

Se ejecuta en GitHub Actions (ver .github/workflows/datos.yml). Respeta las zonas que Biota
no sirve a programas automáticos (galería con autores y cuadrículas de distribución): esas
partes se enlazan, no se descargan.

Salida en datos/:
  indice.json        lista compacta para buscar y filtrar en la app
  fichas/<cod>.json  ficha completa de cada taxón
  meta.json          fecha, recuentos y leyendas

Uso:
  python scripts/descargar.py                # todo
  python scripts/descargar.py --limite 20    # prueba con 20 taxones por grupo
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
PAUSA = 1.0  # segundos entre peticiones
BASE = "https://www.biodiversidadcanarias.es"
BIOTA = f"{BASE}/biota"
CENTINELA = f"{BASE}/centinela"
SALIDA = Path(__file__).resolve().parent.parent / "datos"

# Grupos de la búsqueda divulgativa de Biota: (reino, grupo, subgrupo, parámetros)
GRUPOS = [
    ("Flora", "Helechos", None, {"selectLevel1": 2, "selectLevel2": 5}),
    ("Flora", "Plantas con flor", "Terrestres", {"selectLevel1": 2, "selectLevel2": 6}),
    ("Flora", "Plantas con flor", "Marinas", {"selectLevel1": 2, "selectLevel2": 7}),
    ("Fauna", "Peces", "Cartilaginosos", {"selectLevel1": 8, "selectLevel2": 24, "selectLevel3": 35}),
    ("Fauna", "Peces", "Dulceacuícolas", {"selectLevel1": 8, "selectLevel2": 24, "selectLevel3": 33}),
    ("Fauna", "Peces", "Marinos óseos", {"selectLevel1": 8, "selectLevel2": 24, "selectLevel3": 34}),
    ("Fauna", "Anfibios", None, {"selectLevel1": 8, "selectLevel2": 25}),
    ("Fauna", "Reptiles", "Terrestres", {"selectLevel1": 8, "selectLevel2": 26, "selectLevel3": 36}),
    ("Fauna", "Reptiles", "Tortugas marinas", {"selectLevel1": 8, "selectLevel2": 26, "selectLevel3": 37}),
    ("Fauna", "Aves", None, {"selectLevel1": 8, "selectLevel2": 27}),
    ("Fauna", "Mamíferos", "Terrestres", {"selectLevel1": 8, "selectLevel2": 28, "selectLevel3": 38}),
    ("Fauna", "Mamíferos", "Marinos", {"selectLevel1": 8, "selectLevel2": 28, "selectLevel3": 39}),
]
# Exportaciones completas de cada nivel 1, para recoger lo que no caiga en ningún subgrupo
COMPLETOS = [("Flora", "Plantas vasculares", {"selectLevel1": 2}), ("Fauna", "Vertebrados", {"selectLevel1": 8})]
GRUPOS_EXCLUIDOS_FAUNA = {"Ascidiacea", "Thaliacea", "Appendicularia"}  # urocordados («vertebrados y afines»)

ISLAS = {"H": "El Hierro", "P": "La Palma", "G": "La Gomera", "T": "Tenerife", "C": "Gran Canaria",
         "F": "Fuerteventura", "L": "Lanzarote", "M": "Mar"}
PRESENCIA = {"s": "segura", "d": "dudosa, equívoca o extinta", "t": "traslocada"}
RANGOS = {"subsp.": "subespecie", "ssp.": "subespecie", "var.": "variedad", "f.": "forma",
          "fo.": "forma", "nothosubsp.": "notosubespecie", "nothovar.": "notovariedad"}
PARTICULAS = {"de", "da", "del", "van", "von", "der", "la", "le", "du", "des", "ex", "et", "in", "y", "&"}


# --------------------------------------------------------------------------- red

class Cliente:
    def __init__(self) -> None:
        self.s = requests.Session()
        self.s.headers.update({"User-Agent": UA, "Accept-Language": "es-ES,es;q=0.9"})
        self.peticiones = 0

    def get(self, url: str, params: dict | None = None, intentos: int = 4) -> requests.Response:
        espera = 5
        for n in range(intentos):
            try:
                time.sleep(PAUSA)
                r = self.s.get(url, params=params, timeout=90)
                self.peticiones += 1
                if r.status_code == 200:
                    return r
                if r.status_code == 404:
                    r.raise_for_status()
            except requests.RequestException as e:  # noqa: PERF203
                if n == intentos - 1:
                    raise
                print(f"  reintento {n + 1} {url}: {e}", flush=True)
            time.sleep(espera)
            espera *= 2
        raise RuntimeError(f"Sin respuesta válida: {url}")


# ----------------------------------------------------------------------- utilidades

def limpiar(texto: str | None) -> str:
    return re.sub(r"\s+", " ", texto or "").strip()


def si_no(valor: str) -> bool | None:
    v = limpiar(valor).lower()
    if v.startswith("s"):
        return True
    if v.startswith("n"):
        return False
    return None


def leer_presencia(codigo: str) -> dict[str, str]:
    """'Hs Ps Ts Cd' -> {'H': 's', 'P': 's', 'T': 's', 'C': 'd'}"""
    out = {}
    for tok in codigo.split():
        if len(tok) >= 2 and tok[0] in ISLAS:
            out[tok[0]] = tok[1:].lower()
    return out


def separar_nombre_texto(completo: str) -> tuple[str, str, str]:
    """Separa nombre y autoría sin marcas de cursiva (respaldo si falta la ficha)."""
    toks = completo.split()
    if len(toks) < 2:
        return completo, "", "especie"
    nombre, i = [toks[0]], 1
    if toks[i] in ("x", "×"):
        nombre.append("×")
        i += 1
    if i < len(toks) and re.fullmatch(r"[a-zëï\-]+", toks[i]):
        nombre.append(toks[i])
        i += 1
    rango, autor_sp, autor_infra = "especie", [], []
    while i < len(toks):
        t = toks[i]
        if t in RANGOS and i + 1 < len(toks) and re.fullmatch(r"[a-zëï\-]+", toks[i + 1]):
            nombre += [t, toks[i + 1]]
            rango, autor_infra = RANGOS[t], []
            i += 2
            continue
        if rango == "especie" and not autor_sp and t not in PARTICULAS and re.fullmatch(r"[a-zëï\-]{3,}", t):
            nombre.append(t)  # trinomio zoológico sin «subsp.»
            rango = "subespecie"
            i += 1
            continue
        (autor_infra if rango != "especie" else autor_sp).append(t)
        i += 1
    autor = " ".join(autor_infra) if autor_infra else " ".join(autor_sp)
    return " ".join(nombre), autor, rango


def separar_nombre_html(span) -> tuple[str, str, str]:
    """Usa las cursivas de Biota: lo que va en <i> es nombre; el resto, autoría o rango."""
    nombre, rango = [], "especie"
    cubos: dict[int, list[str]] = {}
    n_cursivas = 0
    hijos = list(span.children)
    for idx, h in enumerate(hijos):
        if getattr(h, "name", None) == "i":
            nombre.append(limpiar(h.get_text()))
            n_cursivas += 1
            continue
        texto = h.get_text() if hasattr(h, "get_text") else str(h)
        siguiente_es_cursiva = idx + 1 < len(hijos) and getattr(hijos[idx + 1], "name", None) == "i"
        toks = texto.split()
        for j, t in enumerate(toks):
            if t in RANGOS and j == len(toks) - 1 and siguiente_es_cursiva:
                nombre.append(t)
                rango = RANGOS[t]
            elif t in ("x", "×") and siguiente_es_cursiva and j == len(toks) - 1:
                nombre.append("×")
            else:
                cubos.setdefault(n_cursivas, []).append(t)
    if not nombre:
        return separar_nombre_texto(limpiar(span.get_text()))
    if rango == "especie" and len([p for p in nombre if p not in RANGOS.keys() and p != "×"]) >= 3:
        rango = "subespecie"
    autor = " ".join(cubos.get(n_cursivas, [])) or " ".join(cubos.get(n_cursivas - 1, []))
    return " ".join(nombre), limpiar(autor), rango


# ----------------------------------------------------------------- exportaciones

def exportar(cli: Cliente, params: dict) -> list[dict]:
    p = dict(params, searchSpeciesTabs="divulgativeSearch")
    r = cli.get(f"{BIOTA}/especies/export", params=p)
    texto = r.content.decode("cp1252", errors="replace")
    filas = list(csv.reader(io.StringIO(texto), delimiter=";"))
    cab = [limpiar(c) for c in filas[0]]
    out = []
    for f in filas[1:]:
        if not f or not f[0].strip():
            continue
        d = dict(zip(cab, f))
        out.append({
            "codigo": limpiar(d.get("Código")),
            "completo": limpiar(d.get("Especie")),
            "comunes": limpiar(d.get("Nombre común/vulgar")),
            "medio": limpiar(d.get("Medio")),
            "clase": limpiar(d.get("Clase")),
            "presencia": limpiar(d.get("Presencia")),
            "validez": limpiar(d.get("Validez")),
            "status": limpiar(d.get("Status")),
            "origen": limpiar(d.get("Origen")),
            "endemico": limpiar(d.get("Endemicidad")) == "Endémico",
            "nImagenes": int(d.get("Imagen") or 0) if (d.get("Imagen") or "").strip().isdigit() else 0,
        })
    return out


def exportar_centinela(cli: Cliente) -> set[str]:
    """Nombres completos de las especies de Centinela (sin código en la exportación)."""
    r = cli.get(f"{CENTINELA}/especies/export", params={"pagina": 1, "tipoBusqueda": "NOMBRE"})
    texto = r.content.decode("cp1252", errors="replace")
    filas = list(csv.reader(io.StringIO(texto), delimiter=";"))
    return {limpiar(f[0]) for f in filas[1:] if f}


# ------------------------------------------------------------------ ficha Biota

def tabla_tras_titulo(sopa, titulo: str):
    for h in sopa.select("h3.panel-title, h3"):
        if limpiar(h.get_text()) == titulo:
            panel = h.find_parent(class_="panel")
            return panel.find("table") if panel else None
    return None


def leer_ficha_biota(html: str) -> dict:
    sopa = BeautifulSoup(html, "lxml")
    f: dict = {}

    # Fotos: metadatos en los <script> de cada imagen (antes de quitar los scripts)
    imagenes, vistas = [], set()
    for bloque in re.findall(r"var pk = '(\d+)';(.*?)var loadedMap", html, re.S):
        pk, resto = bloque
        if pk in vistas:
            continue
        vistas.add(pk)
        val = dict(re.findall(r"var (\w+) = '([^']*)';", resto))
        if val.get("publica", "true") != "true" or val.get("tipo", "IMG") != "IMG":
            continue
        imagenes.append({
            "id": pk,
            "autor": limpiar(val.get("autor")),
            "licencia": limpiar(val.get("licencia")),
            "documento": val.get("codigoDocumentoAsigna", ""),
            "portada": val.get("portada") == "true",
            "descripcion": limpiar(val.get("descripcionCortaImagen")),
        })
    if not imagenes:
        for src in re.findall(r"/biota/especie/[A-Z]\d+/imagenes/(\d+)\"", html):
            if src not in vistas:
                vistas.add(src)
                imagenes.append({"id": src, "autor": "", "licencia": "", "documento": "", "portada": False, "descripcion": ""})
    imagenes.sort(key=lambda x: not x["portada"])
    f["imagenes"] = imagenes

    m = re.search(r"miniMapa_(\d+)", html)
    f["mapaPk"] = m.group(1) if m else None

    for t in sopa(["script", "style"]):
        t.decompose()

    span = sopa.select_one("#nombreEspecieCompleto")
    if span:
        f["nombre"], f["autor"], f["rango"] = separar_nombre_html(span)
        f["nombreCompleto"] = limpiar(span.get_text())
    comun = sopa.select_one("#nombreComun")
    f["comunTitulo"] = limpiar(comun.get_text()) if comun else ""

    # Endemicidad
    end = {"canarias": {}, "macaronesia": {}}
    tabla = tabla_tras_titulo(sopa, "Endemicidad")
    if tabla:
        for tr in tabla.select("tbody tr"):
            tds = tr.find_all("td")
            if len(tds) >= 3:
                nivel = limpiar(tds[0].get_text()).lower()
                end["canarias"][nivel] = si_no(tds[1].get_text())
                end["macaronesia"][nivel] = si_no(tds[2].get_text())
    f["endemicidad"] = end

    # Origen
    tabla = tabla_tras_titulo(sopa, "Categorías de origen")
    if tabla:
        a = tabla.find("a", attrs={"data-content": True})
        doc = tabla.find("a", href=re.compile(r"/biota/documento/"))
        txt = limpiar(a.get_text()) if a else ""
        m = re.search(r"^(.*)\(([A-Z]+)\)$", txt)
        f["origen"] = {
            "nombre": limpiar(m.group(1)) if m else txt,
            "codigo": m.group(2) if m else "",
            "definicion": limpiar(a.get("data-content")) if a else "",
            "documento": doc["href"].rsplit("/", 1)[-1] if doc else "",
        }

    # Hábitat
    habitats = []
    tabla = tabla_tras_titulo(sopa, "Categorías de hábitat")
    if tabla:
        for tr in tabla.find_all("tr"):
            tds = tr.find_all("td")
            if tds:
                doc = tr.find("a", href=re.compile(r"/biota/documento/"))
                habitats.append({"categoria": limpiar(tds[0].get_text()),
                                 "documento": doc["href"].rsplit("/", 1)[-1] if doc else ""})
    f["habitats"] = habitats

    f["protegida"] = bool(sopa.find("a", href=re.compile(r"/centinela/especie/")))

    # Taxonomía
    tax = {}
    for lab in sopa.select("#taxonomyTab label"):
        rango = limpiar(lab.get_text()).rstrip(":").strip()
        valor = lab.find_next_sibling("a")
        if rango and valor:
            tax[rango] = limpiar(valor.get_text())
    f["taxonomia"] = tax
    m = re.search(r"Sub nómine\s*(\d+)", limpiar(sopa.select_one("#taxonomyTab").get_text()) if sopa.select_one("#taxonomyTab") else "")
    f["sinonimos"] = int(m.group(1)) if m else 0
    ref = sopa.select_one("#referencesTab")
    m = re.search(r"(\d+)\s+resultados", limpiar(ref.get_text()) if ref else "")
    f["referencias"] = int(m.group(1)) if m else 0

    # Protección por isla y catálogo
    prot = {}
    tab = sopa.select_one("#protectionLevelTab")
    if tab:
        for panel in tab.select(".panel"):
            titulo = panel.select_one(".panel-title")
            if not titulo:
                continue
            filas = {}
            for tr in panel.select("tbody tr"):
                tds = tr.find_all("td")
                if len(tds) >= 2:
                    a = tds[1].find("a", attrs={"data-content": True})
                    filas[limpiar(tds[0].get_text())] = {
                        "categoria": limpiar(tds[1].get_text()),
                        "definicion": limpiar(a.get("data-content")) if a else "",
                    }
            if filas:
                prot[limpiar(titulo.get_text())] = filas
    f["proteccion"] = prot

    # Enlaces de interés
    enlaces = []
    tab = sopa.select_one("#enlacesTab")
    if tab:
        titulo = ""
        for el in tab.find_all(["h3", "a"]):
            if el.name == "h3":
                titulo = limpiar(el.get_text())
            elif el.get("href", "").startswith("http"):
                enlaces.append({"titulo": titulo, "url": el["href"]})
    f["enlaces"] = enlaces
    for e in enlaces:
        if "iucnredlist.org" in e["url"]:
            m = re.search(r"(?:details|species)/(\d+)", e["url"])
            f["uicnId"] = m.group(1) if m else None
        if "gbif.org/species/" in e["url"]:
            m = re.search(r"species/(\d+)", e["url"])
            f["gbifId"] = m.group(1) if m else None
    return f


# -------------------------------------------------------------- ficha Centinela

def leer_ficha_centinela(html: str) -> dict:
    sopa = BeautifulSoup(html, "lxml")
    for t in sopa(["script", "style"]):
        t.decompose()
    secciones = {}
    for fila in sopa.select(".specieFile_info"):
        et = fila.find("span")
        if not et:
            continue
        clave = limpiar(et.get_text())
        partes = [limpiar(p.get_text()) for p in fila.find_all("p")]
        valor = "\n\n".join(p for p in partes if p)
        if clave and valor:
            secciones[clave] = valor
    return {"secciones": secciones, "pdf": bool(sopa.find("a", href=re.compile(r"/informe$")))}


# ------------------------------------------------------------------- documentos

def leer_documento(html: str) -> dict:
    """Título, autores y año de un documento de Biota (se usa como crédito de las fotos)."""
    sopa = BeautifulSoup(html, "lxml")
    for t in sopa(["script", "style"]):
        t.decompose()
    texto = limpiar(sopa.get_text(" "))
    def entre(a: str, b: str) -> str:
        m = re.search(re.escape(a) + r"\s+(.*?)\s+" + re.escape(b), texto)
        return limpiar(m.group(1)) if m else ""
    autores = entre("Autores", "Datos bibliográficos")
    autores = re.sub(r"(?<=\.) (?=[A-ZÁÉÍÓÚÑ][a-záéíóúñ])", "; ", autores)  # separa «Apellido, X. Apellido2, Y.»
    m = re.search(r"\bAño\s+(\d{4})", texto)
    return {"titulo": entre("Título completo", "Autores")[:300], "autores": autores, "anio": m.group(1) if m else ""}


# ------------------------------------------------------------------- composición

def nivel_endemicidad(rec: dict) -> str:
    rango = "subespecie" if rec.get("rango") not in (None, "especie") else "especie"
    end = rec.get("endemicidad") or {}
    can = end.get("canarias", {}).get(rango)
    mac = end.get("macaronesia", {}).get(rango)
    islas_seguras = [k for k, v in rec["presencia"].items() if v == "s" and k != "M"]
    if can or (can is None and rec.get("endemicoCsv")):
        return "insular" if len(islas_seguras) == 1 else "canario"
    if mac:
        return "macaronesico"
    cod = (rec.get("origen") or {}).get("codigo") or rec.get("origenCsv", "")
    return "nativo" if cod.startswith("N") else "introducido"


def resumen_proteccion(prot: dict) -> dict:
    """Categoría más relevante de cada catálogo (cualquier isla)."""
    out = {}
    for catalogo, islas in prot.items():
        cats = sorted({v["categoria"] for v in islas.values() if v["categoria"]})
        if cats:
            out[catalogo] = cats
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limite", type=int, default=0, help="máximo de taxones por grupo (pruebas)")
    ap.add_argument("--sin-fichas", action="store_true", help="solo exportaciones, sin fichas")
    args = ap.parse_args()

    cli = Cliente()
    (SALIDA / "fichas").mkdir(parents=True, exist_ok=True)
    inicio = time.time()

    # 1. Exportaciones por grupo
    registros: dict[str, dict] = {}
    for reino, grupo, subgrupo, params in GRUPOS:
        filas = exportar(cli, params)
        print(f"{grupo} / {subgrupo or '-'}: {len(filas)}", flush=True)
        for fila in filas[: args.limite or None]:
            registros.setdefault(fila["codigo"], {**fila, "reino": reino, "grupo": grupo, "subgrupo": subgrupo})
    for reino, grupo, params in COMPLETOS:
        filas = exportar(cli, params)
        extra = [f for f in filas if f["codigo"] not in registros and f["clase"] not in GRUPOS_EXCLUIDOS_FAUNA]
        print(f"{grupo} (completo): {len(filas)}; sin subgrupo: {len(extra)}", flush=True)
        if not args.limite:
            for fila in extra:
                registros[fila["codigo"]] = {**fila, "reino": reino, "grupo": "Otros", "subgrupo": None}
    centinela = exportar_centinela(cli)
    print(f"Centinela: {len(centinela)} taxones protegidos", flush=True)

    # 2. Fichas
    documentos: dict[str, dict] = {}
    indice = []
    errores = []
    total = len(registros)
    for n, (cod, base) in enumerate(sorted(registros.items(), key=lambda x: x[1]["completo"]), 1):
        nombre, autor, rango = separar_nombre_texto(base["completo"])
        rec = {
            "codigo": cod, "nombre": nombre, "autor": autor, "rango": rango, "nombreCompleto": base["completo"],
            "comunes": [c.strip() for c in base["comunes"].split(",") if c.strip()],
            "reino": base["reino"], "grupo": base["grupo"], "subgrupo": base["subgrupo"],
            "medio": base["medio"], "clase": base["clase"], "validez": base["validez"], "status": base["status"],
            "presencia": leer_presencia(base["presencia"]), "origenCsv": base["origen"], "endemicoCsv": base["endemico"],
            "nImagenes": base["nImagenes"], "fuentes": {"lista": "Biota (exportación oficial)"},
        }
        destino = SALIDA / "fichas" / f"{cod}.json"
        if not args.sin_fichas:
            try:
                r = cli.get(f"{BIOTA}/especie/{cod}")
                rec.update({k: v for k, v in leer_ficha_biota(r.text).items() if v not in (None, "")})
                rec["fuentes"]["ficha"] = f"{BIOTA}/especie/{cod}"
                for img in rec.get("imagenes", [])[:8]:
                    doc = img.get("documento")
                    if doc and doc not in documentos:
                        try:
                            documentos[doc] = leer_documento(cli.get(f"{BIOTA}/documento/{doc}").text)
                        except Exception as e:  # noqa: BLE001
                            documentos[doc] = {"titulo": "", "autores": "", "anio": "", "error": str(e)}
                    d = documentos.get(doc) or {}
                    img["credito"] = img.get("autor") or ", ".join(x for x in (d.get("autores"), d.get("anio")) if x)
                if rec.get("protegida") or base["completo"] in centinela:
                    rc = cli.get(f"{CENTINELA}/especie/{cod}")
                    rec["centinela"] = leer_ficha_centinela(rc.text)
                    rec["fuentes"]["centinela"] = f"{CENTINELA}/especie/{cod}"
            except Exception as e:  # noqa: BLE001
                errores.append({"codigo": cod, "error": str(e)})
                print(f"  ERROR {cod}: {e}", flush=True)
                if destino.exists():  # conservar la ficha anterior
                    rec = {**json.loads(destino.read_text(encoding="utf-8")), **{k: rec[k] for k in ("presencia", "status", "validez")}}
        rec["nivel"] = nivel_endemicidad(rec)
        rec["actualizado"] = datetime.now(timezone.utc).date().isoformat()
        destino.write_text(json.dumps(rec, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

        prot = resumen_proteccion(rec.get("proteccion", {}))
        portada = (rec.get("imagenes") or [{}])[0].get("id")
        indice.append({
            "c": cod, "n": rec["nombre"], "a": rec["autor"], "r": rec["rango"], "cm": rec["comunes"],
            "re": rec["reino"], "g": rec["grupo"], "sg": rec["subgrupo"], "cl": rec["clase"],
            "fa": rec.get("taxonomia", {}).get("Familia", ""), "md": rec["medio"],
            "is": "".join(f"{k}{v}" for k, v in rec["presencia"].items()),
            "o": (rec.get("origen") or {}).get("codigo") or rec["origenCsv"], "nv": rec["nivel"],
            "st": rec["status"], "hb": [h["categoria"] for h in rec.get("habitats", [])],
            "cc": prot.get("Catálogo Canario", []), "ce": prot.get("Catálogo Español/LESRPE", []),
            "pr": bool(rec.get("protegida")), "img": portada, "ni": rec["nImagenes"],
        })
        if n % 50 == 0 or n == total:
            mins = (time.time() - inicio) / 60
            print(f"[{n}/{total}] {mins:.1f} min", flush=True)

    # 3. Índice y metadatos
    indice.sort(key=lambda x: (x["re"] != "Flora", x["g"], x["fa"], x["n"]))
    for i, e in enumerate(indice, 1):
        e["no"] = i  # número de Pokédex: orden por reino, grupo, familia y nombre
    (SALIDA / "documentos.json").write_text(json.dumps(documentos, ensure_ascii=False, indent=1), encoding="utf-8")
    (SALIDA / "indice.json").write_text(json.dumps(indice, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = {
        "actualizado": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "taxones": len(indice),
        "porGrupo": {g: sum(1 for e in indice if e["g"] == g) for g in sorted({e["g"] for e in indice})},
        "errores": errores,
        "peticiones": cli.peticiones,
        "islas": ISLAS, "presencia": PRESENCIA,
        "fuentes": {"Biota": BIOTA, "Centinela": CENTINELA},
    }
    (SALIDA / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Listo: {len(indice)} taxones, {len(errores)} errores, {cli.peticiones} peticiones, "
          f"{(time.time() - inicio) / 60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
