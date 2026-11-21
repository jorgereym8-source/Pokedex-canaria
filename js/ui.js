// Utilidades de interfaz: iconos, nombres, insignias, mapa de islas y avisos.
import { MAPA } from "./islas.js";

export const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

const P = {
  hoja: "M5 19C5 10 10 5 19 5c0 9-5 14-14 14zM5 19l9-9",
  pluma: "M20 4C12 4 7 9 7 17v3h3c8 0 10-6 10-16zM7 20l9-10",
  ave: "M2 13.5l4.5 1c1.5-3 4.5-5 8-5 .5-2 2-3 3.5-3 1.3 0 2.3.8 2.6 2l1.4.6-1.6.4c0 3.6-2.8 7.4-8.4 7.4-3 0-5.5-1.2-7-3M8.5 13.5c1.5 1.2 4 1.3 6-.3M18.2 8.4v.01M11 17.8l-.6 2.4M13.6 17.6l.4 2.4",
  lagarto: "M3 17c2 1 4 0 5-2l2-4c1-2 3-3 5-3h2c2 0 3 1 3 2s-1 2-3 2h-2c-2 0-3 1-4 3l-1 2c-1 2-3 3-5 3M8 15l-2 3M13 13l2 3M11 9l-1-3M16 8l1-3",
  pata: "M8 10a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2zM16 10a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2zM5 14a1.4 1.4 0 1 1 0-2.8 1.4 1.4 0 0 1 0 2.8zM19 14a1.4 1.4 0 1 1 0-2.8 1.4 1.4 0 0 1 0 2.8zM12 13c-3 0-5 3-5 5 0 1.5 1.5 2 2.5 2s1.5-.6 2.5-.6 1.5.6 2.5.6 2.5-.5 2.5-2c0-2-2-5-5-5z",
  rana: "M7 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM17 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM4 14c0-3 3-5 8-5s8 2 8 5-3 5-8 5-8-2-8-5zM9 14h6",
  pez: "M3 12c3-4 8-5 12-3l5-3v12l-5-3c-4 2-9 1-12-3zM8 11v.01",
  helecho: "M12 21V5M12 7c-2 0-4-1-5-3M12 7c2 0 4-1 5-3M12 11c-3 0-5-1-6-3M12 11c3 0 5-1 6-3M12 15c-3 0-6-1-7-3M12 15c3 0 6-1 7-3",
  buscar: "M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM20 20l-4-4",
  ajustes: "M4 7h9M17 7h3M4 17h3M11 17h9M17 7a2 2 0 1 1-4 0 2 2 0 0 1 4 0zM11 17a2 2 0 1 1-4 0 2 2 0 0 1 4 0z",
  inicio: "M4 11l8-7 8 7v9h-5v-6H9v6H4z",
  explorar: "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z",
  mapa: "M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2zM9 4v14M15 6v14",
  vistas: "M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18zM8 12l3 3 5-6",
  check: "M5 12l5 5 9-10",
  flecha: "M9 6l6 6-6 6",
  atras: "M15 6l-6 6 6 6",
  externo: "M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5",
  compartir: "M12 3v12M7 8l5-5 5 5M5 13v6a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-6",
  filtro: "M4 6h16M7 12h10M10 18h4",
  cerrar: "M6 6l12 12M18 6L6 18",
  alerta: "M12 4l9 16H3zM12 10v4M12 17v.01",
  pin: "M12 21s-6-6-6-11a6 6 0 0 1 12 0c0 5-6 11-6 11zM12 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
  flor: "M12 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM12 10V5M12 14v5M10 12H5M14 12h5M10.5 10.5l-3-3M13.5 13.5l3 3M13.5 10.5l3-3M10.5 13.5l-3 3",
  escudo: "M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6zM12 9v4M12 16v.01",
  regla: "M4 17L17 4l3 3L7 20zM8 13l2 2M11 10l2 2M14 7l2 2",
  reloj: "M7 3h10M7 21h10M8 3c0 5 8 6 8 9s-8 4-8 9M16 3c0 5-8 6-8 9s8 4 8 9",
  calendario: "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4",
  mira: "M12 3v18M3 12h18M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z",
  montana: "M3 19l6-9 4 5 3-4 5 8z",
  camara: "M4 8h3l2-3h6l2 3h3v11H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
  sol: "M12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
  nubesol: "M8 6a3 3 0 0 1 5.5 1.5M6 4l.8.8M3 8h1M8 2v1M7 19h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 19z",
  nube: "M7 19h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 19z",
  niebla: "M5 10h14M3 14h18M6 18h12M7 6h10",
  lluvia: "M7 15h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 15zM8 18l-1 3M12 18l-1 3M16 18l-1 3",
  tormenta: "M7 14h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 14zM12 14l-2 4h4l-2 4",
  nieve: "M7 14h10a4 4 0 0 0 0-8 5 5 0 0 0-9.6 1.5A3.3 3.3 0 0 0 7 14zM9 18v.01M12 20v.01M15 18v.01",
  descargar: "M12 4v12M7 11l5 5 5-5M5 20h14",
  papelera: "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
  insecto: "M10 5.5a2 2 0 1 0 4 0 2 2 0 1 0-4 0M8 11c0-2.5 1.8-3.5 4-3.5s4 1 4 3.5v5c0 2.8-1.8 4.5-4 4.5s-4-1.7-4-4.5zM12 7.5v13M8 11.5L4.5 10M8 14.5H4M8.3 17.5L5 19.5M16 11.5l3.5-1.5M16 14.5h4M15.7 17.5l3.3 2M11 4L9.5 2.3M13 4l1.5-1.7",
  arana: "M10.5 8a1.5 1.5 0 1 0 3 0 1.5 1.5 0 1 0-3 0M9.5 13.5a2.5 3 0 1 0 5 0 2.5 3 0 1 0-5 0M10.6 8.8L6 5 4 6M10.4 10l-5.9-.5L3 11M10 12.5l-5 2-1.5 3M10.2 15l-3.5 3.5-.5 2.5M13.4 8.8L18 5l2 1M13.6 10l5.9-.5L21 11M14 12.5l5 2 1.5 3M13.8 15l3.5 3.5.5 2.5",
  caracol: "M3 19h15.5a2.5 2.5 0 0 0 2.5-2.5M6 19a5.5 5.5 0 1 1 10.8-1.6c0 1.9-1.5 3-3.1 3a2.4 2.4 0 0 1-2.4-2.4c0-1.2.9-2 2-2M3 19c-.6-1.8-.4-3.6.6-5M4 14.5L2.5 11M5 14l.5-3.5",
  cangrejo: "M7 13.5c0-2.5 2.2-4 5-4s5 1.5 5 4-2.2 4-5 4-5-1.5-5-4zM7.3 12L4 8.5l.8-3.5 2.2 2.3M16.7 12L20 8.5 19.2 5 17 7.3M7.5 15.5L4 17.5M8.6 16.8L6.5 20M16.5 15.5l3.5 2M15.4 16.8l2.1 3.2M10.5 9.6L10 7.5M13.5 9.6l.5-2.1",
  ciempies: "M5 4c1.5 2 2.5 4 3.5 6.5S11 15 13 16s4.5 2 6 4M6.3 6.8L4 7.6M7.6 5.6l-.4-2.2M7.8 9.8l-2.4.6M9.6 8.6L10 6.4M10 13l-2.3 1M12 11.5l1.5-1.6M12.6 15.6l-1.6 2M14.4 13.9l2.1-.7M16.5 17.6l-1 2.1M18 16l2.3-.4",
  gusano: "M3 15c2-4 4-4 6 0s4 4 6 0 4-4 6 0M20.5 13.8v.01",
  medusa: "M5 12a7 7 0 0 1 14 0zM7.5 12c0 3-1 5-1 8M10.5 12c0 3 1 5 0 8M13.5 12c0 3-1 5 0 8M16.5 12c0 3 1 5 1 8",
  estrella: "M12 3l2.2 5.6 6 .4-4.6 3.8 1.5 5.8L12 15.4l-5.1 3.2 1.5-5.8L3.8 9l6-.4z",
  esponja: "M7 21V9c0-3 2-5 5-5s5 2 5 5v12zM10 8.5v.01M14 11v.01M10 14v.01M14 17v.01M10 18.5v.01",
};

export function icono(nombre, extra = "") {
  return `<svg class="icono" viewBox="0 0 24 24" aria-hidden="true" ${extra}><path d="${P[nombre] || P.hoja}"></path></svg>`;
}

export const GRUPOS = {
  "Helechos": { icono: "helecho" }, "Plantas con flor": { icono: "hoja" }, "Aves": { icono: "ave" },
  "Reptiles": { icono: "lagarto" }, "Mamíferos": { icono: "pata" }, "Anfibios": { icono: "rana" }, "Peces": { icono: "pez" },
  "Insectos": { icono: "insecto" }, "Arácnidos": { icono: "arana" }, "Moluscos": { icono: "caracol" }, "Crustáceos": { icono: "cangrejo" },
  "Miriápodos": { icono: "ciempies" }, "Anélidos": { icono: "gusano" }, "Cnidarios": { icono: "medusa" }, "Equinodermos": { icono: "estrella" },
  "Esponjas": { icono: "esponja" }, "Otros invertebrados": { icono: "gusano" },
};
// Bloques de grupos para Inicio y filtros
export const BLOQUES = [
  ["Flora", ["Plantas con flor", "Helechos"]],
  ["Vertebrados", ["Aves", "Reptiles", "Mamíferos", "Anfibios", "Peces"]],
  ["Invertebrados", ["Insectos", "Arácnidos", "Moluscos", "Crustáceos", "Miriápodos", "Anélidos", "Cnidarios", "Equinodermos", "Esponjas", "Otros invertebrados"]],
];
export const iconoGrupo = (g) => (GRUPOS[g] || { icono: "hoja" }).icono;

export const ISLAS = [
  ["H", "El Hierro"], ["P", "La Palma"], ["G", "La Gomera"], ["T", "Tenerife"],
  ["C", "Gran Canaria"], ["F", "Fuerteventura"], ["L", "Lanzarote"],
];
export const NOMBRE_ISLA = Object.fromEntries(ISLAS);
export const ABREV = { H: "EH", P: "LP", G: "LG", T: "TF", C: "GC", F: "FV", L: "LZ" };

export const NIVELES = {
  insular: "Exclusivo de una isla", canario: "Endemismo canario", macaronesico: "Endemismo macaronésico",
  nativo: "Nativo no endémico", introducido: "Introducido",
};
export const ORIGENES = {
  NS: "Nativo seguro", NP: "Nativo probable", IP: "Introducido probable", ISI: "Introducido invasor",
  ISN: "Introducido no invasor", ISP: "Introducido potencialmente invasor", ISF: "Introducido con falta de datos",
};

export const UICN = {
  CR: { nombre: "En peligro crítico", color: "#D81E05" }, EN: { nombre: "En peligro", color: "#FC7F3F" },
  VU: { nombre: "Vulnerable", color: "#F9E814" }, NT: { nombre: "Casi amenazada", color: "#CCE226" },
  LC: { nombre: "Preocupación menor", color: "#60C659" }, DD: { nombre: "Datos insuficientes", color: "#D1D1C6" },
  NE: { nombre: "No evaluada", color: "#D1D1C6" }, EX: { nombre: "Extinta", color: "#000000" }, EW: { nombre: "Extinta en estado silvestre", color: "#542344" },
};

export function presencia(is) {
  // "HsPsTd" -> {H:"s", P:"s", T:"d"}
  const out = {};
  for (let i = 0; i < (is || "").length; i += 2) out[is[i]] = is[i + 1];
  return out;
}
export const islasDe = (is) => Object.entries(presencia(is)).filter(([k, v]) => k !== "M" && v !== "d").map(([k]) => k);

export function nombreSci(n, a, conAutor = true) {
  const partes = esc(n).split(" ").map((t) => (/^(subsp\.|var\.|f\.|×)$/.test(t) ? `<span class="rango">${t}</span>` : t)).join(" ");
  return `<span class="sci">${partes}${conAutor && a ? ` <span class="autor">${esc(a)}</span>` : ""}</span>`;
}

export function nombreComun(e) { return (e.cm && e.cm[0]) || e.n; }
export const numero = (no) => `Nº ${String(no || 0).padStart(4, "0")}`;

export function insigniaNivel(nv, pequena = false) {
  return `<span class="insignia ${pequena ? "pequena" : ""} nv-${nv}">${esc(NIVELES[nv] || nv)}</span>`;
}
export function insigniasEntrada(e, pequena = true) {
  const out = [insigniaNivel(e.nv, pequena)];
  if (e.o === "ISI") out.push(`<span class="insignia ${pequena ? "pequena" : ""} invasora">Invasora</span>`);
  if (e.o === "ISP") out.push(`<span class="insignia ${pequena ? "pequena" : ""} invasora">Potencialmente invasora</span>`);
  if (["CR", "EN", "VU"].includes(e.ui)) out.push(`<span class="insignia ${pequena ? "pequena" : ""} uicn-${e.ui}">UICN ${e.ui}</span>`);
  const amen = [...(e.cc || []), ...(e.ce || [])].find((c) => /peligro|vulnerable/i.test(c));
  if (amen) out.push(`<span class="insignia ${pequena ? "pequena" : ""} amenaza">${esc(amen)}</span>`);
  if (e.st === "Extinto") out.push(`<span class="insignia ${pequena ? "pequena" : ""} extinto">Extinto</span>`);
  return out.join("");
}

export const BIOTA = "https://www.biodiversidadcanarias.es/biota";
export const CENTINELA = "https://www.biodiversidadcanarias.es/centinela";
export const urlImagen = (cod, id, mini = false) => `${BIOTA}/especie/${cod}/imagenes/${id}${mini ? "?thumbnails=true" : ""}`;

// Fotos con licencia libre: «c:Archivo.jpg» (Wikimedia Commons) o «i:123/medium.jpg» (iNaturalist)
export function urlLibre(fl, ancho = 960) {
  if (fl.startsWith("c:")) return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(fl.slice(2))}?width=${ancho}`;
  const u = fl.startsWith("i:") ? `https://inaturalist-open-data.s3.amazonaws.com/photos/${fl.slice(2)}` : fl;
  return u.replace(/\/(medium|small)\./, ancho <= 250 ? "/small." : "/medium.");
}

// Foto principal de una entrada del índice según los ajustes: { src, credito } o null
export function fotoPrincipal(e, op, ancho = 960) {
  if (op.biota && e.img) return { src: urlImagen(e.c, e.img, ancho <= 250), credito: "Foto: Biota" };
  if (op.libres && e.fl) return { src: urlLibre(e.fl, ancho), credito: e.fl.startsWith("c:") ? "Foto: Wikimedia Commons" : "Foto: iNaturalist" };
  return null;
}

export function miniatura(e, op, ancho = 120) {
  const ft = fotoPrincipal(e, op || {}, ancho);
  const img = ft ? `<img loading="lazy" alt="" src="${ft.src}" onerror="this.remove()">` : "";
  return `<span class="miniatura">${icono(iconoGrupo(e.g))}${img}</span>`;
}

// Mapa de las islas con su contorno real (OpenStreetMap), coloreado según la presencia
const ETIQUETAS = {
  H: [35, 147, "start", "El Hierro"], P: [46, 66, "start", "La Palma"], G: [77.6, 132, "middle", "La Gomera"],
  T: [127, 71, "middle", "Tenerife"], C: [191.5, 155, "middle", "Gran Canaria"], F: [300, 132, "middle", "Fuerteventura"],
  L: [307, 44, "end", "Lanzarote"],
};
const CLASE_PRES = { s: "presente", d: "dudosa", t: "traslocada", x: "extinta" };

export function mapaIslas(is) {
  const pr = presencia(is);
  const { ancho, alto, islas, km50 } = MAPA;
  const formas = Object.entries(islas).map(([k, ds]) => `<g class="isla ${CLASE_PRES[pr[k]] || "ausente"}">${ds.map((d) => `<path d="${d}"/>`).join("")}</g>`).join("");
  const textos = Object.entries(ETIQUETAS).map(([, [x, y, a, t]]) => `<text x="${x}" y="${y}" text-anchor="${a}">${t}</text>`).join("");
  const xe = ancho - 10 - km50, ye = alto - 9;
  const escala = `<g class="escala"><path d="M${xe},${ye - 3}V${ye}H${xe + km50}V${ye - 3}"/><text x="${xe + km50 / 2}" y="${ye - 5}" text-anchor="middle">50 km</text></g>`;
  const desc = ISLAS.filter(([k]) => pr[k]).map(([k, n]) => `${n}: ${{ s: "presente", d: "dudosa o extinta", t: "traslocada", x: "extinta" }[pr[k]] || pr[k]}`).join("; ");
  return `<svg class="mapa-islas" viewBox="0 0 ${ancho} ${alto}" role="img" aria-label="${esc((desc || "Sin presencia en las islas") + (pr.M ? ". Presente en aguas de Canarias" : ""))}">
    <rect class="mar ${pr.M ? "con-especie" : ""}" x="0" y="0" width="${ancho}" height="${alto}" rx="8"/>${formas}${textos}${escala}</svg>`;
}

export function aviso(texto, ms = 2600) {
  const d = document.createElement("div");
  d.className = "aviso";
  d.setAttribute("role", "status");
  d.textContent = texto;
  document.body.appendChild(d);
  setTimeout(() => d.remove(), ms);
}

export function normalizar(s) {
  return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}
