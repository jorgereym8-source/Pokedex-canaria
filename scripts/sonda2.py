"""Sonda ligera: comprueba URLs (estado, tipo, tamaño) y guarda como mucho 300 kB de cada una.

Lee scripts/sonda2_urls.txt (una URL por línea; las líneas con # se ignoran).
Para ZIP pequeños (< 60 MB) guarda además la lista de archivos que contienen.
"""
import io
import json
import re
import time
import zipfile
from pathlib import Path

import requests

UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
MAX = 300_000
s = requests.Session()
s.headers.update({"User-Agent": UA})
out = Path("sonda")
out.mkdir(exist_ok=True)
resumen = []
urls = [u.strip() for u in Path(__file__).with_name("sonda2_urls.txt").read_text().splitlines() if u.strip() and not u.startswith("#")]
for i, url in enumerate(urls):
    fila = {"url": url}
    try:
        r = s.get(url, stream=True, timeout=90, allow_redirects=True)
        fila.update(estado=r.status_code, tipo=r.headers.get("content-type", ""), longitud=r.headers.get("content-length"), final=r.url)
        datos = b""
        grande = int(r.headers.get("content-length") or 0)
        es_zip = url.lower().endswith(".zip") or "zip" in fila["tipo"]
        limite = 60_000_000 if es_zip and grande < 60_000_000 else MAX
        for trozo in r.iter_content(65536):
            datos += trozo
            if len(datos) >= limite:
                break
        r.close()
        fila["bytes"] = len(datos)
        if es_zip and len(datos) < limite:
            try:
                z = zipfile.ZipFile(io.BytesIO(datos))
                fila["zip"] = [(n.filename, n.file_size) for n in z.infolist()][:400]
            except Exception as e:  # noqa: BLE001
                fila["zip_error"] = str(e)
            datos = datos[:2000]
        nombre = f"{i:02d}_" + re.sub(r"[^A-Za-z0-9]+", "_", url.split("//", 1)[-1])[:90]
        (out / nombre).write_bytes(datos[:MAX])
        fila["archivo"] = nombre
    except Exception as e:  # noqa: BLE001
        fila["error"] = str(e)
    resumen.append(fila)
    print(json.dumps(fila, ensure_ascii=False)[:300], flush=True)
    time.sleep(1)
(out / "_resumen.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=1))
