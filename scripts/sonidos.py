"""Cantos y reclamos de aves, anfibios, mamíferos y reptiles.

  - xeno-canto (si hay clave en la variable de entorno XC_KEY, guardada como secreto de
    GitHub): grabaciones con licencia Creative Commons; primero las grabadas en Canarias.
  - iNaturalist: sonidos de observaciones de grado investigación con licencia Creative
    Commons; primero los de Canarias.

Los audios no se copian: la app los reproduce desde xeno-canto o iNaturalist con su autor
y licencia. Escribe en las fichas «sonidos». Caché en datos/extra/sonidos.json.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "datos"
EXTRA = DATOS / "extra"
UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
HOY = date.today().isoformat()
GRUPOS = {"Aves", "Anfibios", "Mamíferos", "Reptiles"}
PLACES = "130979,108930"  # Canarias (tierra y mar) en iNaturalist
CAJA = "27.4,-18.5,29.5,-13.2"
LIC_INAT = {"cc0": "CC0", "cc-by": "CC BY", "cc-by-sa": "CC BY-SA", "cc-by-nc": "CC BY-NC", "cc-by-nc-sa": "CC BY-NC-SA",
            "cc-by-nd": "CC BY-ND", "cc-by-nc-nd": "CC BY-NC-ND"}
RANGOS = {"subsp.", "var.", "f.", "×"}
XC_KEY = os.environ.get("XC_KEY", "").strip()
MAX = 3

s = requests.Session()
s.headers.update({"User-Agent": UA})


def get(url, params=None, intentos=3):
    espera = 3
    for n in range(intentos):
        try:
            r = s.get(url, params=params, timeout=60)
            if r.status_code in (200, 204, 404):
                return r
            if r.status_code == 429:
                time.sleep(30)
        except requests.RequestException as e:  # noqa: PERF203
            if n == intentos - 1:
                print(f"  sin respuesta {url.split('?')[0]}: {e}", flush=True)
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


def autor_inat(atr: str) -> str:
    m = re.match(r"\(c\)\s*(.+?),\s*(?:some|all) rights reserved", atr or "") or re.search(r"uploaded by (.+)$", atr or "")
    return (m.group(1) if m else (atr or "")).strip()[:80]


def lic_xc(url: str) -> str:
    m = re.search(r"licenses/([a-z-]+)/([\d.]+)", url or "")
    if not m:
        return "CC0" if "publicdomain" in (url or "") else ""
    return "CC " + m.group(1).upper() + " " + m.group(2)


# ------------------------------------------------------------------ xeno-canto

def xeno_canto(nombre: str) -> list[dict]:
    partes = [t for t in nombre.split() if t not in RANGOS]
    if len(partes) < 2:
        return []
    base = f"gen:{partes[0]} sp:{partes[1]}" + (f" ssp:{partes[2]}" if len(partes) > 2 else "")
    out = []
    for q in (f"{base} box:{CAJA}", base):
        r = get("https://xeno-canto.org/api/3/recordings", params={"query": q, "key": XC_KEY, "per_page": 50})
        time.sleep(1)
        if not r or r.status_code != 200:
            continue
        recs = r.json().get("recordings", [])
        recs.sort(key=lambda x: (x.get("q") or "E"))
        for x in recs:
            lic = lic_xc(x.get("lic", ""))
            if not lic or not x.get("file"):
                continue
            out.append({"url": x["file"], "autor": (x.get("rec") or "")[:80], "lic": lic,
                        "licUrl": ("https:" + x["lic"]) if x.get("lic", "").startswith("//") else x.get("lic", ""),
                        "pagina": f"https://xeno-canto.org/{x.get('id')}", "fuente": "xeno-canto",
                        "tipo": (x.get("type") or "")[:40], "lugar": ", ".join(filter(None, [x.get("loc"), x.get("cnt")]))[:80],
                        "canarias": "box:" in q})
            if len(out) >= MAX:
                return out
        if out:
            return out
    return out


# ------------------------------------------------------------------ iNaturalist

def inat_id(nombre: str, c_inat: dict) -> int | None:
    v = (c_inat.get("nombres") or {}).get(nombre) or {}
    if v.get("id"):
        return v["id"]
    r = get("https://api.inaturalist.org/v1/taxa", params={"q": " ".join(t for t in nombre.split() if t not in RANGOS), "per_page": 5})
    time.sleep(1)
    if r and r.status_code == 200:
        for t in r.json().get("results", []):
            if t.get("name", "").lower() == " ".join(t2 for t2 in nombre.split() if t2 not in RANGOS).lower():
                return t["id"]
    return None


def inaturalist(tid: int) -> list[dict]:
    out = []
    for lugar in (PLACES, None):
        params = {"taxon_id": tid, "sounds": "true", "quality_grade": "research", "per_page": 20, "order_by": "votes"}
        if lugar:
            params["place_id"] = lugar
        r = get("https://api.inaturalist.org/v1/observations", params=params)
        time.sleep(1)
        if not r or r.status_code != 200:
            continue
        for o in r.json().get("results", []):
            for snd in o.get("sounds") or []:
                lic = LIC_INAT.get(snd.get("license_code") or "")
                if not lic or not snd.get("file_url"):
                    continue
                out.append({"url": snd["file_url"], "autor": autor_inat(snd.get("attribution", "")), "lic": lic,
                            "licUrl": f"https://creativecommons.org/licenses/{(snd.get('license_code') or '').removeprefix('cc-')}/4.0/deed.es"
                            if lic != "CC0" else "https://creativecommons.org/publicdomain/zero/1.0/deed.es",
                            "pagina": o.get("uri") or f"https://www.inaturalist.org/observations/{o.get('id')}",
                            "fuente": "iNaturalist", "tipo": "", "lugar": (o.get("place_guess") or "")[:80], "canarias": bool(lugar)})
                break
            if len(out) >= MAX:
                return out
        if out:
            return out
    return out


def main() -> int:
    inicio = time.time()
    indice = json.loads((DATOS / "indice.json").read_text(encoding="utf-8"))
    rutas = {e["c"]: DATOS / "fichas" / f"{e['c']}.json" for e in indice}
    fichas = {c: json.loads(p.read_text(encoding="utf-8")) for c, p in rutas.items()}
    cache = cargar_json(EXTRA / "sonidos.json", {})
    c_inat = cargar_json(EXTRA / "inat.json", {})
    xc = bool(XC_KEY)
    print(f"xeno-canto: {'con clave' if xc else 'sin clave (solo iNaturalist)'}", flush=True)

    objetivos = [f for f in fichas.values() if f.get("grupo") in GRUPOS]
    pend = [f for f in objetivos if caducado(cache.get(f["nombre"], {}).get("fecha"), 120) or (xc and not cache.get(f["nombre"], {}).get("xc"))]
    print(f"Sonidos: {len(pend)} taxones por consultar", flush=True)
    try:
        for k, f in enumerate(pend, 1):
            if time.time() - inicio > float(os.environ.get("MINUTOS_SONIDOS", "60")) * 60:
                print(f"  tiempo agotado: quedan {len(pend) - k + 1} para la próxima ejecución", flush=True)
                break
            n = f["nombre"]
            lista = xeno_canto(n) if xc and f.get("grupo") in ("Aves", "Anfibios", "Mamíferos") else []
            if len(lista) < MAX:
                tid = inat_id(n, c_inat)
                if tid:
                    ya = {x["url"] for x in lista}
                    lista += [x for x in inaturalist(tid) if x["url"] not in ya][: MAX - len(lista)]
            cache[n] = {"fecha": HOY, "xc": xc, "lista": lista}
            if k % 100 == 0:
                print(f"  {k}/{len(pend)}", flush=True)
                (EXTRA / "sonidos.json").write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    finally:
        (EXTRA / "sonidos.json").write_text(json.dumps(cache, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    n_con = 0
    for c, f in fichas.items():
        f.pop("sonidos", None)
        lista = (cache.get(f["nombre"]) or {}).get("lista") or []
        if lista and f.get("grupo") in GRUPOS:
            f["sonidos"] = lista
            n_con += 1
    for c, f in fichas.items():
        rutas[c].write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    for e in indice:
        e.pop("so", None)
        if fichas[e["c"]].get("sonidos"):
            e["so"] = 1
    (DATOS / "indice.json").write_text(json.dumps(indice, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    meta = cargar_json(DATOS / "meta.json", {})
    meta["sonidos"] = {"fecha": HOY, "con_sonido": n_con, "xeno_canto": xc}
    (DATOS / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Sonidos: {n_con} taxones con sonido · {round((time.time() - inicio) / 60, 1)} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
