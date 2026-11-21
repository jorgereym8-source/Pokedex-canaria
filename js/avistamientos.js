// Avistamientos: se guardan solo en el iPhone (IndexedDB), con lugar, fecha y tiempo.

const BD = "pokedex-canaria";
const ALMACEN = "avistamientos";
let bd = null;
let cache = null;

function abrir() {
  if (bd) return Promise.resolve(bd);
  return new Promise((ok, mal) => {
    const r = indexedDB.open(BD, 1);
    r.onupgradeneeded = () => {
      const s = r.result.createObjectStore(ALMACEN, { keyPath: "id" });
      s.createIndex("codigo", "codigo");
      s.createIndex("fecha", "fecha");
    };
    r.onsuccess = () => { bd = r.result; ok(bd); };
    r.onerror = () => mal(r.error);
  });
}

function tx(modo, fn) {
  return abrir().then((db) => new Promise((ok, mal) => {
    const t = db.transaction(ALMACEN, modo);
    const s = t.objectStore(ALMACEN);
    const res = fn(s);
    t.oncomplete = () => ok(res?.result ?? res);
    t.onerror = () => mal(t.error);
  }));
}

export async function todos() {
  if (cache) return cache;
  const lista = await tx("readonly", (s) => s.getAll());
  cache = (lista || []).sort((a, b) => b.fecha.localeCompare(a.fecha));
  return cache;
}
export async function guardar(av) { cache = null; await tx("readwrite", (s) => s.put(av)); }
export async function borrar(id) { cache = null; await tx("readwrite", (s) => s.delete(id)); }
export async function borrarTodos() { cache = null; await tx("readwrite", (s) => s.clear()); }
export async function vistas() { return new Set((await todos()).map((a) => a.codigo)); }
export async function deEspecie(codigo) { return (await todos()).filter((a) => a.codigo === codigo); }
export const nuevoId = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`);

// ------------------------------------------------------------------- lugar

export function ubicar() {
  return new Promise((ok, mal) => {
    if (!navigator.geolocation) return mal(new Error("Este dispositivo no da la ubicación"));
    navigator.geolocation.getCurrentPosition(
      (p) => ok({ lat: p.coords.latitude, lon: p.coords.longitude, precision: Math.round(p.coords.accuracy || 0), altitud: p.coords.altitude != null ? Math.round(p.coords.altitude) : null }),
      (e) => mal(new Error(e.code === 1 ? "Permiso de ubicación denegado" : "No se pudo obtener la ubicación")),
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 30000 },
    );
  });
}

// Isla aproximada por rectángulos (funciona sin conexión). Los islotes van primero.
const CAJAS = [
  ["Lobos", 28.73, 28.77, -13.84, -13.79], ["La Graciosa", 29.21, 29.30, -13.55, -13.46],
  ["Alegranza y Montaña Clara", 29.36, 29.43, -13.54, -13.47],
  ["El Hierro", 27.62, 27.87, -18.17, -17.86], ["La Palma", 28.44, 28.87, -18.01, -17.71],
  ["La Gomera", 28.00, 28.23, -17.36, -17.08], ["Tenerife", 27.98, 28.60, -16.94, -16.10],
  ["Gran Canaria", 27.72, 28.19, -15.85, -15.34], ["Fuerteventura", 28.03, 28.77, -14.54, -13.81],
  ["Lanzarote", 28.83, 29.26, -13.89, -13.40],
];
export function islaDe(lat, lon) {
  const c = CAJAS.find(([, a, b, c1, d]) => lat >= a && lat <= b && lon >= c1 && lon <= d);
  return c ? c[0] : (lat > 27.4 && lat < 29.6 && lon > -18.4 && lon < -13.2 ? "Mar (Canarias)" : "Fuera de Canarias");
}

export async function nombreLugar(lat, lon) {
  // OpenStreetMap (Nominatim): municipio y paraje más cercano
  const u = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}&zoom=16&accept-language=es`;
  const r = await fetch(u, { headers: { Accept: "application/json" } });
  if (!r.ok) throw new Error("Sin nombre de lugar");
  const j = await r.json();
  const a = j.address || {};
  const municipio = a.city || a.town || a.village || a.municipality || a.county || "";
  const paraje = a.hamlet || a.suburb || a.neighbourhood || a.locality || a.isolated_dwelling || a.natural || a.peak || a.road || "";
  return { municipio, paraje: paraje && paraje !== municipio ? paraje : "" };
}

export async function altitudDem(lat, lon) {
  const r = await fetch(`https://api.open-meteo.com/v1/elevation?latitude=${lat}&longitude=${lon}`);
  const j = await r.json();
  return Array.isArray(j.elevation) ? Math.round(j.elevation[0]) : null;
}

// ------------------------------------------------------------------ tiempo

const WMO = {
  0: ["Despejado", "sol"], 1: ["Casi despejado", "sol"], 2: ["Parcialmente nuboso", "nubesol"], 3: ["Cubierto", "nube"],
  45: ["Niebla", "niebla"], 48: ["Niebla con escarcha", "niebla"], 51: ["Llovizna débil", "lluvia"], 53: ["Llovizna", "lluvia"],
  55: ["Llovizna intensa", "lluvia"], 61: ["Lluvia débil", "lluvia"], 63: ["Lluvia", "lluvia"], 65: ["Lluvia fuerte", "lluvia"],
  71: ["Nieve débil", "nieve"], 73: ["Nieve", "nieve"], 75: ["Nieve fuerte", "nieve"], 80: ["Chubascos débiles", "lluvia"],
  81: ["Chubascos", "lluvia"], 82: ["Chubascos fuertes", "lluvia"], 95: ["Tormenta", "tormenta"], 96: ["Tormenta con granizo", "tormenta"], 99: ["Tormenta con granizo", "tormenta"],
};
export const cielo = (codigo) => WMO[codigo] || ["—", "nube"];
const RUMBOS = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"];
export const rumbo = (g) => (g == null ? "" : RUMBOS[Math.round(((g % 360) / 45)) % 8]);

const VARS = "temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,wind_direction_10m,weather_code";
function empaquetar(o) {
  return {
    temperatura: o.temperature_2m, humedad: o.relative_humidity_2m, lluvia: o.precipitation, nubosidad: o.cloud_cover,
    viento: o.wind_speed_10m, direccion: o.wind_direction_10m, codigo: o.weather_code, fuente: "Open-Meteo",
  };
}

export async function tiempoAhora(lat, lon) {
  const r = await fetch(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=${VARS}&timezone=auto`);
  if (!r.ok) throw new Error("Sin datos del tiempo");
  const j = await r.json();
  return { ...empaquetar(j.current), hora: j.current.time };
}

// Para avistamientos guardados sin conexión: tiempo de esa hora, del histórico reciente o del archivo
export async function tiempoEn(lat, lon, fechaIso) {
  const d = new Date(fechaIso);
  const dia = d.toISOString().slice(0, 10);
  const urls = [
    `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=${VARS}&start_date=${dia}&end_date=${dia}&timezone=UTC`,
    `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&hourly=${VARS}&start_date=${dia}&end_date=${dia}&timezone=UTC`,
  ];
  for (const u of urls) {
    try {
      const r = await fetch(u);
      if (!r.ok) continue;
      const j = await r.json();
      const h = d.getUTCHours();
      const i = j.hourly?.time?.findIndex((t) => Number(t.slice(11, 13)) === h);
      if (i >= 0 && j.hourly.temperature_2m[i] != null) {
        const o = Object.fromEntries(Object.keys(j.hourly).map((k) => [k, j.hourly[k][i]]));
        return { ...empaquetar(o), hora: j.hourly.time[i], historico: true };
      }
    } catch { /* probar la siguiente */ }
  }
  throw new Error("Tiempo no disponible todavía");
}

export async function completarPendientes() {
  if (!navigator.onLine) return 0;
  let n = 0;
  for (const a of await todos()) {
    if (a.lat == null) continue;
    try {
      if (a.tiempoPendiente) { a.tiempo = await tiempoEn(a.lat, a.lon, a.fecha); a.tiempoPendiente = false; n++; }
      if (a.lugarPendiente) {
        const l = await nombreLugar(a.lat, a.lon);
        Object.assign(a, l, { lugarPendiente: false });
        if (a.altitud == null) a.altitud = await altitudDem(a.lat, a.lon);
        n++;
      }
      await guardar(a);
    } catch { /* se intentará más tarde */ }
  }
  return n;
}

// ----------------------------------------------------------------- fotos

export function reducirFoto(archivo, max = 1600) {
  return new Promise((ok, mal) => {
    const img = new Image();
    img.onload = () => {
      const k = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement("canvas");
      c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
      c.getContext("2d").drawImage(img, 0, 0, c.width, c.height);
      c.toBlob((b) => (b ? ok(b) : mal(new Error("No se pudo leer la foto"))), "image/jpeg", 0.85);
      URL.revokeObjectURL(img.src);
    };
    img.onerror = () => mal(new Error("No se pudo leer la foto"));
    img.src = URL.createObjectURL(archivo);
  });
}

// ------------------------------------------------------------ exportación

const COLS = ["fecha", "codigo", "nombre", "comun", "individuos", "estados", "isla", "municipio", "paraje", "lat", "lon", "precision", "altitud",
  "temperatura", "cielo", "viento", "direccion", "humedad", "lluvia", "nubosidad", "notas"];

export async function aCsv() {
  const filas = (await todos()).map((a) => {
    const t = a.tiempo || {};
    const v = {
      ...a, estados: (a.estados || []).join(" | "), temperatura: t.temperatura, cielo: t.codigo != null ? cielo(t.codigo)[0] : "",
      viento: t.viento, direccion: rumbo(t.direccion), humedad: t.humedad, lluvia: t.lluvia, nubosidad: t.nubosidad,
    };
    return COLS.map((c) => {
      const x = v[c] == null ? "" : String(v[c]);
      return /[;"\n]/.test(x) ? `"${x.replace(/"/g, '""')}"` : x;
    }).join(";");
  });
  return "﻿" + [COLS.join(";"), ...filas].join("\n");
}

export async function aJson() {
  const lista = await todos();
  return JSON.stringify(lista.map(({ foto, ...resto }) => resto), null, 1);
}

export async function importarJson(texto) {
  const lista = JSON.parse(texto);
  if (!Array.isArray(lista)) throw new Error("El archivo no es una lista de avistamientos");
  let n = 0;
  for (const a of lista) if (a && a.codigo && a.fecha) { await guardar({ ...a, id: a.id || nuevoId() }); n++; }
  return n;
}
