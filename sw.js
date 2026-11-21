// Service worker: la app funciona sin conexión.
// - Estructura de la app: se guarda al instalar (cambia VERSION al publicar cambios).
// - Índice y fichas: primero la red, y si no hay, lo guardado.
// - Fotos de Biota y teselas del mapa: lo guardado primero, con límite de tamaño.
const VERSION = "v0.2.1";
const APP = `pokedex-canaria-app-${VERSION}`;
const DATOS = "pokedex-canaria-datos";
const FICHAS = "pokedex-canaria-fichas";
const IMAGENES = "pokedex-canaria-imagenes";
const MAX_IMAGENES = 400;

const ARCHIVOS = [
  "./", "index.html", "manifest.webmanifest", "css/fuentes.css", "css/app.css",
  "js/app.js", "js/ajustes.js", "js/datos.js", "js/ui.js", "js/avistamientos.js", "js/tamano.js",
  "vendor/leaflet/leaflet.js", "vendor/leaflet/leaflet.css", "vendor/leaflet/images/marker-icon.png",
  "vendor/leaflet/images/marker-icon-2x.png", "vendor/leaflet/images/marker-shadow.png",
  "iconos/favicon.png", "iconos/logo.png", "iconos/apple-touch-icon.png",
  "fuentes/inter-latin-400-normal.woff2", "fuentes/inter-latin-400-italic.woff2", "fuentes/inter-latin-600-normal.woff2",
  "fuentes/inter-latin-700-normal.woff2", "fuentes/vt323-latin-400-normal.woff2", "fuentes/press-start-2p-latin-400-normal.woff2",
  "fuentes/eb-garamond-latin-400-normal.woff2", "fuentes/eb-garamond-latin-400-italic.woff2", "fuentes/eb-garamond-latin-500-normal.woff2",
  "fuentes/caveat-latin-500-normal.woff2", "fuentes/caveat-latin-600-normal.woff2",
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(APP).then((c) => c.addAll(ARCHIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k.startsWith("pokedex-canaria-app-") && k !== APP).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

async function redPrimero(req, almacen) {
  const c = await caches.open(almacen);
  try {
    const r = await fetch(req);
    if (r.ok) c.put(req, r.clone());
    return r;
  } catch {
    const g = await c.match(req) || await caches.match(req);
    if (g) return g;
    throw new Error("Sin conexión");
  }
}

async function guardadoPrimero(req, almacen, max) {
  const c = await caches.open(almacen);
  const g = await c.match(req);
  if (g) return g;
  const r = await fetch(req);
  if (r.ok || r.type === "opaque") {
    await c.put(req, r.clone());
    if (max) c.keys().then((ks) => { if (ks.length > max) ks.slice(0, ks.length - max).forEach((k) => c.delete(k)); });
  }
  return r;
}

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  if (url.origin === location.origin) {
    if (url.pathname.includes("/datos/fichas/")) return e.respondWith(redPrimero(e.request, FICHAS));
    if (url.pathname.includes("/datos/")) return e.respondWith(redPrimero(e.request, DATOS));
    return e.respondWith(caches.match(e.request, { ignoreSearch: true }).then((g) => g || fetch(e.request)));
  }
  if (url.hostname === "www.biodiversidadcanarias.es" && /\/imagenes\/|\/minMap/.test(url.pathname)) {
    return e.respondWith(guardadoPrimero(e.request, IMAGENES, MAX_IMAGENES));
  }
  if (url.hostname === "tile.openstreetmap.org") return e.respondWith(guardadoPrimero(e.request, IMAGENES, MAX_IMAGENES * 2));
});
