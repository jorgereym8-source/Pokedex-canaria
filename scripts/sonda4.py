"""Sonda: compendio de especies introducidas (PDF) y carpetas de los informes art. 12 y 17 de la EEA."""
import io
import json
import re
import zipfile
from pathlib import Path

import requests

UA = "PokedexCanaria/0.1 (app personal sin fines comerciales; +https://github.com/jorgereym8-source/pokedex-canaria)"
s = requests.Session()
s.headers.update({"User-Agent": UA})
out = Path("sonda")
out.mkdir(exist_ok=True)
res = {}
TOKEN = "sptXqwkQr5g7Bp5"
DAV = f"https://sdi.eea.europa.eu/datashare/public.php/dav/files/{TOKEN}/"


def listar(ruta=""):
    r = s.request("PROPFIND", DAV + ruta, headers={"Depth": "1"}, timeout=120)
    return [h.split(TOKEN + "/", 1)[-1] for h in re.findall(r"<d:href>([^<]+)</d:href>", r.text)]


try:
    raiz = listar()
    res["raiz_art"] = [x for x in raiz if re.search(r"art1[27]|article", x, re.I)]
    res["raiz_n"] = len(raiz)
    for d in res["raiz_art"]:
        res["dir_" + d] = listar(d)[:40]
except Exception as e:  # noqa: BLE001
    res["dav_error"] = repr(e)

try:
    r = s.get("https://www.gobiernodecanarias.org/medioambiente/descargas/publicaciones/GOBCAN-2022-Compendio-fichas-especies-introducidas-2008-2011.zip", timeout=300)
    z = zipfile.ZipFile(io.BytesIO(r.content))
    nombres = [n.filename for n in z.infolist()]
    res["compendio_n"] = len(nombres)
    res["compendio_nombres"] = nombres[:60]
    from pypdf import PdfReader
    textos = {}
    for n in [x for x in nombres if x.lower().endswith(".pdf")][:4]:
        rd = PdfReader(io.BytesIO(z.read(n)))
        if rd.is_encrypted:
            rd.decrypt("")
        textos[n] = "\n".join((p.extract_text() or "") for p in rd.pages[:4])[:6000]
    res["compendio_textos"] = textos
except Exception as e:  # noqa: BLE001
    res["compendio_error"] = repr(e)

for u in ("https://ccdb.tau.ac.il/services/countsFull/?genus=Aeonium&format=json", "https://ccdb.tau.ac.il/"):
    try:
        r = s.get(u, timeout=60)
        res["ccdb_" + u[-20:]] = [r.status_code, r.text[:300]]
    except Exception as e:  # noqa: BLE001
        res["ccdb_" + u[-20:]] = repr(e)
(out / "_res.json").write_text(json.dumps(res, ensure_ascii=False, indent=1))
print(json.dumps(res, ensure_ascii=False)[:3000])
