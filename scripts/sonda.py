"""Sonda: descarga unas pocas páginas de Biota y Centinela para estudiar su estructura.

Se ejecuta en GitHub Actions (el entorno de desarrollo no tiene acceso a esas webs).
Guarda cada respuesta tal cual en sonda/ junto con un resumen (estado, tipo, tamaño),
y además los .js propios que cargan las páginas, para localizar llamadas AJAX.
"""

import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests

UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
PAUSA = 1.5  # segundos entre peticiones, para no cargar los servidores

BIOTA = "https://www.biodiversidadcanarias.es/biota"
CENTINELA = "https://www.biodiversidadcanarias.es/centinela"

URLS = [
    "https://www.biodiversidadcanarias.es/robots.txt",
    f"{BIOTA}",
    f"{BIOTA}/especies",
    f"{BIOTA}/especie/F01736",
    f"{BIOTA}/especie/F02220",
    f"{BIOTA}/taxonomia",
    f"{BIOTA}/taxonomia?selecLevel=Familia&nombreLat=Asparagaceae",
    f"{BIOTA}/informeTaxonomia",
    f"{BIOTA}/estadisticas?se=0&m=0",
    f"{BIOTA}/galeria",
    f"{BIOTA}/minMap?especiePk=11177&width=525&height=250",
    f"{BIOTA}/especie/F01736/imagenes/124223670",
    f"{BIOTA}/especie/F01736/imagenes/124223670?thumbnails=true",
    f"{BIOTA}/documento/F00038",
    f"{CENTINELA}",
    f"{CENTINELA}/especies",
    f"{CENTINELA}/especie/F01736",
    f"{CENTINELA}/especie/F01736/informe",
    f"{CENTINELA}/nivelesProteccion",
]

EXT = {
    "text/html": ".html",
    "application/json": ".json",
    "application/javascript": ".js",
    "text/javascript": ".js",
    "application/pdf": ".pdf",
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "text/plain": ".txt",
}


def nombre_fichero(url: str, ctype: str) -> str:
    p = urlparse(url)
    base = (p.path.strip("/") or "raiz").replace("/", "__")
    if p.query:
        base += "__" + re.sub(r"[^A-Za-z0-9]+", "_", p.query)
    return base[:150] + EXT.get(ctype.split(";")[0].strip(), ".bin")


def main() -> int:
    # Si existe scripts/sonda_urls.txt, se usan esas URL (una por línea) en lugar de la lista fija
    lista = Path(__file__).with_name("sonda_urls.txt")
    urls = [u.strip() for u in lista.read_text(encoding="utf-8").splitlines() if u.strip() and not u.startswith("#")] if lista.exists() else URLS
    seguir_js = not lista.exists()
    out = Path("sonda")
    out.mkdir(exist_ok=True)
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Accept-Language": "es-ES,es;q=0.9"})

    resumen = []
    scripts_vistos = set()
    cola = list(urls)
    while cola:
        url = cola.pop(0)
        try:
            r = s.get(url, timeout=60)
            ctype = r.headers.get("content-type", "")
            fichero = nombre_fichero(url, ctype)
            (out / fichero).write_bytes(r.content)
            item = {"url": url, "estado": r.status_code, "tipo": ctype, "bytes": len(r.content), "fichero": fichero}
            if "html" in ctype and seguir_js:
                texto = r.text
                item["robot"] = "por ser un robot" in texto
                # Scripts propios del sitio: ahí suelen estar las llamadas AJAX
                for src in re.findall(r'<script[^>]+src="([^"]+)"', texto):
                    absoluta = urljoin(url, src)
                    if urlparse(absoluta).netloc.endswith("biodiversidadcanarias.es") and absoluta not in scripts_vistos and len(scripts_vistos) < 25:
                        scripts_vistos.add(absoluta)
                        cola.append(absoluta)
            resumen.append(item)
            print(f"{r.status_code} {len(r.content):>8} {ctype[:30]:30} {url}")
        except Exception as e:  # noqa: BLE001
            resumen.append({"url": url, "error": str(e)})
            print(f"ERROR {url}: {e}")
        time.sleep(PAUSA)

    (out / "_resumen.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
