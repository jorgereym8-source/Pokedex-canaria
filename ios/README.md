# Pokédex Canaria para iPhone (SwiftUI)

Versión nativa de la Pokédex Canaria, escrita desde cero en SwiftUI. Usa los mismos datos que la web (la carpeta `datos/` de este repositorio) y tiene las mismas pantallas: Inicio, Explorar, Mapa, Vistas y Ajustes, con los tres estilos (Naturalista, Pokédex clásica y Cuaderno de campo) y toda su personalización.

## Qué necesitas

- Un Mac con **Xcode 16 o posterior**.
- Un iPhone con **iOS 17 o posterior** y su cable (o la misma red wifi, una vez emparejado).
- Tu Apple ID. Con un Apple ID gratuito la app **caduca a los 7 días** y hay que volver a instalarla desde Xcode (basta con darle otra vez a ▶). Con la cuenta de desarrollador de Apple (99 €/año) dura un año.

## Instalarla en el iPhone

1. Descarga el repositorio completo en el Mac (con la carpeta `datos/`):
   ```sh
   git clone https://github.com/jorgereym8-source/pokedex-canaria.git
   cd pokedex-canaria
   git checkout ios-nativa
   ```
   Si ya lo tenías: `git pull` y `git checkout ios-nativa`.
2. Abre `ios/PokedexCanaria.xcodeproj` con Xcode.
3. En el panel de la izquierda, pulsa el proyecto **PokedexCanaria** → pestaña **Signing & Capabilities** → en **Team** elige tu Apple ID (si no aparece: *Add an Account…*). Si Xcode dice que el *Bundle Identifier* ya está cogido, cambia `es.jorgerey.pokedexcanaria` por otro, por ejemplo `es.jorgerey.pokedex2`.
4. Conecta el iPhone y elígelo arriba, en la lista de destinos.
5. En el iPhone, activa el modo de desarrollador: **Ajustes › Privacidad y seguridad › Modo de desarrollador** (se reinicia).
6. Pulsa ▶ (Run). La primera compilación tarda un poco porque empaqueta las 19.000 fichas.
7. La primera vez, el iPhone no la abrirá hasta que confíes en ti mismo: **Ajustes › General › VPN y gestión de dispositivos** → tu Apple ID → *Confiar*.

Si Xcode muestra algún error al compilar, ábrelo en el navegador de errores (el triángulo rojo de la barra lateral), copia el texto y pásamelo.

## Los datos

- Al compilar, la fase **«Datos de especies»** (`scripts/empaquetar_datos.py`, con el Python que trae Xcode) mete en la app el índice y todas las fichas, comprimidas en un solo archivo. La app funciona entera sin conexión (salvo fotos, mapas, sonidos y el calendario de iNaturalist, que se cargan de internet y se guardan para la próxima vez).
- **Actualizaciones**: GitHub regenera los datos el día 3 de cada mes. La app lo comprueba una vez al día en GitHub Pages; si hay datos nuevos, descarga el índice y, desde entonces, baja cada ficha al abrirla y la guarda. En **Ajustes › Datos y fotos** puedes buscar datos nuevos a mano y guardar todas las fichas nuevas para usarlas sin conexión.
- Si vuelves a compilar con datos más nuevos (`git pull` y ▶), la app usa los suyos y borra lo descargado.

## Avistamientos

Se guardan solo en el iPhone (SwiftData), con fecha, lugar (GPS, isla, municipio y altitud), el tiempo de ese momento (Open-Meteo), número de individuos, estado, tu foto y notas. Si guardas uno sin conexión, el tiempo y el nombre del lugar se completan solos más tarde.

Para pasar los avistamientos que tengas en la web: en la web, **Ajustes › Exportar › Hacer copia de seguridad**; manda ese archivo al iPhone y en la app ve a **Vistas › (botón de compartir) › Recuperar una copia**. La app también exporta a CSV (Excel) y hace copias de seguridad en el mismo formato que la web.

## Estructura

```
ios/
├── PokedexCanaria.xcodeproj
├── scripts/empaquetar_datos.py      empaqueta datos/ dentro de la app al compilar
└── PokedexCanaria/
    ├── App/                         arranque de la app
    ├── Datos/                       índice, fichas, filtros, búsqueda y actualizaciones
    ├── Estilo/                      ajustes, los tres estilos y las tipografías
    ├── Graficos/                    iconos, mapa de islas y diagrama de tamaño (los mismos dibujos que la web)
    ├── Avistamientos/               avistamientos, GPS, tiempo y lugar, copia de seguridad
    ├── Vistas/                      pantallas
    └── Recursos/                    icono, tipografías (licencia OFL) y contorno de las islas
```

Uso personal y sin fines comerciales. Las fotos se muestran desde su web de origen, con su autor y licencia.
