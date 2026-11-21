// Ajustes: estilo de la app, personalización de cada estilo y preferencias generales.
// Se guardan en localStorage y se aplican como variables CSS sobre <html>.

const CLAVE = "pokedex-canaria:ajustes";

export const ESTILOS = { nat: "Naturalista", poke: "Pokédex", cua: "Cuaderno" };

const COLOR = {
  // Naturalista
  "Verde cardón": "#3D6B35", "Azul océano": "#2D6A8F", "Rojo tajinaste": "#B23A2E", "Ocre malpaís": "#9A6B12",
  "Violeta del Teide": "#6E4C8C", "Negro basalto": "#2A2D2B",
  "Arena clara": "#F4F5F1", "Blanco": "#FFFFFF", "Gris niebla": "#E9ECE7", "Noche volcánica": "#141816",
  // Pokédex
  "Rojo clásico": "#C3262F", "Azul": "#1F5FA8", "Amarillo": "#E3B21B", "Verde": "#2E6B2F", "Negro": "#2B2B2B",
  "Pantalla LCD verde": "#C9DDB8", "LCD ámbar": "#F2C46D", "LCD azul": "#B9D4EC", "LCD negra": "#17230F",
  // Cuaderno
  "Tinta azul": "#2D4A6B", "Tinta sepia": "#6B4A2B", "Tinta negra": "#2A2620", "Tinta verde": "#3E5A3A",
  "Papel crema": "#F2EBDC", "Papel blanco": "#FBFAF6", "Kraft": "#D9C4A0", "Papel oscuro": "#2E2A24",
};

const FUENTES = {
  "Sistema (San Francisco)": 'system-ui, -apple-system, "Segoe UI", sans-serif',
  "Inter": '"Inter", system-ui, sans-serif',
  "Atkinson Hyperlegible": '"Atkinson Hyperlegible", system-ui, sans-serif',
  "Fraunces": '"Fraunces", Georgia, serif',
  "EB Garamond": '"EB Garamond", Georgia, serif',
  "Press Start 2P (píxel)": '"Press Start 2P", monospace',
  "VT323 (LCD)": '"VT323", monospace',
};
// Algunas letras se ven más pequeñas o más grandes de lo normal: se compensan
const ESCALA_FUENTE = { "VT323 (LCD)": 1.25, "Press Start 2P (píxel)": 0.72, "EB Garamond": 1.08, "Caveat": 1.2 };

export const OPCIONES = [
  { id: "tema", etiqueta: "Tema", opciones: ["Automático", "Claro", "Oscuro", "Según la hora del día"],
    def: { nat: "Automático", poke: "Automático", cua: "Claro" } },
  { id: "color", etiqueta: { nat: "Color principal", poke: "Color de la carcasa", cua: "Color de la tinta" },
    opciones: { nat: ["Verde cardón", "Azul océano", "Rojo tajinaste", "Ocre malpaís", "Violeta del Teide", "Negro basalto", "Personalizado"],
      poke: ["Rojo clásico", "Azul", "Amarillo", "Verde", "Negro", "Personalizado"],
      cua: ["Tinta azul", "Tinta sepia", "Tinta negra", "Tinta verde", "Personalizado"] },
    def: { nat: "Verde cardón", poke: "Rojo clásico", cua: "Tinta azul" } },
  { id: "fondo", etiqueta: { nat: "Color de fondo", poke: "Color de la pantalla", cua: "Papel" },
    opciones: { nat: ["Arena clara", "Blanco", "Gris niebla", "Noche volcánica"],
      poke: ["Pantalla LCD verde", "LCD ámbar", "LCD azul", "LCD negra"],
      cua: ["Papel crema", "Papel blanco", "Kraft", "Papel oscuro"] },
    def: { nat: "Arena clara", poke: "Pantalla LCD verde", cua: "Papel crema" } },
  { id: "letra", etiqueta: "Tipo de letra", opciones: Object.keys(FUENTES),
    def: { nat: "Inter", poke: "VT323 (LCD)", cua: "EB Garamond" } },
  { id: "cient", etiqueta: "Nombres científicos", opciones: ["Cursiva de la misma letra", "Cursiva con serifa", "Sin cursiva"],
    def: { nat: "Cursiva de la misma letra", poke: "Cursiva de la misma letra", cua: "Cursiva con serifa" } },
  { id: "tam", etiqueta: "Tamaño del texto", opciones: ["Pequeño", "Normal", "Grande", "Muy grande"],
    def: { nat: "Normal", poke: "Normal", cua: "Normal" } },
  { id: "forma", etiqueta: "Forma de las tarjetas", opciones: ["Redondeada", "Suave", "Recta"],
    def: { nat: "Redondeada", poke: "Recta", cua: "Recta" } },
  { id: "dens", etiqueta: "Densidad", opciones: ["Compacta", "Cómoda", "Amplia"],
    def: { nat: "Cómoda", poke: "Compacta", cua: "Amplia" } },
  { id: "transp", etiqueta: "Fondos y transparencias", opciones: ["Liso", "Translúcido", "Textura de papel", "Malla de puntos"],
    def: { nat: "Translúcido", poke: "Liso", cua: "Textura de papel" } },
  { id: "iconos", etiqueta: "Iconos", opciones: ["Línea fina", "Línea gruesa", "Píxel"],
    def: { nat: "Línea fina", poke: "Píxel", cua: "Línea fina" } },
  { id: "anim", etiqueta: "Animaciones", opciones: ["Normales", "Reducidas", "Ninguna"],
    def: { nat: "Normales", poke: "Normales", cua: "Reducidas" } },
];

const GENERALES = {
  estilo: "nat",
  porEstilo: { nat: {}, poke: {}, cua: {} },
  personalizado: { nat: "#3D6B35", poke: "#C3262F", cua: "#2D4A6B" },
  nombres: "Todos",            // nombres comunes: Todos | Solo el principal
  autoria: true,               // mostrar autoría del nombre científico
  numeracion: "Taxonómica",    // Taxonómica | Alfabética
  altura: 180,                 // cm, para el diagrama de tamaño
  guardarLugar: true,
  precision: "Aprox. si amenazada", // Exacta | Aprox. si amenazada | Siempre aprox.
  guardarTiempo: true,
  fotosBiota: true,
  fotosLibres: true,
};

let estado = cargar();

function cargar() {
  try {
    const g = JSON.parse(localStorage.getItem(CLAVE) || "{}");
    return { ...structuredClone(GENERALES), ...g, porEstilo: { ...GENERALES.porEstilo, ...(g.porEstilo || {}) },
      personalizado: { ...GENERALES.personalizado, ...(g.personalizado || {}) } };
  } catch {
    return structuredClone(GENERALES);
  }
}

export function guardar() {
  try { localStorage.setItem(CLAVE, JSON.stringify(estado)); } catch { /* modo privado */ }
}

export function get(clave) { return estado[clave]; }
export function set(clave, valor) { estado[clave] = valor; guardar(); aplicar(); }

export function etiqueta(def) { return typeof def.etiqueta === "string" ? def.etiqueta : def.etiqueta[estado.estilo]; }
export function opcionesDe(def) { return Array.isArray(def.opciones) ? def.opciones : def.opciones[estado.estilo]; }
export function valor(id) {
  const def = OPCIONES.find((d) => d.id === id);
  return estado.porEstilo[estado.estilo]?.[id] || def.def[estado.estilo];
}
export function fijar(id, v) {
  estado.porEstilo[estado.estilo] = { ...(estado.porEstilo[estado.estilo] || {}), [id]: v };
  guardar(); aplicar();
}
export function restablecer() { estado.porEstilo[estado.estilo] = {}; guardar(); aplicar(); }
export function colorDe(nombre) {
  if (nombre === "Personalizado") return estado.personalizado[estado.estilo];
  return COLOR[nombre];
}
export function fijarPersonalizado(hex) { estado.personalizado[estado.estilo] = hex; fijar("color", "Personalizado"); }

// ------------------------------------------------------------------- color

function luminancia(hex) {
  const n = hex.replace("#", "");
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
const contraste = (a, b) => { const [x, y] = [luminancia(a), luminancia(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
const textoSobre = (hex) => (contraste(hex, "#FFFFFF") >= 4.5 ? "#FFFFFF" : "#17201A");
function mezclar(a, b, t) {
  const pa = a.replace("#", ""), pb = b.replace("#", "");
  const c = [0, 2, 4].map((i) => Math.round(parseInt(pa.slice(i, i + 2), 16) * (1 - t) + parseInt(pb.slice(i, i + 2), 16) * t));
  return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join("");
}
const esOscuro = (hex) => luminancia(hex) < 0.2;

function temaOscuro() {
  const t = valor("tema");
  if (t === "Oscuro") return true;
  if (t === "Claro") return false;
  if (t === "Según la hora del día") { const h = new Date().getHours(); return h >= 20 || h < 7; }
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches;
}

// --------------------------------------------------------------- aplicar

export function aplicar() {
  const e = estado.estilo;
  const raiz = document.documentElement.style;
  const cuerpo = document.body;
  cuerpo.classList.remove("estilo-nat", "estilo-poke", "estilo-cua", "textura-papel", "textura-puntos");
  cuerpo.classList.add(`estilo-${e}`);

  const oscuro = temaOscuro();
  let acento = colorDe(valor("color")) || "#3D6B35";
  let fondo = COLOR[valor("fondo")] || "#F4F5F1";
  if (oscuro && !esOscuro(fondo)) fondo = { nat: "#141816", poke: "#17230F", cua: "#2E2A24" }[e];
  const fondoOscuro = esOscuro(fondo);
  const v = {};

  if (e === "poke") {
    // La carcasa usa el color principal; la pantalla LCD es el «fondo» de los paneles
    const lcdTexto = { "#C9DDB8": "#17230F", "#F2C46D": "#3A2600", "#B9D4EC": "#0E2236", "#17230F": "#9BE07A" }[fondo] || (fondoOscuro ? "#9BE07A" : "#17230F");
    Object.assign(v, {
      "--carcasa": oscuro ? mezclar(acento, "#000000", 0.45) : acento, "--carcasa-txt": textoSobre(oscuro ? mezclar(acento, "#000000", 0.45) : acento),
      "--tecla": "#1F5FA8", "--fondo": fondo, "--superficie": fondo, "--superficie-2": mezclar(fondo, lcdTexto, 0.12),
      "--texto": lcdTexto, "--lcd-texto-2": mezclar(lcdTexto, fondo, 0.3),
      "--texto-2": mezclar(textoSobre(oscuro ? mezclar(acento, "#000000", 0.45) : acento), oscuro ? mezclar(acento, "#000000", 0.45) : acento, 0.18), "--borde": "#2B2B2B", "--borde-2": mezclar(fondo, lcdTexto, 0.25),
      "--acento": lcdTexto, "--acento-txt": fondo, "--acento-suave": mezclar(fondo, lcdTexto, 0.15), "--acento-tinta": lcdTexto,
    });
  } else {
    const texto = fondoOscuro ? (e === "cua" ? "#EDE4D3" : "#EEF1EC") : (e === "cua" ? "#2A2620" : "#1C211B");
    if (fondoOscuro && contraste(acento, fondo) < 3) acento = mezclar(acento, "#FFFFFF", 0.45);
    Object.assign(v, {
      "--acento": acento, "--acento-txt": textoSobre(acento),
      "--acento-suave": fondoOscuro ? mezclar(fondo, acento, 0.28) : mezclar("#FFFFFF", acento, 0.16),
      "--acento-tinta": fondoOscuro ? mezclar(acento, "#FFFFFF", 0.55) : mezclar(acento, "#000000", 0.35),
      "--fondo": fondo,
      "--superficie": e === "cua" ? fondo : (fondoOscuro ? mezclar(fondo, "#FFFFFF", 0.06) : "#FFFFFF"),
      "--superficie-2": fondoOscuro ? mezclar(fondo, "#FFFFFF", 0.1) : mezclar(fondo, "#000000", 0.035),
      "--texto": texto, "--texto-2": mezclar(texto, fondo, 0.38),
      "--borde": e === "cua" ? mezclar(texto, fondo, 0.7) : (fondoOscuro ? mezclar(fondo, "#FFFFFF", 0.14) : mezclar(fondo, "#000000", 0.08)),
      "--borde-2": fondoOscuro ? mezclar(fondo, "#FFFFFF", 0.09) : mezclar(fondo, "#000000", 0.04),
      "--barra-fondo": fondoOscuro ? "rgba(20,24,22,0.92)" : "rgba(255,255,255,0.94)",
    });
  }

  const letra = valor("letra");
  const fuente = FUENTES[letra] || FUENTES.Inter;
  const tamBase = { "Pequeño": 15, "Normal": 16, "Grande": 18, "Muy grande": 20 }[valor("tam")] || 16;
  const cient = valor("cient");
  Object.assign(v, {
    "--font": fuente,
    "--font-titulo": e === "cua" ? FUENTES["EB Garamond"] : fuente,
    "--font-sci": cient === "Cursiva con serifa" ? FUENTES["EB Garamond"] : (letra.startsWith("Press") ? FUENTES.Inter : fuente),
    "--sci-style": cient === "Sin cursiva" ? "normal" : "italic",
    "--tam": `${Math.round(tamBase * (ESCALA_FUENTE[letra] || 1))}px`,
    "--radio": { "Redondeada": "18px", "Suave": "8px", "Recta": "0px" }[valor("forma")],
    "--radio-p": { "Redondeada": "10px", "Suave": "5px", "Recta": "0px" }[valor("forma")],
    "--esp": { "Compacta": 0.75, "Cómoda": 1, "Amplia": 1.25 }[valor("dens")],
    "--trazo": { "Línea fina": 1.7, "Línea gruesa": 2.4, "Píxel": 2.6 }[valor("iconos")],
    "--anim": { "Normales": "0.22s", "Reducidas": "0.08s", "Ninguna": "0s" }[valor("anim")],
    "--barra-blur": valor("transp") === "Translúcido" ? "14px" : "0px",
  });
  if (valor("transp") !== "Translúcido") v["--barra-fondo"] = "var(--fondo)";
  if (valor("transp") === "Textura de papel") cuerpo.classList.add("textura-papel");
  if (valor("transp") === "Malla de puntos") cuerpo.classList.add("textura-puntos");
  cuerpo.style.setProperty("--trazo-linecap", valor("iconos") === "Píxel" ? "square" : "round");

  for (const [k, val] of Object.entries(v)) raiz.setProperty(k, val);
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", e === "poke" ? v["--carcasa"] : v["--fondo"]);
}

export function muestraDe(nombre) { return colorDe(nombre) || null; }
export function fuenteDe(nombre) { return FUENTES[nombre] || null; }
window.matchMedia?.("(prefers-color-scheme: dark)").addEventListener?.("change", () => aplicar());
