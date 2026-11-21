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
- Open-Meteo para el tiempo de los avistamientos.

Las fotos de Biota pertenecen a sus autores: la app las muestra desde su web, con crédito, y no las copia.

## Instalar en el iPhone

Abre la app en Safari, pulsa Compartir y elige «Añadir a pantalla de inicio».

## Estructura

- `index.html`, `css/`, `js/`: la app (sin compilación; HTML, CSS y JavaScript).
- `datos/`: índice y fichas de especies. Se regeneran solos el día 3 de cada mes (`.github/workflows/datos.yml`).
- `scripts/descargar.py`: descarga desde Biota y Centinela. Se ejecuta en GitHub Actions.
- `fuentes/`, `vendor/leaflet/`: tipografías y mapas alojados en la propia app (con sus licencias).
- `sw.js`: permite usar la app sin conexión.

Los avistamientos y tus fotos se guardan solo en el iPhone (IndexedDB). Desde Ajustes puedes exportarlos a CSV o hacer una copia de seguridad.

Uso personal y sin fines comerciales.
