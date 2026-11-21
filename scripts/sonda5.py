"""Sonda: páginas de fichas del compendio y cabeceras de las tablas art. 12 y 17."""
import io
import json
import re
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


for d in ("eea_t_art12-2013-2018_p_2013-2018_v01_r01/Article12_2020_dataset_20210401_csv/",
          "eea_t_art17_p_2013-2018_v01_r00/Article17_2020_dataset_csv/",
          "eea_t_art17_p_2013-2018_v01_r00/Article17_2020_ref_codelists_csv/",
          "eea_t_art12-2013-2018_p_2013-2018_v01_r01/Article12_2020_ref_codelists_csv/"):
    try:
        archivos = listar(d)
        res[d] = {}
        for a in archivos[1:]:
            r = s.get(DAV + a, stream=True, timeout=120)
            datos = b""
            for t in r.iter_content(16384):
                datos += t
                if len(datos) > 400000:
                    break
            r.close()
            texto = datos.decode("utf-8", "replace")
            lineas = texto.splitlines()
            esp = [l for l in lineas if re.search(r"\bES\b|Fringilla|Gallotia|Dracaena", l)][:4]
            res[d][a.rsplit("/", 1)[-1]] = {"cab": lineas[:2], "es": esp}
    except Exception as e:  # noqa: BLE001
        res[d] = repr(e)

try:
    r = s.get("https://www.gobiernodecanarias.org/medioambiente/descargas/publicaciones/GOBCAN-2022-Compendio-fichas-especies-introducidas-2008-2011.zip", timeout=300)
    import zipfile
    from pypdf import PdfReader
    z = zipfile.ZipFile(io.BytesIO(r.content))
    rd = PdfReader(io.BytesIO(z.read(z.namelist()[0])))
    if rd.is_encrypted:
        rd.decrypt("")
    res["paginas"] = len(rd.pages)
    res["indice"] = "\n".join((rd.pages[i].extract_text() or "") for i in range(4, 14))[:8000]
    res["myoporum"] = "\n=====PAG=====\n".join((rd.pages[i].extract_text() or "") for i in range(574, 582))[:12000]
    res["ave"] = "\n=====PAG=====\n".join((rd.pages[i].extract_text() or "") for i in range(1300, 1306))[:8000]
except Exception as e:  # noqa: BLE001
    res["compendio_error"] = repr(e)
(out / "_res.json").write_text(json.dumps(res, ensure_ascii=False, indent=1))
