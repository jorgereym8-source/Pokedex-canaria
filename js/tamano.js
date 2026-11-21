// Diagrama de tamaño: la especie a escala junto a tu silueta (o una mano, si es pequeña).
import { esc } from "./ui.js";

// Cada silueta va en su propia caja (w × h). Las «verticales» se escalan por altura
// (plantas, personas); el resto, por longitud (animales).
const cardon = () => {
  const cols = [[4, 0.45], [18, 0.72], [32, 0.9], [46, 1], [60, 0.82], [74, 0.96], [88, 0.7], [102, 0.86], [116, 0.6], [130, 0.42]];
  return cols.map(([x, h]) => { const y = 100 - h * 100; return `M${x} 100V${y + 6}Q${x} ${y} ${x + 6} ${y}Q${x + 12} ${y} ${x + 12} ${y + 6}V100Z`; }).join("");
};

const SIL = {
  humano: { w: 40, h: 100, v: true, d: "M12 8a8 8 0 1 0 16 0a8 8 0 1 0-16 0zM8 20Q20 17 32 20L38 54 34 55 29 30 29 100 23 100 21 60 19 60 17 100 11 100 11 30 6 55 2 54Z" },
  mano: { w: 50, h: 100, v: true, d: "M10 100L10 52Q8 40 10 34L12 14Q14 10 17 14L18 40 20 6Q22 2 25 6L26 40 28 4Q30 0 33 4L34 42 36 12Q38 8 41 12L42 52 48 40Q52 38 50 44L42 70Q40 84 38 100Z" },
  arbol: { w: 100, h: 110, v: true, d: "M45 110L45 66Q30 68 16 60Q0 50 6 34Q10 16 30 14Q38 2 56 4Q76 2 86 18Q100 30 94 46Q90 62 70 64Q62 66 55 66L55 110Z" },
  palmera: { w: 80, h: 120, v: true, d: "M38 120Q35 80 40 30L44 30Q41 80 44 120ZM42 28Q22 14 0 32Q22 22 41 31ZM42 28Q62 12 80 30Q60 22 43 31ZM42 28Q34 6 14 6Q32 12 41 30ZM42 28Q52 4 72 8Q54 12 43 30ZM42 28Q34 40 16 56Q32 40 41 31ZM42 28Q52 40 68 56Q52 40 43 31Z" },
  arbusto: { w: 120, h: 80, v: true, d: "M4 80Q0 56 16 48Q16 26 40 26Q50 8 72 16Q92 12 100 32Q118 38 116 58Q120 70 116 80Z" },
  hierba: { w: 70, h: 100, v: true, d: "M33 100Q24 62 4 44Q28 58 37 100ZM37 100Q42 56 62 38Q48 62 41 100ZM34 100Q33 50 35 18Q38 50 38 100ZM28 12a7 7 0 1 0 14 0a7 7 0 1 0-14 0Z" },
  roseta: { w: 60, h: 120, v: true, d: "M20 98Q26 50 30 2Q34 50 40 98ZM30 120Q12 116 0 106Q18 104 28 110ZM30 120Q48 116 60 106Q42 104 32 110ZM30 120Q20 108 14 96Q26 102 30 114ZM30 120Q40 108 46 96Q34 102 30 114ZM28 120L28 98L32 98L32 120Z" },
  cactiforme: { w: 146, h: 100, v: true, d: cardon() },
  helecho: { w: 100, h: 80, v: true, d: "M50 80Q30 50 2 44Q30 40 52 76ZM50 80Q70 50 98 44Q70 40 48 76ZM50 80Q36 40 22 8Q46 36 53 78ZM50 80Q64 40 78 8Q54 36 47 78ZM49 80Q50 40 50 0Q52 40 51 80Z" },
  ave: { w: 100, h: 70, d: "M8 40Q20 28 44 26Q58 16 70 14Q84 12 88 22L98 25L88 29Q86 40 76 48Q62 60 40 58Q22 54 14 48L0 46ZM46 57L44 70L47 70L49 57ZM56 56L56 70L59 70L59 56Z" },
  lagarto: { w: 100, h: 24, d: "M0 14Q20 12 40 10Q50 4 62 6L82 6Q96 6 100 10Q96 14 82 14L66 14L70 22L66 22L60 15L46 15L44 22L40 22L40 15Q20 16 0 14ZM72 6L76 0L79 0L77 6ZM48 9L50 2L53 2L52 9Z" },
  serpiente: { w: 100, h: 14, d: "M0 9Q12 0 25 7T50 7T75 7Q86 12 94 6L100 7L94 9Q86 15 75 10T50 10T25 10Q12 4 0 11Z" },
  tortuga: { w: 100, h: 40, d: "M14 32Q16 6 50 4Q84 6 86 32ZM84 24Q94 18 100 24Q96 30 86 30ZM20 32L8 40L28 36ZM72 32L84 40L66 36Z" },
  pez: { w: 100, h: 36, d: "M0 6L16 18L0 30L6 18ZM14 18Q34 0 62 2Q86 4 100 18Q86 32 62 34Q34 36 14 18Z" },
  tiburon: { w: 100, h: 30, d: "M0 2L12 15L4 28L18 17Q40 8 60 8L66 0L72 8Q90 10 100 16Q90 22 70 22L64 28L60 22Q38 24 18 17Z" },
  cetaceo: { w: 100, h: 26, d: "M0 4L8 13L0 22L12 15Q34 6 60 6L64 0L70 7Q88 9 94 13L100 14L94 16Q84 22 60 22Q34 22 12 15Z" },
  murcielago: { w: 100, h: 45, d: "M50 14L46 6L48 14Q40 16 36 24Q24 10 0 14Q10 22 8 34Q18 28 24 36Q30 30 38 34Q44 40 50 42Q56 40 62 34Q70 30 76 36Q82 28 92 34Q90 22 100 14Q76 10 64 24Q60 16 52 14L54 6Z" },
  mamifero: { w: 100, h: 60, d: "M10 20Q8 8 16 6L18 0L22 6Q28 10 26 20Q50 16 76 18Q92 18 96 30L100 38L94 36Q92 40 88 42L88 60L82 60L80 42L36 42L34 60L28 60L26 40Q14 34 10 20Z" },
  rana: { w: 100, h: 60, d: "M20 60Q2 56 10 44Q14 30 30 24Q32 10 44 12Q50 4 58 12Q72 10 72 24Q90 30 92 44Q98 56 80 60Q72 50 64 54L58 60L42 60L36 54Q28 50 20 60Z" },
};
const ALIAS = { "árbol": "arbol", trepadora: "arbusto", planta: "arbusto", raya: "pez" };

export function medida(m) {
  if (m == null) return "";
  if (m >= 1) return `${(Math.round(m * 10) / 10).toLocaleString("es")} m`;
  if (m >= 0.01) return `${Math.round(m * 100)} cm`;
  return `${Math.round(m * 1000)} mm`;
}

export function textoTamano(t) {
  if (!t) return "";
  let rango = `hasta ${medida(t.max)}`;
  if (t.min) {
    const [a, b] = [medida(t.min), medida(t.max)];
    const ua = a.split(" ")[1], ub = b.split(" ")[1];
    rango = ua === ub ? `${a.split(" ")[0]}–${b}` : `${a}–${b}`;
  }
  return `${rango.charAt(0).toUpperCase()}${rango.slice(1)}`;
}

function barraEscala(escala) {
  const opciones = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20];
  return opciones.find((l) => l * escala >= 36) || 20;
}

// Etiqueta centrada que no se sale por los bordes del dibujo
function etiqueta(x, y, texto, tam, peso, color, W) {
  const mitad = texto.length * tam * 0.29;
  let ancla = "middle", xx = x;
  if (x - mitad < 4) { ancla = "start"; xx = 4; } else if (x + mitad > W - 4) { ancla = "end"; xx = W - 4; }
  return `<text x="${xx}" y="${y}" text-anchor="${ancla}" font-size="${tam}" font-weight="${peso}" fill="${color}">${esc(texto)}</text>`;
}

export function diagrama(forma, tam, alturaCm = 180) {
  if (!tam?.max) return "";
  const sil = SIL[ALIAS[forma] || forma] || SIL.arbusto;
  const t = tam.max;
  const [ancho, alto] = sil.v ? [t * sil.w / sil.h, t] : [t, t * sil.h / sil.w];
  const conMano = t < 0.3;
  const ref = conMano ? SIL.mano : SIL.humano;
  const refAlto = conMano ? 0.19 : alturaCm / 100;
  const refAncho = refAlto * ref.w / ref.h;

  const W = 340, suelo = 196, izq = 18, der = 18, arriba = 34;
  const hueco = Math.max(refAncho, ancho) * 0.3;
  const escala = Math.min((W - izq - der) / (refAncho + hueco + ancho), (suelo - arriba) / Math.max(refAlto, alto));
  const xRef = izq + ((W - izq - der) - (refAncho + hueco + ancho) * escala) / 2;
  const xEsp = xRef + (refAncho + hueco) * escala;
  const kRef = (refAncho * escala) / ref.w, kEsp = (ancho * escala) / sil.w;
  const hRef = refAlto * escala, hEsp = alto * escala;
  const barra = barraEscala(escala);
  const etRef = conMano ? `Mano · ${medida(refAlto)}` : `Tú · ${medida(refAlto)}`;
  const etEsp = textoTamano(tam);

  return `<svg viewBox="0 0 ${W} 230" role="img" aria-label="${esc(`Comparación de tamaño: ${etEsp} frente a ${etRef}`)}">
    <line x1="6" y1="${suelo}" x2="${W - 6}" y2="${suelo}" stroke="var(--borde)" stroke-width="1.5"/>
    <g transform="translate(${xRef} ${suelo - hRef}) scale(${kRef})" fill="var(--texto)" opacity="0.85"><path d="${ref.d}"/></g>
    <g transform="translate(${xEsp} ${suelo - hEsp}) scale(${kEsp})" fill="var(--acento)"><path d="${sil.d}"/></g>
    ${etiqueta(xRef + (refAncho * escala) / 2, suelo - hRef - 8, etRef, 11, 600, "var(--texto)", W)}
    ${etiqueta(xEsp + (ancho * escala) / 2, Math.max(14, suelo - hEsp - 8), etEsp, 12, 700, "var(--acento)", W)}
    <line x1="${W - 18 - barra * escala}" y1="216" x2="${W - 18}" y2="216" stroke="var(--texto-2)" stroke-width="2"/>
    <line x1="${W - 18 - barra * escala}" y1="211" x2="${W - 18 - barra * escala}" y2="221" stroke="var(--texto-2)" stroke-width="1.5"/>
    <line x1="${W - 18}" y1="211" x2="${W - 18}" y2="221" stroke="var(--texto-2)" stroke-width="1.5"/>
    <text x="${W - 18 - (barra * escala) / 2}" y="208" text-anchor="middle" font-size="10" fill="var(--texto-2)">${medida(barra)}</text>
  </svg>`;
}
