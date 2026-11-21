// Datos de especies: índice, fichas, búsqueda y filtros.
import { normalizar, islasDe } from "./ui.js";

let indice = null;
let meta = null;
const fichas = new Map();

export async function cargarIndice() {
  if (indice) return indice;
  const [ri, rm] = await Promise.all([fetch("datos/indice.json"), fetch("datos/meta.json")]);
  if (!ri.ok) throw new Error("No se pudo cargar el índice de especies");
  indice = await ri.json();
  meta = rm.ok ? await rm.json() : null;
  for (const e of indice) {
    e._b = normalizar([e.n, e.cm.join(" "), e.fa, e.c, e.cl].join(" "));
    e._islas = islasDe(e.is);
  }
  return indice;
}
export const getIndice = () => indice || [];
export const getMeta = () => meta;
export const porCodigo = (c) => getIndice().find((e) => e.c === c);

export async function cargarFicha(codigo) {
  if (fichas.has(codigo)) return fichas.get(codigo);
  const r = await fetch(`datos/fichas/${codigo}.json`);
  if (!r.ok) throw new Error("No se pudo cargar la ficha");
  const f = await r.json();
  fichas.set(codigo, f);
  return f;
}

// ---------------------------------------------------------------- filtros

export const FILTROS = {
  g: { titulo: "Grupo", valores: ["Plantas con flor", "Helechos", "Aves", "Reptiles", "Mamíferos", "Anfibios", "Peces"] },
  i: { titulo: "Isla", valores: ["L", "F", "C", "T", "G", "P", "H"] },
  nv: { titulo: "Endemicidad y origen", valores: ["insular", "canario", "macaronesico", "nativo", "introducido"] },
  inv: { titulo: "Invasoras", valores: ["si"] },
  cc: { titulo: "Catálogo Canario de Especies Protegidas", valores: ["En peligro de extinción", "Vulnerable", "Interés para los ecosistemas canarios", "Protección especial"] },
  ce: { titulo: "Catálogo Español", valores: ["En peligro de extinción", "Vulnerable", "Régimen de protección especial"] },
  md: { titulo: "Medio", valores: ["Terrestre", "Marino"] },
  hb: { titulo: "Hábitat", valores: [] }, // se rellena con los más frecuentes
  foto: { titulo: "Fotografía", valores: ["si"] },
  ext: { titulo: "Extinguidas", valores: ["ocultar"] },
};

export function habitatsFrecuentes(n = 14) {
  const cuenta = new Map();
  for (const e of getIndice()) for (const h of e.hb || []) cuenta.set(h, (cuenta.get(h) || 0) + 1);
  return [...cuenta.entries()].sort((a, b) => b[1] - a[1]).slice(0, n).map(([h]) => h);
}

// f: { q, g:[], i:[], nv:[], cc:[], ce:[], md:[], hb:[], inv:bool, foto:bool, novistas:bool }
export function filtrar(f, vistas = new Set(), orden = "no") {
  const q = normalizar(f.q || "").trim();
  const palabras = q ? q.split(/\s+/) : [];
  const res = getIndice().filter((e) => {
    if (palabras.length && !palabras.every((p) => e._b.includes(p))) return false;
    if (f.g?.length && !f.g.includes(e.g)) return false;
    if (f.i?.length && !f.i.some((i) => e._islas.includes(i))) return false;
    if (f.nv?.length && !f.nv.includes(e.nv)) return false;
    if (f.ui?.length && !f.ui.includes(e.ui)) return false;
    if (f.inv && e.o !== "ISI") return false;
    if (f.cc?.length && !f.cc.some((c) => (e.cc || []).includes(c))) return false;
    if (f.ce?.length && !f.ce.some((c) => (e.ce || []).includes(c))) return false;
    if (f.md?.length && !f.md.includes(e.md)) return false;
    if (f.hb?.length && !f.hb.some((h) => (e.hb || []).includes(h))) return false;
    if (f.foto && !e.img && !e.fl) return false;
    if (f.novistas && vistas.has(e.c)) return false;
    if (f.ext && e.st === "Extinto") return false;
    return true;
  });
  if (orden === "az") res.sort((a, b) => (a.cm[0] || a.n).localeCompare(b.cm[0] || b.n, "es"));
  else if (orden === "sci") res.sort((a, b) => a.n.localeCompare(b.n));
  else res.sort((a, b) => a.no - b.no);
  return res;
}

export function cuantosFiltros(f) {
  return ["g", "i", "nv", "ui", "cc", "ce", "md", "hb"].reduce((n, k) => n + (f[k]?.length || 0), 0) + (f.inv ? 1 : 0) + (f.foto ? 1 : 0) + (f.novistas ? 1 : 0) + (f.ext ? 1 : 0);
}

export function cuentaPorGrupo() {
  const c = {};
  for (const e of getIndice()) c[e.g] = (c[e.g] || 0) + 1;
  return c;
}

// Especie del día: misma para todo el día, elegida entre las que tienen foto
export function especieDelDia() {
  const con = getIndice().filter((e) => e.img && e.nv !== "introducido" && e.st !== "Extinto");
  const lista = con.length ? con : getIndice();
  if (!lista.length) return null;
  const d = new Date();
  const semilla = d.getFullYear() * 1000 + Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 864e5);
  return lista[(semilla * 2654435761) % lista.length];
}
