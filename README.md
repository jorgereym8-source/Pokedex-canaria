# Pokédex Canaria

App web tipo Pokédex de la flora y fauna de Canarias, pensada para añadirla a la pantalla de inicio del iPhone.

## Qué incluye

- Flora vascular y vertebrados (nativos, endémicos e introducidos), ampliable a otros grupos.
- Ficha de especie: nombre científico y autoría, nombres comunes, taxonomía, endemicidad y origen, distribución por islas, hábitat, poblaciones, amenaza y protección (UICN, Lista Roja, Catálogo Canario, Catálogo Español, Directiva Hábitats/Aves, Berna), tamaño comparado con una silueta humana, floración o cría, longevidad, fotos y enlaces a las webs oficiales.
- Avistamientos: marcar especies como vistas guardando fecha, hora, lugar (GPS) y tiempo meteorológico del momento.
- Tres estilos (Naturalista, Pokédex clásica y Cuaderno de campo), cada uno personalizable.

## Fuentes de datos

Cada dato se guarda con su fuente.

- [Banco de Datos de Biodiversidad de Canarias (Biota)](https://www.biodiversidadcanarias.es/biota): taxonomía, nombres, endemicidad, origen, distribución, fotos (enlazadas, con crédito).
- [Centinela](https://www.biodiversidadcanarias.es/centinela): especies protegidas, hábitat, poblaciones, categorías legales.
- Lista de especies silvestres de Canarias (Gobierno de Canarias).
- MITECO (Atlas y Libros Rojos), UICN, GBIF, iNaturalist y Wikidata para completar tamaño, longevidad y fenología.
- [Wikimedia Commons](https://commons.wikimedia.org) e [iNaturalist](https://www.inaturalist.org): fotos con licencia libre (CC0, CC BY, CC BY-SA y, de iNaturalist, también CC BY-NC y CC BY-NC-SA) para completar las de Biota.
- [Especies Vegetales en Canarias](https://endemicascanarias.com) (Gerardo G. Casanova y colaboradores): solo enlace a la ficha de cada planta. Sus fotos tienen © y la web pide el consentimiento expreso del autor para usarlas, así que no se muestran en la app.
- Rasgos por grupo: AnAge (reproducción), AVONET y EltonTraits (aves y mamíferos), FishBase (peces), WCVP de Kew (forma vital, clima y distribución mundial de las plantas) y Chromosome Counts Database (números cromosomáticos, cuando el servicio responde).
- Conservación: Red Natura 2000 y los informes de los artículos 12 y 17 de las directivas Aves y Hábitats (Agencia Europea de Medio Ambiente), tallas mínimas del caladero canario (Real Decreto 560/1995, BOE) y el Compendio de fichas de la Base de especies introducidas en Canarias (Gobierno de Canarias).
- Altitud y primer registro: registros de GBIF en Canarias y el modelo del terreno Copernicus GLO-90.
- Sonidos: xeno-canto (con clave, como secreto `XC_KEY` de GitHub) e iNaturalist, con licencia Creative Commons.
- Vulnerabilidad al cambio climático: solo si se rellena `datos-propios/vulnerabilidad.csv`.
- Open-Meteo para el tiempo de los avistamientos.

Las fotos pertenecen a sus autores: la app las muestra desde la web de origen (Biota, Commons o iNaturalist), con su autor y licencia, y no las copia.

## Instalar en el iPhone

Abre la app en Safari, pulsa Compartir y elige «Añadir a pantalla de inicio».

## Estructura

- `index.html`, `css/`, `js/`: la app (sin compilación; HTML, CSS y JavaScript).
- `datos/`: índice y fichas de especies. Se regeneran solos el día 3 de cada mes (`.github/workflows/datos.yml`).
- `scripts/descargar.py`: descarga desde Biota y Centinela. Se ejecuta en GitHub Actions.
- `scripts/enriquecer.py`: categoría UICN, tamaño, peso, longevidad y ciclo de vida.
- `scripts/fotos.py`: fotos con licencia libre y enlaces a Especies Vegetales en Canarias.
- `scripts/rasgos.py`, `scripts/conservacion.py`, `scripts/registros.py`, `scripts/sonidos.py`: biología por grupos, conservación y normativa, altitud y primer registro, y sonidos.
- `fuentes/`, `vendor/leaflet/`: tipografías y mapas alojados en la propia app (con sus licencias).
- `sw.js`: permite usar la app sin conexión.

Los avistamientos y tus fotos se guardan solo en el iPhone (IndexedDB). Desde Ajustes puedes exportarlos a CSV o hacer una copia de seguridad.

Uso personal y sin fines comerciales.
