#!/usr/bin/env python3
"""Empaqueta los datos de especies para la app de iPhone.

Xcode lo ejecuta en cada compilación (fase «Datos de especies»):

    python3 empaquetar_datos.py <carpeta datos/ del repositorio> <carpeta Datos/ dentro de la app>

Copia indice.json y meta.json y junta las ~19.000 fichas en un único archivo comprimido
(fichas.pack) con su índice (fichas.idx), para que la app ocupe menos y se instale más rápido.
Si los datos no han cambiado desde la última vez, no hace nada.
"""
import hashlib
import json
import os
import shutil
import sys
import zlib


def firma(origen):
    h = hashlib.sha256()
    for nombre in ("meta.json", "indice.json"):
        ruta = os.path.join(origen, nombre)
        with open(ruta, "rb") as f:
            h.update(f.read())
    carpeta = os.path.join(origen, "fichas")
    nombres = sorted(n for n in os.listdir(carpeta) if n.endswith(".json"))
    h.update(str(len(nombres)).encode())
    h.update(str(max(os.path.getmtime(os.path.join(carpeta, n)) for n in nombres) if nombres else 0).encode())
    return h.hexdigest()


def main():
    if len(sys.argv) != 3:
        print("Uso: empaquetar_datos.py <origen datos/> <destino>", file=sys.stderr)
        return 2
    origen, destino = sys.argv[1], sys.argv[2]
    if not os.path.isfile(os.path.join(origen, "indice.json")):
        print(f"error: no encuentro {origen}/indice.json. ¿Has descargado el repositorio completo?", file=sys.stderr)
        return 1
    os.makedirs(destino, exist_ok=True)
    f_nueva = firma(origen)
    ruta_firma = os.path.join(destino, "firma.txt")
    if os.path.isfile(ruta_firma) and os.path.isfile(os.path.join(destino, "fichas.pack")):
        with open(ruta_firma) as f:
            if f.read().strip() == f_nueva:
                print("Datos de especies sin cambios")
                return 0

    for nombre in ("indice.json", "meta.json"):
        shutil.copyfile(os.path.join(origen, nombre), os.path.join(destino, nombre))

    carpeta = os.path.join(origen, "fichas")
    entradas = {}
    desplazamiento = 0
    tmp = os.path.join(destino, "fichas.pack.tmp")
    with open(tmp, "wb") as salida:
        for nombre in sorted(os.listdir(carpeta)):
            if not nombre.endswith(".json"):
                continue
            with open(os.path.join(carpeta, nombre), "rb") as f:
                crudo = f.read()
            # DEFLATE sin cabecera (wbits -15): es lo que espera NSData.decompressed(using: .zlib) en iOS
            c = zlib.compressobj(9, zlib.DEFLATED, -15)
            comprimido = c.compress(crudo) + c.flush()
            salida.write(comprimido)
            entradas[nombre[:-5]] = [desplazamiento, len(comprimido), len(crudo)]
            desplazamiento += len(comprimido)
    os.replace(tmp, os.path.join(destino, "fichas.pack"))
    with open(os.path.join(destino, "fichas.idx"), "w") as f:
        json.dump({"formato": 1, "compresion": "deflate", "fichas": entradas}, f, separators=(",", ":"))
    with open(ruta_firma, "w") as f:
        f.write(f_nueva)
    print(f"Empaquetadas {len(entradas)} fichas ({desplazamiento / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
