"""Sonda de estructura de las fuentes nuevas (se ejecuta en GitHub Actions)."""
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


def guarda(k, v):
    res[k] = v
    print(k, json.dumps(v, ensure_ascii=False)[:600], flush=True)


def intento(k, f):
    try:
        guarda(k, f())
    except Exception as e:  # noqa: BLE001
        guarda(k, {"error": repr(e)[:300]})


TOKEN = "sptXqwkQr5g7Bp5"


def propfind(ruta):
    for url, auth in ((f"https://sdi.eea.europa.eu/datashare/public.php/dav/files/{TOKEN}/{ruta}", None),
                      (f"https://sdi.eea.europa.eu/datashare/public.php/webdav/{ruta}", (TOKEN, ""))):
        r = s.request("PROPFIND", url, headers={"Depth": "1"}, auth=auth, timeout=60)
        if r.status_code in (200, 207):
            return {"url": url, "items": re.findall(r"<d:href>([^<]+)</d:href>", r.text)[:80]}
    return {"estado": r.status_code, "texto": r.text[:300]}


for uuid in ("e2face16-f352-4aff-9e4f-0ad1306f89b5", "7b25f644-63a6-4aff-9440-a76ab952907b",
             "7638812a-2063-40bc-b4cc-1b440e00e60e", "14984214-a151-49bb-acc1-24156a550e43"):
    intento(f"data_{uuid[:8]}", lambda u=uuid: s.get(f"https://sdi.eea.europa.eu/data/{u}", timeout=60).url)
intento("dav_raiz", lambda: propfind(""))
intento("dav_natura", lambda: propfind("eea_t_natura2000_p_2024_v01_r01/"))
intento("dav_natura_csv", lambda: propfind("eea_t_natura2000_p_2024_v01_r01/CSV/"))


def compendio():
    r = s.get("https://www.gobiernodecanarias.org/medioambiente/descargas/publicaciones/GOBCAN-2022-Compendio-fichas-especies-introducidas-2008-2011.zip", timeout=300)
    z = zipfile.ZipFile(io.BytesIO(r.content))
    nombres = [n.filename for n in z.infolist()]
    textos = {}
    from pypdf import PdfReader
    pdfs = [n for n in nombres if n.lower().endswith(".pdf")]
    for n in pdfs[:3]:
        txt = "\n".join((p.extract_text() or "") for p in PdfReader(io.BytesIO(z.read(n))).pages[:3])
        textos[n] = txt[:3000]
    (out / "compendio_textos.json").write_text(json.dumps(textos, ensure_ascii=False, indent=1))
    return {"n": len(nombres), "pdfs": len(pdfs), "primeros": nombres[:40]}


intento("compendio", compendio)

for id_ in ("BOE-A-1995-8639", "BOE-A-2013-8565"):
    def boe(i=id_):
        r = s.get(f"https://www.boe.es/datosabiertos/api/legislacion-consolidada/id/{i}/texto", headers={"Accept": "application/xml"}, timeout=60)
        (out / f"{i}.xml").write_bytes(r.content)
        return {"estado": r.status_code, "bytes": len(r.content)}
    intento(f"boe_{id_}", boe)

for u in ("https://ccdb.tau.ac.il/services/countsFull/?genus=Aeonium&format=json",
          "https://ccdb.tau.ac.il/services/countsFull/?species=Aeonium%20arboreum&format=json",
          "http://ccdb.tau.ac.il/services/countsFull/?genus=Aeonium&format=json"):
    intento("ccdb_" + u[-40:], lambda u=u: (lambda r: {"estado": r.status_code, "t": r.text[:400]})(s.get(u, timeout=60)))


def avonet():
    import openpyxl
    r = s.get("https://ndownloader.figshare.com/files/34480856", timeout=300)
    wb = openpyxl.load_workbook(io.BytesIO(r.content), read_only=True)
    info = {}
    for ws in wb.worksheets:
        filas = list(ws.iter_rows(min_row=1, max_row=3, values_only=True))
        info[ws.title] = [list(map(str, f))[:40] for f in filas]
    return info


intento("avonet", avonet)


def wcvp():
    r = s.get("https://sftp.kew.org/pub/data-repositories/WCVP/wcvp.zip", timeout=600)
    z = zipfile.ZipFile(io.BytesIO(r.content))
    info = {"archivos": [(n.filename, n.file_size) for n in z.infolist()]}
    for n in z.namelist():
        if n.endswith(".csv"):
            with z.open(n) as f:
                info[n] = [f.readline().decode("utf-8", "replace")[:700] for _ in range(3)]
    with z.open([n for n in z.namelist() if "names" in n][0]) as f:
        for linea in f:
            l = linea.decode("utf-8", "replace")
            if "|Aeonium arboreum|" in l or "|Dracaena draco|" in l:
                info.setdefault("ejemplos", []).append(l[:900])
            if len(info.get("ejemplos", [])) > 3:
                break
    return info


intento("wcvp", wcvp)


def fishbase():
    import pandas as pd
    base = "https://huggingface.co/datasets/cboettig/fishbase/resolve/main/data/fb/v23.05/parquet/"
    info = {}
    for t in ("species", "estimate", "stocks", "ecology"):
        df = pd.read_parquet(base + t + ".parquet")
        info[t] = list(df.columns)
        ej = df[df.get("SpecCode", df.columns[0]) == 4472] if "SpecCode" in df.columns else df.head(1)
        info[t + "_ej"] = ej.head(1).astype(str).to_dict("records")
    return info


intento("fishbase", fishbase)


def dem():
    ok = []
    for lat in (27, 28, 29):
        for lon in range(19, 12, -1):
            n = f"Copernicus_DSM_COG_30_N{lat:02d}_00_W{lon:03d}_00_DEM"
            r = s.head(f"https://copernicus-dem-90m.s3.amazonaws.com/{n}/{n}.tif", timeout=30)
            if r.status_code == 200:
                ok.append(n)
    return ok


intento("dem", dem)
(out / "_res.json").write_text(json.dumps(res, ensure_ascii=False, indent=1))
