// Pokédex Canaria — navegación y pantallas.
import * as A from "./ajustes.js";
import * as D from "./datos.js";
import * as V from "./avistamientos.js";
import { diagrama, textoTamano, medida } from "./tamano.js";
import {
  esc, icono, iconoGrupo, ISLAS, NOMBRE_ISLA, NIVELES, ORIGENES, nombreSci, nombreComun, numero, insigniaNivel,
  insigniasEntrada, urlImagen, urlLibre, fotoPrincipal, miniatura, BLOQUES, mapaIslas, aviso, BIOTA, CENTINELA, islasDe, presencia, UICN,
} from "./ui.js";

const VERSION = "0.5.0";
const vista = document.getElementById("vista");
const hojas = document.getElementById("hojas");
const FILTROS_VACIOS = () => ({ g: [], i: [], nv: [], ui: [], cc: [], ce: [], md: [], hb: [], inv: false, foto: false, son: false, novistas: false, ext: false, am: false, pr: false });
const ISLAS_ORDEN = ["T", "C", "P", "G", "H", "F", "L"];
const SIGLA_ISLA = { H: "EH", P: "LP", G: "LG", T: "TF", C: "GC", F: "FV", L: "LZ" };
const estado = { filtros: FILTROS_VACIOS(), q: "", orden: null, limite: 60, vistas: new Set(), modoVistas: "lista", abierto: null };
const MESES = ["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
const MESES_LARGOS = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const REDEXOS = "https://www.gobiernodecanarias.org/medioambiente/materias/biodiversidad/especies-exoticas-invasoras/";

// ------------------------------------------------------------------ arranque

A.aplicar();
iniciar();

async function iniciar() {
  window.addEventListener("hashchange", render);
  document.addEventListener("click", alPulsar);
  try {
    await D.cargarIndice();
  } catch (e) {
    vista.innerHTML = `<div class="vacio">${icono("alerta")}<p>No se han podido cargar los datos de especies.</p><p class="pequeno">${esc(e.message)}</p></div>`;
    return;
  }
  estado.vistas = await V.vistas().catch(() => new Set());
  render();
  V.completarPendientes().then((n) => { if (n) aviso("Se ha completado el tiempo de avistamientos guardados sin conexión"); }).catch(() => {});
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
}

function ruta() {
  const h = location.hash.slice(1) || "/";
  const [camino, qs] = h.split("?");
  return { partes: camino.split("/").filter(Boolean), qs: new URLSearchParams(qs || "") };
}

async function render() {
  const { partes } = ruta();
  const pagina = partes[0] || "inicio";
  document.querySelectorAll(".pestanas a").forEach((a) => a.classList.toggle("activa", a.dataset.pagina === (pagina === "especie" ? "explorar" : pagina)));
  vista.classList.toggle("sin-relleno-arriba", pagina === "especie" && A.get("estilo") !== "poke");
  cerrarHojas();
  if (pagina !== "explorar") estado.limite = 60;
  try {
    if (pagina === "inicio") return vistaInicio();
    if (pagina === "explorar") return vistaExplorar();
    if (pagina === "especie") return vistaFicha(partes[1]);
    if (pagina === "vistas") return vistaAvistamientos();
    if (pagina === "mapa") return vistaMapa();
    if (pagina === "ajustes") return vistaAjustes();
    location.hash = "#/";
  } catch (e) {
    vista.innerHTML = `<div class="vacio">${icono("alerta")}<p>${esc(e.message)}</p></div>`;
  } finally {
    if (pagina !== "explorar" || !estado.mantenerScroll) window.scrollTo(0, 0);
    estado.mantenerScroll = false;
  }
}

const ordenActual = () => estado.orden || { "Taxonómica": "no", "Nombre común": "az", "Nombre científico": "sci" }[A.get("numeracion")] || "no";

// ------------------------------------------------------------------- inicio

function vistaInicio() {
  const indice = D.getIndice();
  const meta = D.getMeta();
  const cuenta = D.cuentaPorGrupo();
  const dia = D.especieDelDia();
  const vistasN = indice.filter((e) => estado.vistas.has(e.c)).length;
  const fotoDia = dia ? fotoPrincipal(dia, opFotos(), 960) : null;
  const progIslas = D.progresoIslas(estado.vistas);
  const bloques = BLOQUES.map(([t, gs]) => [t, gs.filter((g) => cuenta[g])]).filter(([, gs]) => gs.length);
  const amenazadas = indice.filter(esAmenazada).length;

  vista.innerHTML = `
    <div class="cabecera">
      <div class="marca-app"><img src="iconos/logo.png" alt="" width="60" height="60"><div class="titulos"><span class="sobre">Pokédex Canaria</span><h1>Flora y fauna<br>de Canarias</h1></div></div>
      <a class="boton-icono" href="#/ajustes" aria-label="Ajustes">${icono("ajustes")}</a>
    </div>
    <form class="buscador" data-accion="buscar-inicio" role="search">
      ${icono("buscar")}
      <input type="search" name="q" aria-label="Buscar especie" placeholder="Nombre científico o común" autocomplete="off" enterkeyhint="search">
    </form>
    ${dia ? `
    <a class="tarjeta destacada" href="#/especie/${dia.c}">
      <div class="foto">${icono(iconoGrupo(dia.g))}${fotoDia ? `<img alt="" src="${fotoDia.src}" onerror="this.parentNode.querySelector('.credito')?.remove();this.remove()">` : ""}
        <span class="etiqueta-foto">Especie del día</span>${fotoDia ? `<span class="credito">${fotoDia.credito}</span>` : ""}</div>
      <div class="cuerpo">
        <span class="numero">${numero(dia.no)} · ${esc(dia.fa || dia.g)}</span>
        <span class="nombre-comun">${esc(nombreComun(dia))}</span>
        ${nombreSci(dia.n, dia.a, A.get("autoria"))}
        <div class="insignias" style="margin-top:4px">${insigniasEntrada(dia, false)}</div>
      </div>
    </a>` : ""}
    <div class="tarjeta relleno">
      <div class="titulo-seccion"><h2>Tu Pokédex</h2><a href="#/vistas">Avistamientos</a></div>
      <div class="pequeno texto-2">Has visto <b>${vistasN}</b> de ${indice.length.toLocaleString("es")} especies y subespecies</div>
      <div class="progreso"><i style="width:${indice.length ? Math.max(vistasN ? 1 : 0, (vistasN / indice.length) * 100) : 0}%"></i></div>
    </div>
    ${bloques.map(([t, gs], i) => `<section class="grupo-ajustes">
      <div class="titulo-seccion"><h2>${esc(t)}</h2>${i === 0 ? `<a href="#/explorar" data-explorar='{}'>Ver todo</a>` : `<a href="#/explorar" data-explorar='${JSON.stringify({ g: gs })}'>Ver ${gs.reduce((n, g) => n + cuenta[g], 0).toLocaleString("es")}</a>`}</div>
      <div class="rejilla">
        ${gs.map((g) => `<a class="tile" href="#/explorar" data-explorar='${JSON.stringify({ g: [g] })}'>
          <span class="burbuja">${icono(iconoGrupo(g))}</span><span class="nombre">${esc(g)}</span><span class="cuenta">${cuenta[g].toLocaleString("es")}</span></a>`).join("")}
      </div>
    </section>`).join("")}
    <section class="grupo-ajustes">
      <div class="titulo-seccion"><h2>Pokédex por isla</h2></div>
      <div class="rejilla-2">
        ${ISLAS_ORDEN.map((k) => { const p = progIslas[k]; return `<a class="tile isla-prog" href="#/explorar" data-explorar='${JSON.stringify({ i: [k] })}'>
          <span class="nombre">${esc(NOMBRE_ISLA[k])}</span><span class="cuenta"><b>${p.vistas.toLocaleString("es")}</b> de ${p.total.toLocaleString("es")} vistas</span>
          <span class="progreso"><i style="width:${p.total ? Math.max(p.vistas ? 2 : 0, (p.vistas / p.total) * 100) : 0}%"></i></span></a>`; }).join("")}
      </div>
    </section>
    <section class="grupo-ajustes">
      <div class="titulo-seccion"><h2>Atajos</h2></div>
      <div class="lista">
        ${atajo("alerta", "Amenazadas", `${amenazadas} en peligro de extinción o vulnerables`, { am: true })}
        ${atajo("pin", "Exclusivas de una isla", "Endemismos insulares", { nv: ["insular"] })}
        ${atajo("hoja", "Endemismos canarios", "Solo viven en Canarias", { nv: ["insular", "canario"] })}
        ${atajo("escudo", "Exóticas invasoras", "Con enlace a REDEXOS", { inv: true })}
        ${atajo("flor", "Protegidas", "Con ficha en Centinela", { pr: true })}
      </div>
    </section>
    ${meta ? `<p class="pequeno texto-2 pie" style="text-align:center;margin:0">Datos de Biota y Centinela · actualizados el ${new Date(meta.actualizado).toLocaleDateString("es")}</p>` : ""}
  `;
}

function atajo(ic, t, s, filtros) {
  return `<a class="fila" href="#/explorar" data-explorar='${JSON.stringify(filtros)}'>${icono(ic)}
    <span class="cuerpo"><span class="principal" style="font-weight:600">${esc(t)}</span><span class="secundario">${esc(s)}</span></span>${icono("flecha", 'class="icono flecha"')}</a>`;
}

function esAmenazada(e) {
  return ["CR", "EN", "VU"].includes(e.ui) || [...(e.cc || []), ...(e.ce || [])].some((c) => /peligro|vulnerable/i.test(c));
}

// ----------------------------------------------------------------- explorar

function filtrosConExtras() {
  const f = { ...estado.filtros, q: estado.q };
  return f;
}

function resultados() {
  let r = D.filtrar(filtrosConExtras(), estado.vistas, ordenActual());
  if (estado.filtros.am) r = r.filter(esAmenazada);
  if (estado.filtros.pr) r = r.filter((e) => e.pr);
  return r;
}

function vistaExplorar() {
  const n = D.cuantosFiltros(estado.filtros) + (estado.filtros.am ? 1 : 0) + (estado.filtros.pr ? 1 : 0);
  vista.innerHTML = `
    <div class="cabecera"><div class="titulos"><h1>Explorar</h1></div><span class="pequeno texto-2" id="total" style="align-self:flex-end"></span></div>
    <label class="buscador">${icono("buscar")}<input type="search" id="q" aria-label="Buscar especie" placeholder="Nombre científico, común, familia o código" value="${esc(estado.q)}" autocomplete="off" enterkeyhint="search"></label>
    <div class="carril">
      <button class="chip oscuro" data-accion="filtros">${icono("filtro")} Filtros${n ? ` · ${n}` : ""}</button>
      ${chipsActivos()}
    </div>
    <div class="titulo-seccion">
      <label class="pequeno texto-2">Orden:
        <select id="orden" style="font:inherit;font-weight:600;border:0;background:transparent;color:var(--texto)">
          ${[["no", "Nº Pokédex"], ["az", "Nombre común"], ["sci", "Nombre científico"]].map(([v, t]) => `<option value="${v}" ${ordenActual() === v ? "selected" : ""}>${t}</option>`).join("")}
        </select></label>
    </div>
    <div class="lista" id="resultados"></div>
  `;
  pintarResultados();
  const q = document.getElementById("q");
  let t;
  q.addEventListener("input", () => { clearTimeout(t); t = setTimeout(() => { estado.q = q.value; estado.limite = 60; pintarResultados(); }, 160); });
  document.getElementById("orden").addEventListener("change", (ev) => { estado.orden = ev.target.value; estado.limite = 60; pintarResultados(); });
}

function chipsActivos() {
  const f = estado.filtros;
  const chips = [];
  const add = (k, v, t) => chips.push(`<button class="chip activo" data-quitar='${JSON.stringify([k, v])}' aria-label="Quitar filtro ${esc(t)}">${esc(t)} <span class="x">${icono("cerrar")}</span></button>`);
  f.g.forEach((v) => add("g", v, v));
  f.i.forEach((v) => add("i", v, NOMBRE_ISLA[v]));
  f.nv.forEach((v) => add("nv", v, NIVELES[v]));
  f.cc.forEach((v) => add("cc", v, `C. Canario: ${v}`));
  f.ce.forEach((v) => add("ce", v, `C. Español: ${v}`));
  f.md.forEach((v) => add("md", v, v));
  f.hb.forEach((v) => add("hb", v, v));
  (f.ui || []).forEach((v) => add("ui", v, `UICN: ${UICN[v]?.nombre || v}`));
  if (f.inv) add("inv", true, "Invasoras");
  if (f.am) add("am", true, "Amenazadas");
  if (f.pr) add("pr", true, "Protegidas");
  if (f.foto) add("foto", true, "Con foto");
  if (f.son) add("son", true, "Con sonido");
  if (f.novistas) add("novistas", true, "No vistas");
  if (f.ext) add("ext", true, "Sin extinguidas");
  return chips.join("");
}

function pintarResultados() {
  const caja = document.getElementById("resultados");
  if (!caja) return;
  const r = resultados();
  document.getElementById("total").textContent = `${r.length.toLocaleString("es")} ${r.length === 1 ? "especie" : "especies"}`;
  if (!r.length) {
    caja.outerHTML = `<div class="vacio" id="resultados">${icono("buscar")}<p>No hay especies con esa búsqueda o esos filtros.</p></div>`;
    return;
  }
  const fotos = opFotos();
  caja.innerHTML = r.slice(0, estado.limite).map((e) => filaEspecie(e, fotos)).join("") + (r.length > estado.limite ? '<div class="mas-resultados" id="mas"></div>' : "");
  const mas = document.getElementById("mas");
  if (mas) {
    const obs = new IntersectionObserver((ents) => {
      if (ents.some((x) => x.isIntersecting)) { obs.disconnect(); estado.limite += 80; pintarResultados(); }
    }, { rootMargin: "600px" });
    obs.observe(mas);
  }
}

function filaEspecie(e, fotos) {
  const visto = estado.vistas.has(e.c);
  return `<a class="fila" href="#/especie/${e.c}">
    ${miniatura(e, fotos)}
    <span class="cuerpo">
      <span class="numero">${estado.filtros.i.length === 1 && e._reg?.[estado.filtros.i[0]] ? `${SIGLA_ISLA[estado.filtros.i[0]]} ${String(e._reg[estado.filtros.i[0]]).padStart(4, "0")}` : numero(e.no)}</span>
      <span class="principal">${esc(nombreComun(e))}</span>
      <span class="secundario">${nombreSci(e.n, e.a, A.get("autoria"))}</span>
      <span class="insignias" style="margin-top:3px">${insigniasEntrada(e)}</span>
    </span>
    <span class="marca-vista ${visto ? "si" : ""}">${visto ? icono("check", 'role="img" aria-label="Vista"') : '<span class="oculto-visual">No vista</span>'}</span>
  </a>`;
}

function abrirFiltros() {
  const borrador = structuredClone(estado.filtros);
  const hab = D.habitatsFrecuentes();
  const secciones = [
    ["g", "Grupo", D.FILTROS.g.valores.map((v) => [v, v])],
    ["i", "Isla", ISLAS.slice().reverse().map(([k, n]) => [k, n])],
    ["nv", "Endemicidad y origen", Object.entries(NIVELES)],
    ["ui", "Categoría UICN (mundial)", Object.entries(UICN).filter(([k]) => !["EX", "EW"].includes(k)).map(([k, u]) => [k, `${u.nombre} (${k})`])],
    ["cc", "Catálogo Canario de Especies Protegidas", D.FILTROS.cc.valores.map((v) => [v, v])],
    ["ce", "Catálogo Español", D.FILTROS.ce.valores.map((v) => [v, v])],
    ["md", "Medio", [["Terrestre", "Terrestre"], ["Marino", "Marino"]]],
    ["hb", "Hábitat (los más frecuentes)", hab.map((v) => [v, v])],
  ];
  const interruptores = [["inv", "Solo exóticas invasoras"], ["am", "Solo amenazadas"], ["foto", "Solo con fotografía"], ["son", "Solo con canto o sonido"], ["novistas", "Ocultar las que ya he visto"], ["ext", "Ocultar extinguidas"]];

  const pintar = () => {
    const n = D.filtrar({ ...borrador, q: estado.q }, estado.vistas).filter((e) => (!borrador.am || esAmenazada(e)) && (!borrador.pr || e.pr)).length;
    panel.innerHTML = `
      <span class="asa"></span>
      <div class="barra-hoja"><button data-h="cerrar">Cancelar</button><h2>Filtros</h2><button data-h="limpiar">Limpiar</button></div>
      ${secciones.map(([k, t, vals]) => `<fieldset><legend>${esc(t)}</legend><div class="chips">
        ${vals.map(([v, et]) => `<button class="chip ${borrador[k].includes(v) ? "activo" : ""}" aria-pressed="${borrador[k].includes(v)}" data-h="chip" data-k="${k}" data-v="${esc(v)}">${esc(et)}</button>`).join("")}
      </div></fieldset>`).join("")}
      <div class="ajustes-lista">${interruptores.map(([k, t]) => `<div class="ajuste" style="cursor:default"><span class="etq"><span>${t}</span></span>
        <button class="interruptor" aria-pressed="${!!borrador[k]}" aria-label="${t}" data-h="int" data-k="${k}"><span></span></button></div>`).join("")}</div>
      <button class="boton" data-h="aplicar">Ver ${n.toLocaleString("es")} ${n === 1 ? "especie" : "especies"}</button>`;
  };
  const { panel } = abrirHoja();
  panel.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-h]");
    if (!b) return;
    const k = b.dataset.k;
    if (b.dataset.h === "cerrar") return cerrarHojas();
    if (b.dataset.h === "limpiar") Object.assign(borrador, FILTROS_VACIOS());
    if (b.dataset.h === "chip") { const v = b.dataset.v; borrador[k] = borrador[k].includes(v) ? borrador[k].filter((x) => x !== v) : [...borrador[k], v]; }
    if (b.dataset.h === "int") borrador[k] = !borrador[k];
    if (b.dataset.h === "aplicar") { estado.filtros = borrador; estado.limite = 60; cerrarHojas(); return vistaExplorar(); }
    const y = panel.scrollTop; pintar(); panel.scrollTop = y;
  });
  pintar();
}

// --------------------------------------------------------------------- ficha

async function vistaFicha(codigo) {
  const e = D.porCodigo(codigo);
  if (!e) { vista.innerHTML = `<div class="vacio">${icono("alerta")}<p>No encuentro esa especie.</p></div>`; return; }
  vista.innerHTML = '<div class="cargando">Cargando ficha…</div>';
  let f;
  try { f = await D.cargarFicha(codigo); } catch (err) {
    vista.innerHTML = `<div class="vacio">${icono("alerta")}<p>No se ha podido cargar la ficha. ¿Tienes conexión?</p></div>`; return;
  }
  const avs = await V.deEspecie(codigo);
  const fotos = [
    ...(A.get("fotosBiota") ? (f.imagenes || []).map((im) => ({ src: urlImagen(codigo, im.id), pie: `Foto: ${im.credito || "Biota"} · Biota` })) : []),
    ...(A.get("fotosLibres") ? (f.fotosLibres || []).map((x) => ({
      src: x.fuente === "Wikimedia Commons" ? urlLibre(`c:${x.archivo}`, 960) : urlLibre(x.url, 960),
      pie: `${x.nivel === "especie" ? `Foto de ${x.taxon} · ` : x.nivel === "sinonimo" ? `Como ${x.taxon} en iNaturalist · ` : ""}${x.autor} · ${x.lic} · ${x.fuente === "Wikimedia Commons" ? "Commons" : "iNaturalist"}`,
      enlace: x.pagina,
    })) : []),
  ].slice(0, 10);
  const hayFotos = (f.imagenes || []).length + (f.fotosLibres || []).length;
  const cent = f.centinela?.secciones || {};
  const islas = islasDe(e.is);
  const otrosNombres = A.get("nombres") === "Todos" ? e.cm.slice(1) : [];
  const orig = f.origen?.codigo || e.o;

  vista.innerHTML = `
    <div class="heroe">
      <div class="sin-foto" style="position:absolute">${icono(iconoGrupo(e.g))}<span>${fotos.length ? "" : hayFotos ? "Fotos desactivadas en Ajustes" : "Sin fotos"}</span>
        ${!fotos.length && f.evc ? `<a class="boton-evc" href="${esc(f.evc.url)}" target="_blank" rel="noopener">Ver fotos en Especies Vegetales en Canarias ›</a>` : ""}</div>
      ${fotos.length ? `<div class="pista" id="pista" style="position:relative">${fotos.map((im, i) => `<figure>
        <img ${i ? 'loading="lazy"' : ""} alt="${esc(nombreComun(e))}, foto ${i + 1}" src="${esc(im.src)}" onerror="const p=this.closest('.pista'),c=document.getElementById('contador');this.closest('figure').remove();if(c){if(p.children.length)c.textContent='1 / '+p.children.length;else c.remove();}">
        ${im.enlace ? `<figcaption><a href="${esc(im.enlace)}" target="_blank" rel="noopener">${esc(im.pie)}</a></figcaption>` : `<figcaption>${esc(im.pie)}</figcaption>`}</figure>`).join("")}</div>
        <span class="contador" id="contador">1 / ${fotos.length}</span>` : ""}
      <div class="controles">
        <button class="boton-icono" data-accion="atras" aria-label="Volver">${icono("atras")}</button>
        <button class="boton-icono" data-accion="compartir" aria-label="Compartir">${icono("compartir")}</button>
      </div>
    </div>

    <div class="ficha-titulo">
      <div class="fila-sup">
        <span class="ruta"><span class="num">${numero(e.no)}</span>${esc(f.taxonomia?.Familia || e.fa || e.g)}</span>
        <button class="boton-vista ${avs.length ? "" : "no"}" data-accion="avistar" data-c="${codigo}">${icono(avs.length ? "check" : "vistas")} ${avs.length ? `Vista${avs.length > 1 ? ` · ${avs.length}` : ""}` : "La he visto"}</button>
      </div>
      <h1 class="nombre-comun-ficha">${esc(nombreComun(e))}</h1>
      <p class="nombre-cientifico">${nombreSci(f.nombre || e.n, f.autor || e.a, A.get("autoria"))}</p>
      ${otrosNombres.length ? `<p class="pequeno" style="margin:0">Otros nombres: ${esc(otrosNombres.join(" · "))}</p>` : ""}
      <p class="pequeno texto-2" style="margin:0">Código Biota ${esc(codigo)} · ${esc(f.validez || "")}${f.status === "Extinto" ? " · Extinto" : ""}</p>
      ${f.fichaPendiente ? '<p class="pequeno" style="margin:0;color:var(--acento)">Ficha completa de Biota en camino: se está descargando en las actualizaciones automáticas.</p>' : ""}
      ${Object.keys(e._reg || {}).length ? `<p class="pequeno texto-2" style="margin:0">Pokédex regional: ${ISLAS_ORDEN.filter((k) => e._reg[k]).map((k) => `${SIGLA_ISLA[k]} ${String(e._reg[k]).padStart(4, "0")}`).join(" · ")}</p>` : ""}
    </div>

    <div class="insignias">
      ${insigniaNivel(e.nv)}
      ${f.uicn ? `<span class="insignia uicn-${esc(f.uicn.codigo)}">UICN · ${esc(f.uicn.categoria)} (${esc(f.uicn.codigo)})</span>` : ""}
      <span class="insignia">${esc(f.origen?.nombre || ORIGENES[orig] || orig)}${orig ? ` (${esc(orig)})` : ""}</span>
      ${orig === "ISI" ? '<span class="insignia invasora">Invasora</span>' : orig === "ISP" ? '<span class="insignia invasora">Potencialmente invasora</span>' : ""}
      ${[...new Set([...(e.cc || []).map((c) => `C. Canario: ${c}`), ...(e.ce || []).map((c) => `C. Español: ${c}`)])].map((c) => `<span class="insignia ${/peligro|vulnerable/i.test(c) ? "amenaza" : ""}">${esc(c)}</span>`).join("")}
    </div>

    <div class="hechos">
      ${hecho("pin", "Islas", `${islas.length} de 7`, islas.map((k) => ({ H: "EH", P: "LP", G: "LG", T: "TF", C: "GC", F: "FV", L: "LZ" }[k])).join(" · ") || "—")}
      ${hecho(iconoGrupo(e.g), "Grupo", e.g, e.sg || f.clase || "")}
      ${f.tamano ? hecho("regla", f.tamano.tipo.charAt(0).toUpperCase() + f.tamano.tipo.slice(1), textoTamano(f.tamano), f.tamano.fuente) : hecho("montana", "Medio", f.medio || e.md, f.taxonomia?.Clase || "")}
      ${f.longevidad ? hecho("reloj", "Longevidad", `${(Math.round(f.longevidad.anos * 10) / 10).toLocaleString("es")} años`, [f.longevidad.tipo, f.longevidad.origen].filter(Boolean).join(", "))
        : f.ciclo ? hecho("reloj", "Ciclo de vida", f.ciclo.valor.replace(/ \(.*\)/, ""), f.ciclo.fuente)
        : f.peso ? hecho("regla", "Peso", pesoTexto(f.peso.kg), f.peso.fuente)
        : hecho("camara", "Fotos", String(hayFotos), avs.length ? `${avs.length} avistamiento${avs.length > 1 ? "s" : ""} tuyo${avs.length > 1 ? "s" : ""}` : "Aún no la has visto")}
    </div>

    ${seccionTamano(f, e)}

    ${seccionBiologia(f)}

    ${seccionSonidos(f)}

    <section class="seccion">
      <h2>Distribución</h2>
      ${mapaIslas(e.is)}
      <div class="leyenda"><span><i style="background:var(--acento)"></i>Presente</span><span><i style="background:var(--acento-suave);border:1px dashed var(--acento)"></i>Dudosa</span>
        <span><i style="background:#EBC27A"></i>Traslocada</span><span><i style="background:#9AA097"></i>Extinta</span><span><i style="border:1.5px solid #9AA097"></i>Sin citas</span>${presencia(e.is).M ? '<span><i class="mar-leyenda"></i>En aguas de Canarias</span>' : ""}</div>
      <span class="fuente-dato">Contorno de las islas: © OpenStreetMap. Los islotes se colorean con su isla (La Graciosa, Alegranza y Montaña Clara con Lanzarote; Lobos con Fuerteventura).</span>
      ${cent["Distribución mundial"] ? `<p><b>Mundial:</b> ${esc(cent["Distribución mundial"])}</p>` : ""}
      ${cent["Distribución en Canarias"] ? `<p><b>En Canarias:</b> ${esc(cent["Distribución en Canarias"])}</p>` : ""}
      ${f.mapaPk ? `<img class="mapa-oficial" loading="lazy" alt="Mapa de distribución de Biota en cuadrículas" src="${BIOTA}/minMap?especiePk=${esc(f.mapaPk)}&width=525&height=250" onerror="this.remove()">` : ""}
      <a href="${BIOTA}/especie/${codigo}" target="_blank" rel="noopener" class="pequeno" style="font-weight:600">Ver las cuadrículas de distribución en Biota ›</a>
      <span class="fuente-dato">Fuente: Biota${cent["Distribución en Canarias"] ? " · Centinela" : ""}</span>
      ${bloqueAltitud(f)}
      ${bloqueMundo(f)}
      ${f.gbifClave ? `<h3>Registros en GBIF</h3><div class="mapa-gbif" id="mapa-gbif" data-clave="${esc(f.gbifClave)}" data-amenazada="${esAmenazada(e) ? 1 : 0}"></div>
        <span class="fuente-dato">Densidad de registros de GBIF${esAmenazada(e) ? " en celdas grandes para no revelar localidades de una especie amenazada" : ""}. <a href="https://www.gbif.org/species/${esc(f.gbifClave)}" target="_blank" rel="noopener">Ver en GBIF</a></span>` : ""}
    </section>

    ${seccionIntroduccion(f, e)}

    ${(f.habitats?.length || cent["Hábitat"]) ? `<section class="seccion"><h2>Hábitat</h2>
      ${f.habitats?.length ? `<div class="chips">${[...new Set(f.habitats.map((h) => h.categoria))].map((h) => `<span class="insignia nv-canario">${esc(h)}</span>`).join("")}</div>` : ""}
      ${cent["Hábitat"] ? `<p>${esc(cent["Hábitat"])}</p>` : ""}
      <span class="fuente-dato">Fuente: ${[f.habitats?.length ? "Biota" : "", cent["Hábitat"] ? "Centinela" : ""].filter(Boolean).join(" · ")}</span></section>` : ""}

    ${Object.entries(cent).filter(([k]) => !["Origen", "Distribución mundial", "Distribución en Canarias", "Hábitat"].includes(k)).map(([k, v]) => `
      <section class="seccion"><h2>${esc(k)}</h2><p>${esc(v)}</p><span class="fuente-dato">Fuente: Centinela</span></section>`).join("")}

    <section class="seccion" id="calendario"><h2>Calendario</h2><div class="cargando pequeno" style="padding:8px 0">Consultando observaciones…</div></section>

    ${Object.keys(f.proteccion || {}).length || f.uicn || f.art17 || f.art12 || f.natura2000 ? `<section class="seccion"><h2>Amenaza y protección</h2><div class="tabla-prot">${filaUicn(f)}${filaArt17(f)}${filaArt12(f)}${tablaProteccion(f.proteccion || {})}${filaNatura(f)}</div>
      <span class="fuente-dato">Fuente: ${[f.uicn ? "UICN vía GBIF" : "", "Biota", f.centinela ? "Centinela" : "", f.art17 || f.art12 ? "informes a la UE (EEA)" : "", f.natura2000 ? "Natura 2000 (EEA)" : ""].filter(Boolean).join(" · ")}. Categoría por isla según cada catálogo.</span></section>` : ""}

    ${seccionVulnerabilidad(f)}

    ${seccionEtimologia(f)}

    ${f.taxonomia ? `<section class="seccion"><h2>Taxonomía</h2><div class="tax">
      ${Object.entries(f.taxonomia).map(([r, v]) => `<div><span class="r">${esc(r)}</span><span class="v ${/Género|Especie|Subespecie/.test(r) ? "sci" : ""}">${esc(v)}</span></div>`).join("")}</div>
      ${f.sinonimos ? `<a class="pequeno" style="font-weight:600" href="${BIOTA}/especie/${codigo}#taxonomyTab" target="_blank" rel="noopener">${f.sinonimos} sinónimos (sub nómine) en Biota ›</a>` : ""}</section>` : ""}

    ${seccionGenero(e)}

    <section class="seccion"><h2>Webs oficiales</h2>${enlacesOficiales(e, f)}</section>

    ${f.evc ? `<section class="seccion"><h2>Otras webs</h2><a class="enlace-oficial" href="${esc(f.evc.url)}" target="_blank" rel="noopener"><span class="inicial">EV</span><span class="t">Especies Vegetales en Canarias<small>Fotos y ficha · © ${esc(f.evc.autoria)}</small></span>${icono("externo")}</a></section>` : ""}

    ${avs.length ? `<section class="seccion"><h2>Tus avistamientos</h2><div>${avs.map((a) => filaAvistamiento(a, e)).join("")}</div></section>` : ""}

    <section class="seccion fuentes-ficha"><h2>De dónde sale cada dato</h2>
      <div><span>Nombres, taxonomía, endemicidad y origen</span><span>Biota</span></div>
      <div><span>Presencia por islas y protección</span><span>Biota</span></div>
      ${f.centinela ? "<div><span>Distribución, hábitat y claves</span><span>Centinela</span></div>" : ""}
      ${f.uicn ? "<div><span>Categoría UICN</span><span>UICN 2022-2 vía GBIF</span></div>" : ""}
      ${f.tamano ? `<div><span>Tamaño</span><span>${esc(f.tamano.fuente)}</span></div>` : ""}
      ${f.peso ? `<div><span>Peso</span><span>${esc(f.peso.fuente)}</span></div>` : ""}
      ${f.longevidad ? `<div><span>Longevidad</span><span>${esc(f.longevidad.fuente)}</span></div>` : f.ciclo ? `<div><span>Ciclo de vida</span><span>${esc(f.ciclo.fuente)}</span></div>` : ""}
      ${f.rasgos ? `<div><span>Biología</span><span>${esc([...new Set(f.rasgos.map((x) => x.fuente))].join(" · "))}</span></div>` : ""}
      ${f.sonidos ? `<div><span>Sonidos</span><span>${esc([...new Set(f.sonidos.map((x) => x.fuente))].join(" · "))}</span></div>` : ""}
      ${f.altitud ? "<div><span>Altitud</span><span>GBIF · Copernicus GLO-90</span></div>" : ""}
      ${f.mundo ? "<div><span>Distribución mundial</span><span>WCVP (Kew)</span></div>" : ""}
      ${f.art17 || f.art12 ? "<div><span>Estado en la UE</span><span>Informes art. 12 y 17 (EEA)</span></div>" : ""}
      ${f.natura2000 ? "<div><span>Red Natura 2000</span><span>EEA</span></div>" : ""}
      ${f.introduccion ? "<div><span>Introducción</span><span>Compendio de especies introducidas (Gob. de Canarias)</span></div>" : ""}
      ${f.primerRegistro ? "<div><span>Primer registro</span><span>GBIF</span></div>" : ""}
      ${f.tallaMinima ? "<div><span>Talla mínima</span><span>BOE (RD 560/1995)</span></div>" : ""}
      ${f.etimologia ? "<div><span>Etimología</span><span>Wikipedia (es)</span></div>" : ""}
      ${f.vulnerabilidad ? `<div><span>Vulnerabilidad al cambio climático</span><span>${esc(f.vulnerabilidad.fuente)}</span></div>` : ""}
      <div><span>Calendario</span><span>iNaturalist</span></div>
      <div><span>Fotos</span><span>${esc(fuentesFotos(f) || "—")}</span></div>
      <span class="fuente-dato">Datos descargados el ${esc(f.actualizado || "")}. ${f.referencias ? `Biota cita ${f.referencias} referencias para este taxón.` : ""}</span>
    </section>
  `;
  const pista = document.getElementById("pista");
  if (pista) pista.addEventListener("scroll", () => {
    const i = Math.round(pista.scrollLeft / pista.clientWidth) + 1;
    const c = document.getElementById("contador"); if (c) c.textContent = `${i} / ${pista.children.length}`;
  }, { passive: true });
  pintarCalendario(e);
  pintarMapaGbif();
}

function opFotos() {
  return { biota: A.get("fotosBiota"), libres: A.get("fotosLibres") };
}

function fuentesFotos(f) {
  const l = [];
  if ((f.imagenes || []).length) l.push("Biota (desde su web)");
  for (const x of f.fotosLibres || []) if (!l.includes(x.fuente)) l.push(x.fuente);
  if (f.evc) l.push("enlace a Especies Vegetales en Canarias");
  return l.join(" · ");
}

// ------------------------------------------------------- secciones nuevas

const enlaceFuente = (txt, url) => url ? `<a href="${esc(url)}" target="_blank" rel="noopener">${esc(txt)}</a>` : esc(txt);

function seccionBiologia(f) {
  const filas = [...(f.rasgos || [])];
  if (f.tallaMinima) filas.push({ grupo: "Pesca", k: "Talla mínima legal (caladero canario)", v: `${f.tallaMinima.valor} · ${f.tallaMinima.especieNorma}`, fuente: "BOE · RD 560/1995", url: f.tallaMinima.url });
  if (!filas.length) return "";
  const grupos = {};
  for (const x of filas) (grupos[x.grupo] ||= []).push(x);
  return `<section class="seccion"><h2>Biología</h2>
    ${Object.entries(grupos).map(([g, xs]) => `<h3>${esc(g)}</h3><div class="rasgos">${xs.map((x) => `<div class="rasgo"><span class="k">${esc(x.k)}</span><span class="v">${esc(x.v)}</span><span class="f">${enlaceFuente(x.fuente, x.url)}</span></div>`).join("")}</div>`).join("")}
    ${f.tallaMinima ? '<span class="fuente-dato">La talla mínima procede del texto consolidado del BOE; comprueba la normativa vigente (también la europea y la de pesca recreativa) antes de pescar.</span>' : ""}
  </section>`;
}

const TIPO_SONIDO = [[/alarm call/g, "alarma"], [/flight call/g, "reclamo en vuelo"], [/begging call/g, "petición de comida"],
  [/song/g, "canto"], [/calls?/g, "reclamo"], [/echolocation/g, "ecolocalización"], [/social/g, "social"], [/drumming/g, "tamborileo"],
  [/female/g, "hembra"], [/male/g, "macho"], [/adult/g, "adulto"], [/juvenile/g, "juvenil"], [/near /g, "cerca de "]];
const tipoSonido = (t) => TIPO_SONIDO.reduce((x, [re, es]) => x.replace(re, es), t || "");

function seccionSonidos(f) {
  if (!f.sonidos?.length) return "";
  return `<section class="seccion"><h2>Sonidos</h2>
    ${f.sonidos.map((x) => `<figure class="sonido">
      <audio controls preload="none" src="${esc(x.url)}"></audio>
      <figcaption class="pequeno texto-2">${esc([tipoSonido(x.tipo), tipoSonido(x.lugar)].filter(Boolean).join(" · ") || "Grabación")}${x.canarias ? "" : " (fuera de Canarias)"} · ${esc(x.autor)} · ${enlaceFuente(x.lic, x.licUrl)} · ${enlaceFuente(x.fuente, x.pagina)}</figcaption>
    </figure>`).join("")}
  </section>`;
}

function bloqueAltitud(f) {
  const a = f.altitud;
  if (!a) return "";
  const m = (v) => `${v.toLocaleString("es")} m`;
  return `<h3>Altitud</h3><p><b>${m(a.p5)} – ${m(a.p95)}</b> (el 90 % central de ${a.n.toLocaleString("es")} registros georreferenciados; extremos ${m(a.min)} – ${m(a.max)})</p>
    <span class="fuente-dato">Altitud medida en el modelo del terreno Copernicus GLO-90 en cada registro de GBIF con precisión de 1 km o mejor. <a href="${esc(a.url)}" target="_blank" rel="noopener">Ver registros</a></span>`;
}

function bloqueMundo(f) {
  const w = f.mundo;
  if (!w) return "";
  return `<h3>Distribución mundial</h3>
    ${w.nativa?.length ? `<p><b>Nativa:</b> ${esc(w.nativa.join(", "))}</p>` : ""}
    ${w.introducida?.length ? `<p><b>Introducida:</b> ${esc(w.introducida.join(", "))}</p>` : ""}
    <span class="fuente-dato">Fuente: ${enlaceFuente("WCVP · Plants of the World Online (Kew)", w.url)}${w.nivel === "especie" ? " · dato de la especie" : ""}${w.nombre ? ` · como ${esc(w.nombre)}` : ""}</span>`;
}

function seccionIntroduccion(f, e) {
  const d = f.introduccion, p = f.primerRegistro;
  if (!d && !p) return "";
  const fila = (k, v) => v ? `<div class="rasgo"><span class="k">${esc(k)}</span><span class="v">${esc(v)}</span></div>` : "";
  return `<section class="seccion"><h2>Especie introducida</h2>
    ${d ? `<div class="rasgos">${fila("Origen", d.origen)}${fila("Cuándo llegó", d.fecha)}${fila("Cómo llegó", d.via)}${fila("Cómo se propaga ahora", d.dispersion)}${fila("Islas donde se introdujo", d.islas)}</div>
      <span class="fuente-dato">${esc(d.autor || "")}${d.ano ? ` (${esc(d.ano)})` : ""}. Ficha de <i>${esc(d.nombre || e.n)}</i> en: ${enlaceFuente("Compendio de fichas de la Base de especies introducidas en Canarias (2008-2011)", d.url)}. Gobierno de Canarias, 2022${d.pagina ? `, pág. ${d.pagina}` : ""}.</span>` : ""}
    ${p ? `<p><b>Primer registro en GBIF en Canarias:</b> ${p.ano}${p.tipo ? ` (${esc(p.tipo)})` : ""} · <a href="${esc(p.url)}" target="_blank" rel="noopener">ver registro</a></p>
      <span class="fuente-dato">Es el registro más antiguo publicado en GBIF; la especie pudo llegar antes.</span>` : ""}
  </section>`;
}

const SITIO = { A: "ZEPA", B: "ZEC", C: "ZEC y ZEPA" };
function filaNatura(f) {
  const n = f.natura2000;
  if (!n?.espacios?.length) return "";
  return `<div class="p-fila"><span class="codigo">N2000</span>
    <span style="flex:1;display:flex;flex-direction:column;gap:1px;min-width:0"><span class="k">Red Natura 2000 en Canarias</span>
      <span class="v">En el formulario oficial de ${n.espacios.length} espacio${n.espacios.length > 1 ? "s" : ""}</span>
      <details><summary>Ver los espacios</summary><ul class="lista-n2000">${n.espacios.map((x) => `<li><a href="https://natura2000.eea.europa.eu/Natura2000/SDF.aspx?site=${esc(x.codigo)}" target="_blank" rel="noopener">${esc(x.nombre)}</a> <span class="texto-2">${esc(SITIO[x.tipo] || "")} · ${esc(x.codigo)}</span></li>`).join("")}</ul></details></span></div>`;
}

const COLOR_ESTADO = { "favorable": "uicn-LC", "desfavorable-inadecuado": "uicn-VU", "desfavorable-malo": "uicn-EN", "desconocido": "uicn-DD" };
const SIGLA_ESTADO = { "favorable": "FV", "desfavorable-inadecuado": "U1", "desfavorable-malo": "U2", "desconocido": "XX" };
const PARAM = { range: "área de distribución", population: "población", habitat: "hábitat", future: "perspectivas" };
function filaArt17(f) {
  const a = f.art17;
  if (!a) return "";
  const params = Object.entries(a.parametros || {}).filter(([, v]) => v).map(([k, v]) => `${PARAM[k] || k}: ${v}`).join(" · ");
  return `<div class="p-fila"><span class="codigo ${COLOR_ESTADO[a.estado] || ""}">${SIGLA_ESTADO[a.estado] || "?"}</span>
    <span style="flex:1;display:flex;flex-direction:column;gap:1px;min-width:0"><span class="k">Estado de conservación · ${esc(a.ambito)}</span>
      <span class="v">${esc(a.estado.charAt(0).toUpperCase() + a.estado.slice(1))}${a.tendencia ? ` · ${esc(a.tendencia)}` : ""}</span>
      <span class="k">Directiva Hábitats, art. 17 · ${esc(a.periodo)} · <a href="${esc(a.url)}" target="_blank" rel="noopener">EEA</a></span>
      ${params ? `<details><summary>Por parámetros</summary><span class="pequeno">${esc(params)}</span></details>` : ""}</span></div>`;
}

function filaArt12(f) {
  const a = f.art12;
  if (!a || (!a.poblacion && !a.tendencia)) return "";
  return `<div class="p-fila"><span class="codigo">Art. 12</span>
    <span style="flex:1;display:flex;flex-direction:column;gap:1px;min-width:0"><span class="k">Población ${esc(a.estacion || "")} · ${esc(a.ambito)}</span>
      <span class="v">${esc(a.poblacion || "Sin cifra")}${a.fechaPoblacion ? ` (${esc(a.fechaPoblacion)})` : ""}</span>
      <span class="k">${a.tendencia ? `Tendencia a corto plazo: ${esc(a.tendencia)}` : ""}${a.tendenciaLarga ? ` · a largo plazo: ${esc(a.tendenciaLarga)}` : ""}</span>
      <span class="k">Directiva Aves, art. 12 · ${esc(a.periodo)} · <a href="${esc(a.url)}" target="_blank" rel="noopener">EEA</a></span></span></div>`;
}

function seccionVulnerabilidad(f) {
  const v = f.vulnerabilidad;
  if (!v) return "";
  return `<section class="seccion"><h2>Vulnerabilidad al cambio climático</h2>
    <div class="rasgos">${v.categoria ? `<div class="rasgo"><span class="k">Categoría</span><span class="v">${esc(v.categoria)}</span></div>` : ""}${v.indice ? `<div class="rasgo"><span class="k">Índice</span><span class="v">${esc(v.indice)}</span></div>` : ""}</div>
    <span class="fuente-dato">Fuente: ${enlaceFuente(v.fuente, v.url)}</span></section>`;
}

function seccionEtimologia(f) {
  const t = f.etimologia;
  if (!t) return "";
  return `<section class="seccion"><h2>El nombre</h2><p>${esc(t.texto.replace(/\u200b/g, ""))}</p><span class="fuente-dato">Fuente: ${enlaceFuente(t.fuente, t.url)}</span></section>`;
}

function seccionGenero(e) {
  const otros = D.mismoGenero(e);
  if (!otros.length) return "";
  const fotos = opFotos();
  return `<section class="seccion"><div class="titulo-seccion"><h2>Mismo género en Canarias</h2>
      <a href="#/explorar" data-explorar='${JSON.stringify({ q: e._gen })}'>Ver ${otros.length + 1}</a></div>
    <div class="carril genero">${otros.slice(0, 24).map((x) => `<a class="mini-especie" href="#/especie/${x.c}">${miniatura(x, fotos, 250)}
      <span class="nombre">${esc(nombreComun(x))}</span><span class="sci-mini">${nombreSci(x.n, "", false)}</span></a>`).join("")}</div>
  </section>`;
}

function pintarMapaGbif() {
  const caja = document.getElementById("mapa-gbif");
  if (!caja) return;
  const clave = caja.dataset.clave, amenazada = caja.dataset.amenazada === "1";
  const obs = new IntersectionObserver((ents) => {
    if (!ents.some((x) => x.isIntersecting)) return;
    obs.disconnect();
    cargarLeaflet().then((L) => {
      const m = L.map(caja, { zoomControl: false, attributionControl: true, scrollWheelZoom: false }).setView([28.3, -15.8], 6);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 12, attribution: "© OpenStreetMap" }).addTo(m);
      const bin = amenazada ? "bin=square&squareSize=128" : "bin=hex&hexPerTile=40";
      L.tileLayer(`https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?taxonKey=${encodeURIComponent(clave)}&${bin}&style=classic.poly`,
        { maxZoom: amenazada ? 8 : 12, opacity: 0.85, attribution: "GBIF" }).addTo(m);
    }).catch(() => { caja.remove(); });
  }, { rootMargin: "200px" });
  obs.observe(caja);
}

function hecho(ic, k, v, s) {
  return `<div class="hecho"><span class="k">${icono(ic)}${esc(k)}</span><span class="v">${esc(v)}</span><span class="s">${esc(s)}</span></div>`;
}

function pesoTexto(kg) {
  if (kg >= 1000) return `${(Math.round(kg / 100) / 10).toLocaleString("es")} t`;
  if (kg >= 1) return `${(Math.round(kg * 10) / 10).toLocaleString("es")} kg`;
  return `${(Math.round(kg * 10000) / 10).toLocaleString("es")} g`;
}

function seccionTamano(f, e) {
  if (!f.tamano && !f.peso && !f.longevidad && !f.ciclo) return "";
  const t = f.tamano;
  const fuente = (d) => d.url ? `<a href="${esc(d.url)}" target="_blank" rel="noopener">${esc(d.fuente)}</a>` : esc(d.fuente);
  const lineas = [];
  if (t) lineas.push(`<p><b>${esc(t.tipo.charAt(0).toUpperCase() + t.tipo.slice(1))}:</b> ${esc(textoTamano(t).toLowerCase())} · ${fuente(t)}${t.nivel === "especie" ? " (dato de la especie)" : ""}</p>${t.cita ? `<p class="pequeno texto-2" style="font-style:italic">«${esc(t.cita)}»</p>` : ""}`);
  if (f.peso) lineas.push(`<p><b>Peso ${esc(f.peso.tipo)}:</b> ${pesoTexto(f.peso.kg)} · ${fuente(f.peso)}</p>`);
  if (f.longevidad) lineas.push(`<p><b>Longevidad ${esc(f.longevidad.tipo)}:</b> ${(Math.round(f.longevidad.anos * 10) / 10).toLocaleString("es")} años${f.longevidad.origen ? ` (${esc(f.longevidad.origen)})` : ""} · ${fuente(f.longevidad)}</p>`);
  if (f.ciclo) lineas.push(`<p><b>Ciclo de vida:</b> ${esc(f.ciclo.valor)} · ${esc(f.ciclo.fuente)}</p>`);
  return `<section class="seccion"><h2>Tamaño${f.longevidad || f.ciclo ? " y vida" : ""}</h2>
    ${t ? `<div class="diagrama-tamano">${diagrama(f.forma?.valor || (e.re === "Flora" ? "arbusto" : "mamifero"), t, A.get("altura"))}</div>` : ""}
    ${lineas.join("")}</section>`;
}

function filaUicn(f) {
  if (!f.uicn) return "";
  const u = f.uicn;
  return `<div class="p-fila"><span class="codigo uicn-${esc(u.codigo)}">${esc(u.codigo)}</span>
    <span style="flex:1;display:flex;flex-direction:column;gap:1px;min-width:0"><span class="k">UICN · Lista Roja mundial</span><span class="v">${esc(u.categoria)}</span>
      <span class="k">Versión 2022-2${u.nivel === "especie" ? " · evaluada a nivel de especie" : ""}${u.url ? ` · <a href="${esc(u.url)}" target="_blank" rel="noopener">GBIF</a>` : ""}</span></span></div>`;
}

const CORTO = {
  "En peligro de extinción": "EN", "Vulnerable": "VU", "Protección especial": "PE", "Régimen de protección especial": "PE",
  "Interés para los ecosistemas canarios": "IEC", "Sensible a la alteración de su hábitat": "SAH", "De interés especial": "IE",
};
function tablaProteccion(prot) {
  return Object.entries(prot).map(([cat, islas]) => {
    const porCategoria = {};
    for (const [isla, d] of Object.entries(islas)) (porCategoria[d.categoria] ||= { islas: [], def: d.definicion }).islas.push(isla);
    return Object.entries(porCategoria).map(([c, { islas: is, def }]) => `
      <div class="p-fila"><span class="codigo">${esc(CORTO[c] || c.replace(/^(Anexo|Anejo)\s*/i, ""))}</span>
        <span style="flex:1;display:flex;flex-direction:column;gap:1px;min-width:0"><span class="k">${esc(cat)}</span><span class="v">${esc(c)}</span>
          <span class="k">${esc(is.join(", "))}</span>
          ${def ? `<details><summary>Qué significa</summary><span class="pequeno">${esc(def)}</span></details>` : ""}</span></div>`).join("");
  }).join("");
}

function enlacesOficiales(e, f) {
  const l = [];
  const add = (ini, t, d, url) => l.push(`<a class="enlace-oficial" href="${esc(url)}" target="_blank" rel="noopener"><span class="inicial">${ini}</span><span class="t">${esc(t)}<small>${esc(d)}</small></span>${icono("externo")}</a>`);
  add("B", "Ficha en Biota", "Banco de Datos de Biodiversidad de Canarias", `${BIOTA}/especie/${e.c}`);
  if (f.centinela) {
    add("C", "Ficha de especie protegida", "Centinela · Gobierno de Canarias", `${CENTINELA}/especie/${e.c}`);
    if (f.centinela.pdf) add("C", "Ficha en PDF", "Centinela", `${CENTINELA}/especie/${e.c}/informe`);
  }
  for (const en of f.enlaces || []) {
    const u = en.url;
    if (/iucnredlist/.test(u)) add("U", "Lista Roja de la UICN", "iucnredlist.org", u);
    else if (/gbif\.org/.test(u)) add("G", "GBIF", "Global Biodiversity Information Facility", u);
    else if (/magrama|miteco|mapama/.test(u)) add("M", "Libros Rojos", "Ministerio para la Transición Ecológica", u);
    else if (/eionet/.test(u)) add("E", `Informe artículo 17 · ${en.titulo}`, "Directiva Hábitats · EIONET", u);
    else add("·", en.titulo || "Enlace", new URL(u).hostname, u);
  }
  if (["ISI", "ISP"].includes(f.origen?.codigo || e.o)) add("R", "Especies exóticas invasoras · REDEXOS", "Gobierno de Canarias: cómo avisar de un avistamiento", REDEXOS);
  const binomio = e.n.split(" ").filter((t) => !/^(subsp\.|var\.|f\.|×)$/.test(t)).slice(0, 2).join(" ");
  add("i", "iNaturalist", "Observaciones ciudadanas", `https://www.inaturalist.org/taxa/search?q=${encodeURIComponent(binomio)}`);
  return l.join("");
}

async function pintarCalendario(e) {
  const caja = document.getElementById("calendario");
  if (!caja) return;
  try {
    const d = await fenologia(e);
    const mes = new Date().getMonth();
    const filas = e.re === "Flora" && (d.flor.some(Boolean) || d.fruto.some(Boolean))
      ? [["flor", "Floración", d.flor], ["fruto", "Frutos", d.fruto]]
      : [["", "Observaciones", d.total]];
    const max = Math.max(1, ...filas.flatMap(([, , v]) => v));
    caja.innerHTML = `<h2>Calendario</h2>
      <div class="calendario">${MESES.map((m, i) => `<div class="mes"><span class="letra ${i === mes ? "hoy" : ""}">${m}</span>
        ${filas.map(([cl, , v]) => `<span class="barra ${cl}" title="${v[i]} observaciones"><i style="opacity:${v[i] ? 0.25 + 0.75 * (v[i] / max) : 0}"></i></span>`).join("")}</div>`).join("")}</div>
      <div class="leyenda">${filas.map(([cl, t]) => `<span><i style="background:${cl === "fruto" ? "#EBC27A" : "var(--acento)"}"></i>${t}</span>`).join("")}
        <span>Más intenso = más observaciones · ${MESES_LARGOS[mes]} subrayado</span></div>
      <span class="fuente-dato">Fuente: iNaturalist, ${d.n.toLocaleString("es")} observaciones verificables en Canarias${d.especie ? " (a nivel de especie)" : ""}.</span>`;
    if (!d.n) caja.innerHTML = `<h2>Calendario</h2><p class="texto-2">Todavía no hay observaciones de este taxón en Canarias en iNaturalist.</p>`;
  } catch {
    caja.innerHTML = `<h2>Calendario</h2><p class="texto-2">No se ha podido consultar iNaturalist (¿sin conexión?).</p>`;
  }
}

async function fenologia(e) {
  const clave = `pokedex-canaria:fen:${e.c}`;
  try {
    const c = JSON.parse(localStorage.getItem(clave) || "null");
    if (c && Date.now() - c.t < 30 * 864e5) return c.d;
  } catch { /* sin caché */ }
  const partes = e.n.split(" ").filter((t) => !/^(subsp\.|var\.|f\.|×)$/.test(t));
  const binomio = partes.slice(0, 2).join(" ");
  const base = `https://api.inaturalist.org/v1/observations/histogram?taxon_name=${encodeURIComponent(binomio)}&swlat=27.4&swlng=-18.4&nelat=29.6&nelng=-13.2&interval=month_of_year&date_field=observed&verifiable=true`;
  const leer = async (u) => { const r = await fetch(u); if (!r.ok) throw new Error("iNaturalist"); const j = await r.json(); return Array.from({ length: 12 }, (_, i) => j.results?.month_of_year?.[i + 1] || 0); };
  const total = await leer(base);
  let flor = Array(12).fill(0), fruto = Array(12).fill(0);
  if (e.re === "Flora") [flor, fruto] = await Promise.all([leer(`${base}&term_id=12&term_value_id=13`), leer(`${base}&term_id=12&term_value_id=14`)]);
  const d = { total, flor, fruto, n: total.reduce((a, b) => a + b, 0), especie: partes.length > 2 };
  try { localStorage.setItem(clave, JSON.stringify({ t: Date.now(), d })); } catch { /* lleno */ }
  return d;
}

// ----------------------------------------------------------- avistamientos

const ESTADOS_PLANTA = ["Adulto", "En flor", "Con fruto", "Plántula o juvenil", "Plantado o cultivado", "Seco o muerto"];
const ESTADOS_ANIMAL = ["Adulto", "Juvenil", "Cantando o llamando", "Cortejo o celo", "Con nido o crías", "Muerto"];

function filaAvistamiento(a, e) {
  const t = a.tiempo || {};
  const [cielo, ic] = t.codigo != null ? V.cielo(t.codigo) : ["Sin datos del tiempo", "nube"];
  const fecha = new Date(a.fecha);
  return `<button class="fila" data-accion="ver-avistamiento" data-id="${a.id}">
    ${e ? miniatura(e, opFotos()) : ""}
    <span class="cuerpo"><span class="principal">${esc(a.comun || a.nombre)}</span>
      <span class="secundario">${esc([a.paraje, a.municipio].filter(Boolean).join(", ") || a.isla || "Sin lugar")}</span>
      <span class="secundario">${fecha.toLocaleDateString("es", { day: "numeric", month: "short" })} · ${fecha.toLocaleTimeString("es", { hour: "2-digit", minute: "2-digit" })}${a.individuos > 1 ? ` · ${a.individuos} individuos` : ""}</span></span>
    <span style="display:flex;flex-direction:column;align-items:center;gap:2px;flex:none">${icono(ic, `role="img" aria-label="${esc(cielo)}"`)}<span class="pequeno" style="font-weight:600">${t.temperatura != null ? `${Math.round(t.temperatura)} °C` : a.tiempoPendiente ? "…" : ""}</span></span>
  </button>`;
}

function abrirNuevoAvistamiento(codigo) {
  const e = D.porCodigo(codigo);
  const ahora = new Date();
  const av = { id: V.nuevoId(), codigo, nombre: e.n, comun: nombreComun(e), fecha: ahora.toISOString(), individuos: 1, estados: [], notas: "", lat: null, lon: null };
  const estados = e.re === "Flora" ? ESTADOS_PLANTA : ESTADOS_ANIMAL;
  let mapa = null, marcador = null, fotoUrl = null;
  const { panel } = abrirHoja();
  const local = (d) => new Date(d.getTime() - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16);

  panel.innerHTML = `
    <span class="asa"></span>
    <div class="barra-hoja"><button data-h="cerrar">Cancelar</button><h2>Nuevo avistamiento</h2><button data-h="guardar" style="font-weight:700">Guardar</button></div>
    <div class="lista"><div class="fila" style="cursor:default">${miniatura(e, opFotos())}
      <span class="cuerpo"><span class="numero">${numero(e.no)}</span><span class="principal">${esc(nombreComun(e))}</span><span class="secundario">${nombreSci(e.n, "", false)}</span></span></div></div>
    ${A.get("guardarLugar") ? '<div class="mapa" id="mapa-nuevo"><div class="cargando pequeno">Buscando tu posición…</div></div>' : ""}
    <div class="lista">
      <label class="campo">${icono("calendario")}<span class="etq"><small>Fecha y hora</small><input type="datetime-local" id="av-fecha" value="${local(ahora)}"></span></label>
      ${A.get("guardarLugar") ? `
      <div class="campo">${icono("pin")}<span class="etq"><small>Lugar</small><span id="av-lugar">Buscando…</span></span><span class="estado-auto">auto</span></div>
      <div class="campo">${icono("mira")}<span class="etq"><small>Coordenadas</small><span id="av-coord">—</span></span><span class="estado-auto">auto</span></div>
      <div class="campo">${icono("montana")}<span class="etq"><small>Altitud</small><span id="av-alt">—</span></span><span class="estado-auto">auto</span></div>` : ""}
    </div>
    ${A.get("guardarTiempo") ? `<section class="seccion" id="av-tiempo"><div class="titulo-seccion"><h2>Tiempo en ese momento</h2><span class="estado-auto">auto</span></div>
      <p class="texto-2" id="av-tiempo-txt">Esperando la posición…</p></section>` : ""}
    <section class="seccion">
      <div class="titulo-seccion"><h2>Individuos</h2>
        <span class="paso"><button data-h="menos" aria-label="Uno menos">−</button><output id="av-n">1</output><button data-h="mas" aria-label="Uno más">+</button></span></div>
      <div class="chips">${estados.map((s) => `<button class="chip" aria-pressed="false" data-h="estado" data-v="${esc(s)}">${esc(s)}</button>`).join("")}</div>
    </section>
    <label class="foto-propia" id="av-foto">${icono("camara")}<span style="font-weight:600">Añadir tu foto</span><span class="pequeno texto-2">Se guarda solo en tu iPhone</span>
      <input type="file" accept="image/*" capture="environment" aria-label="Añadir tu foto"></label>
    <label style="display:flex;flex-direction:column;gap:6px"><span style="font-weight:700">Notas</span>
      <textarea class="notas" id="av-notas" placeholder="Comportamiento, estado del ejemplar, con quién ibas…"></textarea></label>
    <button class="boton" data-h="guardar">Guardar avistamiento</button>`;

  const pon = (id, t) => { const el = panel.querySelector(`#${id}`); if (el) el.textContent = t; };
  const pintarTiempo = () => {
    const caja = panel.querySelector("#av-tiempo");
    if (!caja) return;
    const t = av.tiempo;
    if (!t) return;
    const [cielo, ic] = V.cielo(t.codigo);
    caja.innerHTML = `<div class="titulo-seccion"><h2>Tiempo en ese momento</h2><span class="estado-auto">auto</span></div>
      <div class="tiempo-grande">${icono(ic, 'style="width:44px;height:44px"')}<b>${Math.round(t.temperatura)} °C</b><span class="texto-2">${esc(cielo)}</span></div>
      <div class="tiempo-datos"><div><small>Viento</small><span>${Math.round(t.viento)} km/h · ${V.rumbo(t.direccion)}</span></div><div><small>Humedad</small><span>${t.humedad} %</span></div>
        <div><small>Lluvia</small><span>${t.lluvia} mm</span></div><div><small>Nubosidad</small><span>${t.nubosidad} %</span></div></div>
      <span class="fuente-dato">Fuente: Open-Meteo</span>`;
  };

  if (A.get("guardarLugar")) {
    V.ubicar().then(async (p) => {
      Object.assign(av, p, { isla: V.islaDe(p.lat, p.lon) });
      pon("av-coord", `${p.lat.toFixed(5)}, ${p.lon.toFixed(5)} · ±${p.precision} m`);
      pon("av-alt", p.altitud != null ? `${p.altitud} m (GPS)` : "…");
      pon("av-lugar", av.isla);
      cargarLeaflet().then((L) => {
        const caja = panel.querySelector("#mapa-nuevo");
        if (!caja) return;
        caja.innerHTML = "";
        mapa = nuevoMapa(L, caja, [p.lat, p.lon], 15);
        L.circle([p.lat, p.lon], { radius: p.precision || 10, color: "#3D6B35", weight: 1, fillOpacity: 0.12 }).addTo(mapa);
        marcador = L.marker([p.lat, p.lon], { draggable: true }).addTo(mapa);
        marcador.on("dragend", () => {
          const ll = marcador.getLatLng();
          Object.assign(av, { lat: ll.lat, lon: ll.lng, precision: 0, isla: V.islaDe(ll.lat, ll.lng), ajustadoAMano: true });
          pon("av-coord", `${ll.lat.toFixed(5)}, ${ll.lng.toFixed(5)} · ajustado a mano`);
          completarLugar();
        });
      }).catch(() => { const c = panel.querySelector("#mapa-nuevo"); if (c) c.innerHTML = '<div class="cargando pequeno">Mapa no disponible sin conexión</div>'; });
      completarLugar();
      if (A.get("guardarTiempo")) {
        try { av.tiempo = await V.tiempoAhora(p.lat, p.lon); pintarTiempo(); } catch {
          av.tiempoPendiente = true; pon("av-tiempo-txt", "Sin conexión: el tiempo de este momento se completará solo más tarde.");
        }
      }
    }).catch((err) => {
      pon("av-lugar", err.message); const c = panel.querySelector("#mapa-nuevo"); if (c) c.remove();
      pon("av-tiempo-txt", "Sin posición no se puede consultar el tiempo.");
    });
  }
  async function completarLugar() {
    try {
      const l = await V.nombreLugar(av.lat, av.lon);
      Object.assign(av, l, { lugarPendiente: false });
      pon("av-lugar", [l.paraje, l.municipio, av.isla].filter(Boolean).join(", "));
    } catch { av.lugarPendiente = true; pon("av-lugar", `${av.isla} (el nombre del lugar se completará con conexión)`); }
    if (av.altitud == null) {
      try { av.altitud = await V.altitudDem(av.lat, av.lon); pon("av-alt", `${av.altitud} m (modelo del terreno)`); } catch { pon("av-alt", "—"); }
    }
  }

  panel.querySelector('#av-foto input').addEventListener("change", async (ev) => {
    const archivo = ev.target.files?.[0];
    if (!archivo) return;
    try {
      av.foto = await V.reducirFoto(archivo);
      if (fotoUrl) URL.revokeObjectURL(fotoUrl);
      fotoUrl = URL.createObjectURL(av.foto);
      const caja = panel.querySelector("#av-foto");
      caja.querySelector("img")?.remove();
      caja.insertAdjacentHTML("afterbegin", `<img alt="Tu foto" src="${fotoUrl}">`);
    } catch (err) { aviso(err.message); }
  });

  panel.addEventListener("click", async (ev) => {
    const b = ev.target.closest("[data-h]");
    if (!b) return;
    const h = b.dataset.h;
    if (h === "cerrar") { if (mapa) mapa.remove(); return cerrarHojas(); }
    if (h === "menos" || h === "mas") { av.individuos = Math.max(1, av.individuos + (h === "mas" ? 1 : -1)); pon("av-n", String(av.individuos)); }
    if (h === "estado") {
      const v = b.dataset.v; const on = !av.estados.includes(v);
      av.estados = on ? [...av.estados, v] : av.estados.filter((x) => x !== v);
      b.classList.toggle("activo", on); b.setAttribute("aria-pressed", String(on));
    }
    if (h === "guardar") {
      av.fecha = new Date(panel.querySelector("#av-fecha").value || ahora).toISOString();
      av.notas = panel.querySelector("#av-notas").value.trim();
      const p = A.get("precision");
      if (av.lat != null && (p === "Siempre aprox." || (p === "Aprox. si amenazada" && esAmenazada(e)))) {
        av.lat = Math.round(av.lat * 100) / 100; av.lon = Math.round(av.lon * 100) / 100; av.precision = 1000; av.aproximado = true;
      }
      if (A.get("guardarTiempo") && !av.tiempo && av.lat != null) av.tiempoPendiente = true;
      try {
        await V.guardar(av);
        estado.vistas.add(codigo);
        if (mapa) mapa.remove();
        cerrarHojas();
        aviso(`Avistamiento de ${av.comun} guardado`);
        render();
      } catch (err) { aviso(`No se pudo guardar: ${err.message}`); }
    }
  });
}

async function verAvistamiento(id) {
  const a = (await V.todos()).find((x) => x.id === id);
  if (!a) return;
  const e = D.porCodigo(a.codigo);
  const t = a.tiempo || {};
  const [cielo, ic] = t.codigo != null ? V.cielo(t.codigo) : ["", "nube"];
  const { panel } = abrirHoja();
  const foto = a.foto ? URL.createObjectURL(a.foto) : null;
  const fecha = new Date(a.fecha);
  panel.innerHTML = `
    <span class="asa"></span>
    <div class="barra-hoja"><button data-h="cerrar">Cerrar</button><h2>Avistamiento</h2><a href="#/especie/${a.codigo}" style="min-height:44px;display:flex;align-items:center">Ficha</a></div>
    <div><span class="nombre-comun">${esc(a.comun)}</span><div>${nombreSci(a.nombre, "", false)}</div></div>
    ${foto ? `<img alt="Tu foto" src="${foto}" style="border-radius:var(--radio);max-height:320px;object-fit:cover;width:100%">` : ""}
    <div class="lista">
      <div class="campo">${icono("calendario")}<span class="etq"><small>Fecha y hora</small><span>${fecha.toLocaleString("es", { dateStyle: "full", timeStyle: "short" })}</span></span></div>
      <div class="campo">${icono("pin")}<span class="etq"><small>Lugar</small><span>${esc([a.paraje, a.municipio, a.isla].filter(Boolean).join(", ") || "Sin lugar")}</span></span></div>
      ${a.lat != null ? `<div class="campo">${icono("mira")}<span class="etq"><small>Coordenadas${a.aproximado ? " (aproximadas)" : ""}</small><span>${a.lat.toFixed(5)}, ${a.lon.toFixed(5)}${a.precision ? ` · ±${a.precision} m` : ""}</span></span></div>` : ""}
      ${a.altitud != null ? `<div class="campo">${icono("montana")}<span class="etq"><small>Altitud</small><span>${a.altitud} m</span></span></div>` : ""}
      <div class="campo">${icono(ic)}<span class="etq"><small>Tiempo</small><span>${t.temperatura != null ? `${Math.round(t.temperatura)} °C · ${esc(cielo)} · viento ${Math.round(t.viento)} km/h ${V.rumbo(t.direccion)} · humedad ${t.humedad} % · lluvia ${t.lluvia} mm` : a.tiempoPendiente ? "Pendiente de completar" : "No guardado"}</span></span></div>
      <div class="campo">${icono("vistas")}<span class="etq"><small>Observación</small><span>${a.individuos} individuo${a.individuos > 1 ? "s" : ""}${a.estados?.length ? ` · ${esc(a.estados.join(", "))}` : ""}</span></span></div>
      ${a.notas ? `<div class="campo">${icono("hoja")}<span class="etq"><small>Notas</small><span style="font-weight:400;white-space:pre-line">${esc(a.notas)}</span></span></div>` : ""}
    </div>
    ${a.lat != null ? '<div class="mapa" id="mapa-av"></div>' : ""}
    <button class="boton peligro" data-h="borrar">${icono("papelera")} Borrar este avistamiento</button>`;
  if (a.lat != null) cargarLeaflet().then((L) => { const m = nuevoMapa(L, panel.querySelector("#mapa-av"), [a.lat, a.lon], 13); L.circleMarker([a.lat, a.lon], estiloPunto()).addTo(m); }).catch(() => {});
  panel.addEventListener("click", async (ev) => {
    const b = ev.target.closest("[data-h]");
    if (!b) return;
    if (b.dataset.h === "cerrar") { if (foto) URL.revokeObjectURL(foto); cerrarHojas(); }
    if (b.dataset.h === "borrar" && confirm("¿Borrar este avistamiento? No se puede deshacer.")) {
      await V.borrar(a.id);
      estado.vistas = await V.vistas();
      cerrarHojas(); aviso("Avistamiento borrado"); render();
    }
  });
  void e;
}

async function vistaAvistamientos() {
  const lista = await V.todos();
  const especies = new Set(lista.map((a) => a.codigo));
  const islas = new Set(lista.map((a) => a.isla).filter((x) => x && !/Mar|Fuera/.test(x)));
  const modo = estado.modoVistas;
  vista.innerHTML = `
    <div class="cabecera"><div class="titulos"><h1>Avistamientos</h1></div>
      <button class="boton-icono" data-accion="exportar" aria-label="Exportar o importar">${icono("compartir")}</button></div>
    <div class="segmentado" role="group" aria-label="Modo">
      ${[["lista", "Lista"], ["mapa", "Mapa"], ["resumen", "Resumen"]].map(([m, t]) => `<button aria-pressed="${modo === m}" data-accion="modo-vistas" data-m="${m}">${t}</button>`).join("")}
    </div>
    <div class="cifras"><div class="cifra"><b>${lista.length}</b><span>avistamientos</span></div><div class="cifra"><b>${especies.size}</b><span>especies</span></div><div class="cifra"><b>${islas.size}</b><span>islas</span></div></div>
    <div id="contenido-vistas"></div>`;
  const caja = document.getElementById("contenido-vistas");
  if (!lista.length) {
    caja.innerHTML = `<div class="vacio">${icono("vistas")}<p>Aún no has guardado ningún avistamiento.</p><p class="pequeno">Abre la ficha de una especie y pulsa «La he visto».</p></div>`;
    return;
  }
  if (modo === "lista") {
    const porMes = new Map();
    for (const a of lista) {
      const d = new Date(a.fecha);
      const k = `${MESES_LARGOS[d.getMonth()]} ${d.getFullYear()}`;
      if (!porMes.has(k)) porMes.set(k, []);
      porMes.get(k).push(a);
    }
    caja.innerHTML = [...porMes.entries()].map(([mes, avs]) => `<section class="grupo-ajustes" style="margin-bottom:14px"><h2 class="subtitulo-grupo">${esc(mes)}</h2>
      <div class="lista">${avs.map((a) => filaAvistamiento(a, D.porCodigo(a.codigo))).join("")}</div></section>`).join("");
  } else if (modo === "mapa") {
    caja.innerHTML = '<div class="mapa alto" id="mapa-vistas"></div>';
    cargarLeaflet().then((L) => {
      const m = nuevoMapa(L, document.getElementById("mapa-vistas"), [28.3, -15.9], 7);
      const pts = lista.filter((a) => a.lat != null);
      for (const a of pts) L.circleMarker([a.lat, a.lon], estiloPunto()).addTo(m).bindPopup(`<b>${esc(a.comun)}</b><br>${new Date(a.fecha).toLocaleDateString("es")}<br><a href="#/especie/${a.codigo}">Ver ficha</a>`);
      if (pts.length) m.fitBounds(pts.map((a) => [a.lat, a.lon]), { padding: [30, 30], maxZoom: 13 });
    }).catch(() => { caja.innerHTML = '<div class="vacio">El mapa necesita conexión la primera vez.</div>'; });
  } else {
    const total = D.cuentaPorGrupo();
    const vistasPorGrupo = {};
    for (const c of especies) { const e = D.porCodigo(c); if (e) vistasPorGrupo[e.g] = (vistasPorGrupo[e.g] || 0) + 1; }
    const porIsla = {};
    for (const a of lista) if (a.isla) porIsla[a.isla] = (porIsla[a.isla] || 0) + 1;
    caja.innerHTML = `
      <section class="seccion"><h2>Por grupo</h2>${Object.entries(total).map(([g, n]) => `<div style="display:flex;flex-direction:column;gap:4px">
        <div style="display:flex;justify-content:space-between" class="pequeno"><span>${esc(g)}</span><span><b>${vistasPorGrupo[g] || 0}</b> de ${n}</span></div>
        <div class="progreso"><i style="width:${((vistasPorGrupo[g] || 0) / n) * 100}%"></i></div></div>`).join("")}</section>
      <section class="seccion"><h2>Por isla</h2>${Object.entries(porIsla).sort((a, b) => b[1] - a[1]).map(([i, n]) => `<div style="display:flex;justify-content:space-between" class="pequeno"><span>${esc(i)}</span><b>${n}</b></div>`).join("")}</section>`;
  }
}

function abrirExportar() {
  const { panel } = abrirHoja();
  panel.innerHTML = `
    <span class="asa"></span>
    <div class="barra-hoja"><button data-h="cerrar">Cerrar</button><h2>Exportar o importar</h2><span style="width:60px"></span></div>
    <div class="ajustes-lista">
      <button class="ajuste" data-h="csv"><span class="etq"><span>Exportar a Excel (CSV)</span><small>Fecha, lugar, coordenadas, tiempo y notas</small></span>${icono("descargar")}</button>
      <button class="ajuste" data-h="json"><span class="etq"><span>Hacer copia de seguridad</span><small>Archivo para recuperar los avistamientos (sin fotos)</small></span>${icono("descargar")}</button>
      <label class="ajuste"><span class="etq"><span>Recuperar una copia</span><small>Elige un archivo de copia de seguridad</small></span>${icono("compartir")}
        <input type="file" accept="application/json,.json" data-h="importar" class="oculto-visual"></label>
    </div>`;
  panel.addEventListener("click", async (ev) => {
    const b = ev.target.closest("[data-h]");
    if (!b) return;
    if (b.dataset.h === "cerrar") cerrarHojas();
    if (b.dataset.h === "csv") descargarArchivo(await V.aCsv(), `avistamientos-${new Date().toISOString().slice(0, 10)}.csv`, "text/csv");
    if (b.dataset.h === "json") descargarArchivo(await V.aJson(), `avistamientos-copia-${new Date().toISOString().slice(0, 10)}.json`, "application/json");
  });
  panel.querySelector('[data-h="importar"]').addEventListener("change", async (ev) => {
    const f = ev.target.files?.[0]; if (!f) return;
    try { const n = await V.importarJson(await f.text()); estado.vistas = await V.vistas(); aviso(`${n} avistamientos recuperados`); cerrarHojas(); render(); }
    catch (err) { aviso(`No se pudo importar: ${err.message}`); }
  });
}

function descargarArchivo(texto, nombre, tipo) {
  const url = URL.createObjectURL(new Blob([texto], { type: `${tipo};charset=utf-8` }));
  const a = document.createElement("a");
  a.href = url; a.download = nombre; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// ---------------------------------------------------------------------- mapa

async function vistaMapa() {
  const lista = await V.todos();
  vista.innerHTML = `
    <div class="cabecera"><div class="titulos"><h1>Mapa</h1><span class="pequeno texto-2">Tus avistamientos. Toca una isla del mapa para ver sus especies.</span></div></div>
    <div class="mapa alto" id="mapa-general"><div class="cargando pequeno">Cargando mapa…</div></div>
    <div class="carril">${["T", "C", "P", "G", "H", "F", "L"].map((k) => `<a class="chip" href="#/explorar" data-explorar='${JSON.stringify({ i: [k] })}'>${esc(NOMBRE_ISLA[k])}</a>`).join("")}</div>`;
  try {
    const L = await cargarLeaflet();
    const caja = document.getElementById("mapa-general");
    caja.innerHTML = "";
    const m = nuevoMapa(L, caja, [28.3, -15.9], 7);
    for (const a of lista.filter((x) => x.lat != null)) L.circleMarker([a.lat, a.lon], estiloPunto()).addTo(m).bindPopup(`<b>${esc(a.comun)}</b><br>${new Date(a.fecha).toLocaleDateString("es")}<br><a href="#/especie/${a.codigo}">Ver ficha</a>`);
    m.on("click", (ev) => {
      const isla = V.islaDe(ev.latlng.lat, ev.latlng.lng);
      const k = Object.entries(NOMBRE_ISLA).find(([, n]) => n === isla)?.[0];
      if (k) L.popup().setLatLng(ev.latlng).setContent(`<b>${esc(isla)}</b><br><a href="#/explorar" data-explorar='${JSON.stringify({ i: [k] })}'>Ver sus especies</a>`).openOn(m);
    });
  } catch {
    document.getElementById("mapa-general").innerHTML = '<div class="vacio">El mapa necesita conexión la primera vez.</div>';
  }
}

let leaflet = null;
function cargarLeaflet() {
  if (window.L) return Promise.resolve(window.L);
  if (!leaflet) leaflet = new Promise((ok, mal) => {
    const css = document.createElement("link"); css.rel = "stylesheet"; css.href = "vendor/leaflet/leaflet.css"; document.head.appendChild(css);
    const s = document.createElement("script"); s.src = "vendor/leaflet/leaflet.js";
    s.onload = () => { window.L.Icon.Default.imagePath = "vendor/leaflet/images/"; ok(window.L); };
    s.onerror = () => { leaflet = null; mal(new Error("Leaflet")); };
    document.head.appendChild(s);
  });
  return leaflet;
}
function nuevoMapa(L, el, centro, zoom) {
  const m = L.map(el, { zoomControl: true }).setView(centro, zoom);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap" }).addTo(m);
  setTimeout(() => m.invalidateSize(), 50);
  return m;
}
const estiloPunto = () => ({ radius: 7, color: "#fff", weight: 2, fillColor: getComputedStyle(document.documentElement).getPropertyValue("--acento").trim() || "#3D6B35", fillOpacity: 1 });

// ------------------------------------------------------------------- ajustes

function vistaAjustes() {
  const est = A.get("estilo");
  const meta = D.getMeta();
  const fila = (id) => {
    const def = A.OPCIONES.find((d) => d.id === id);
    const v = A.valor(id);
    const abierto = estado.abierto === id;
    const muestra = id === "color" || id === "fondo" ? `<span class="muestra" style="background:${A.colorDe(v) || "transparent"}"></span>` : "";
    return `<div>
      <button class="ajuste" aria-expanded="${abierto}" data-accion="desplegar" data-id="${id}">
        <span class="etq"><span>${esc(A.etiqueta(def))}</span></span><span class="valor">${muestra}${esc(v)}${icono("flecha", `class="icono" style="transform:rotate(${abierto ? 270 : 90}deg);width:16px;height:16px"`)}</span></button>
      ${abierto ? `<div class="opciones" role="listbox" aria-label="${esc(A.etiqueta(def))}">${A.opcionesDe(def).map((o) => {
        const sw = (id === "color" || id === "fondo") ? A.colorDe(o) : null;
        const fuente = id === "letra" ? A.fuenteDe(o) : null;
        return `<button class="opcion" role="option" aria-selected="${o === v}" data-accion="elegir" data-id="${id}" data-v="${esc(o)}">
          ${sw ? `<span class="muestra" style="background:${sw};width:18px;height:18px;border-radius:9px"></span>` : ""}
          <span ${fuente ? `style='font-family:${fuente.replace(/'/g, "")}'` : ""}>${esc(o)}</span><span class="marca">${o === v ? "✓" : ""}</span></button>`;
      }).join("")}
      ${id === "color" ? `<label class="opcion">Elegir color propio <input type="color" id="color-propio" value="${A.get("personalizado")[est]}" aria-label="Color propio"></label>` : ""}</div>` : ""}
    </div>`;
  };
  const interruptor = (clave, t, sub) => `<div class="ajuste" style="cursor:default"><span class="etq"><span>${t}</span>${sub ? `<small>${sub}</small>` : ""}</span>
    <button class="interruptor" aria-pressed="${!!A.get(clave)}" aria-label="${t}" data-accion="interruptor" data-clave="${clave}"><span></span></button></div>`;
  const selector = (clave, t, opciones, sub) => `<label class="ajuste"><span class="etq"><span>${t}</span>${sub ? `<small>${sub}</small>` : ""}</span>
    <select data-accion="selector" data-clave="${clave}" style="font:inherit;color:var(--texto-2);border:0;background:transparent;text-align:right;max-width:55%">
      ${opciones.map((o) => `<option ${A.get(clave) === o ? "selected" : ""}>${esc(o)}</option>`).join("")}</select></label>`;
  const enlace = (t, url) => `<a class="ajuste" href="${url}" target="_blank" rel="noopener"><span class="etq"><span>${t}</span></span>${icono("externo")}</a>`;
  const mini = {
    nat: '<span class="mini" style="background:#F4F5F1;border:1px solid #E1E4DC"><i style="height:8px;width:60%;background:#3D6B35"></i><i style="height:40px;background:#DCE8D6"></i><i style="height:6px;width:80%;background:#C9CDC4"></i><i style="height:6px;width:55%;background:#C9CDC4"></i></span>',
    poke: '<span class="mini" style="background:#C3262F"><i style="width:18px;height:18px;border-radius:9px;background:#2F7FD3;border:2px solid #fff"></i><i style="flex:1;background:#C9DDB8;border:2px solid #2B2B2B"></i><i style="height:10px;width:60%;background:#1F5FA8"></i></span>',
    cua: '<span class="mini" style="background:#F2EBDC;border:1px solid #2A2620;flex-direction:row;align-items:flex-end"><i style="width:14px;height:64px;background:#B23A2E;border-radius:7px 7px 2px 2px"></i><span style="flex:1;display:flex;flex-direction:column;gap:9px;padding-bottom:6px"><i style="height:1px;background:#2A2620"></i><i style="height:1px;background:#2A2620"></i><i style="height:1px;background:#2A2620"></i></span></span>',
  };

  vista.innerHTML = `
    <div class="cabecera"><div class="titulos"><h1>Ajustes</h1></div></div>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Estilo de la app</h2>
      <div class="estilos">${Object.entries(A.ESTILOS).map(([k, n]) => `<button class="estilo-tarjeta" aria-pressed="${k === est}" data-accion="estilo" data-e="${k}">${mini[k]}<span>${n}</span></button>`).join("")}</div>
    </section>

    <section class="grupo-ajustes">
      <div class="titulo-seccion" style="margin:0 4px"><h2 class="subtitulo-grupo" style="margin:0">Personalizar «${A.ESTILOS[est]}»</h2><button class="enlace-boton" data-accion="restablecer">Restablecer</button></div>
      <div class="vista-previa"><span class="bloque"></span><span style="display:flex;flex-direction:column;gap:2px;min-width:0">
        <span style="font-weight:700;font-size:1.15em">Drago</span>${nombreSci("Dracaena draco subsp. draco", "(L.) L.", A.get("autoria"))}<span class="pequeno texto-2">Vista previa</span></span></div>
      <div class="ajustes-lista">${A.OPCIONES.map((d) => fila(d.id)).join("")}</div>
      <p class="pequeno texto-2" style="margin:0 4px">Cada estilo guarda su propia personalización. Toca una fila para abrir su menú.</p>
    </section>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Diagrama de tamaño</h2><div class="ajustes-lista">
      <div class="ajuste" style="cursor:default"><span class="etq"><span>Tu altura</span><small>Tu silueta en el diagrama; las especies de menos de 30 cm se comparan con una mano</small></span>
        <span class="paso"><button data-accion="altura" data-d="-1" aria-label="Restar 1 cm">−</button><output id="altura">${A.get("altura")} cm</output><button data-accion="altura" data-d="1" aria-label="Sumar 1 cm">+</button></span></div>
    </div></section>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Nombres y orden</h2><div class="ajustes-lista">
      ${selector("nombres", "Nombres comunes", ["Todos", "Solo el principal"])}
      ${interruptor("autoria", "Mostrar autoría del nombre científico")}
      ${selector("numeracion", "Orden por defecto", ["Taxonómica", "Nombre común", "Nombre científico"], "El número de Pokédex sigue el orden taxonómico")}
    </div></section>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Avistamientos</h2><div class="ajustes-lista">
      ${interruptor("guardarLugar", "Guardar el lugar", "Coordenadas, altitud, isla y municipio")}
      ${selector("precision", "Precisión del lugar", ["Exacta", "Aprox. si amenazada", "Siempre aprox."], "Aproximada = redondeada a 1 km")}
      ${interruptor("guardarTiempo", "Guardar el tiempo meteorológico", "Temperatura, cielo, viento, humedad y lluvia (Open-Meteo)")}
      <button class="ajuste" data-accion="exportar"><span class="etq"><span>Exportar, copia de seguridad o recuperar</span></span>${icono("flecha")}</button>
      <button class="ajuste peligro" data-accion="borrar-todo"><span class="etq"><span>Borrar todos los avistamientos</span></span></button>
    </div><p class="pequeno texto-2" style="margin:0 4px">Los avistamientos y tus fotos se guardan solo en este iPhone. Haz copias de seguridad de vez en cuando.</p></section>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Datos y fotos</h2><div class="ajustes-lista">
      ${interruptor("fotosBiota", "Fotos de Biota", "Se cargan desde su web, con crédito; necesitan conexión")}
      ${interruptor("fotosLibres", "Fotos con licencia libre", "Wikimedia Commons e iNaturalist, con autor y licencia; completan las de Biota")}
      <button class="ajuste" data-accion="sin-conexion"><span class="etq"><span>Guardar todas las fichas para usar sin conexión</span><small id="estado-descarga">${D.getIndice().length.toLocaleString("es")} fichas</small></span>${icono("descargar")}</button>
      <div class="ajuste" style="cursor:default"><span class="etq"><span>Datos de especies</span><small>${meta ? `${meta.taxones.toLocaleString("es")} taxones · actualizados el ${new Date(meta.actualizado).toLocaleDateString("es")}` : ""}</small></span></div>
    </div><p class="pequeno texto-2" style="margin:0 4px">Los datos se actualizan solos el día 3 de cada mes desde Biota y Centinela.</p></section>

    <section class="grupo-ajustes"><h2 class="subtitulo-grupo">Fuentes y créditos</h2><div class="ajustes-lista">
      ${enlace("Banco de Datos de Biodiversidad de Canarias (Biota)", BIOTA)}
      ${enlace("Centinela · especies protegidas", CENTINELA)}
      ${enlace("Normas de uso de Biota", `${BIOTA}/normas`)}
      ${enlace("REDEXOS · especies exóticas invasoras", REDEXOS)}
      ${enlace("iNaturalist · calendario y fotos con licencia Creative Commons", "https://www.inaturalist.org")}
      ${enlace("Wikimedia Commons · fotos con licencia libre", "https://commons.wikimedia.org")}
      ${enlace("Especies Vegetales en Canarias · Gerardo G. Casanova (enlaces)", "https://endemicascanarias.com")}
      ${enlace("GBIF · categoría UICN (Lista Roja 2022-2)", "https://www.gbif.org/dataset/19491596-35ae-4a91-9a98-85cf505f1bd3")}
      ${enlace("FishBase · tamaño y longevidad de peces", "https://www.fishbase.se")}
      ${enlace("AnAge · longevidad y peso de vertebrados", "https://genomics.senescence.info/species/")}
      ${enlace("Wikidata y Wikipedia · tamaños y formas", "https://www.wikidata.org")}
      ${enlace("Open-Meteo · tiempo de los avistamientos", "https://open-meteo.com")}
      ${enlace("OpenStreetMap · mapas y nombres de lugares", "https://www.openstreetmap.org/copyright")}
    </div></section>

    <p class="pequeno texto-2" style="text-align:center;margin:0">Pokédex Canaria · versión ${VERSION}<br>Uso personal. Las fotos pertenecen a sus autores.</p>`;

  vista.querySelectorAll('[data-accion="selector"]').forEach((s) => s.addEventListener("change", () => { A.set(s.dataset.clave, s.value); vistaAjustes(); }));
  const cp = document.getElementById("color-propio");
  if (cp) cp.addEventListener("change", () => { A.fijarPersonalizado(cp.value); estado.abierto = null; vistaAjustes(); });
}

async function guardarSinConexion() {
  const caja = document.getElementById("estado-descarga");
  const cache = await caches.open("pokedex-canaria-fichas");
  const lista = D.getIndice();
  let hechas = 0;
  const lote = 12;
  for (let i = 0; i < lista.length; i += lote) {
    await Promise.all(lista.slice(i, i + lote).map(async (e) => {
      const url = `datos/fichas/${e.c}.json`;
      if (!(await cache.match(url))) { try { await cache.add(url); } catch { /* seguirá */ } }
      hechas++;
    }));
    if (caja) caja.textContent = `Guardando… ${hechas.toLocaleString("es")} de ${lista.length.toLocaleString("es")}`;
  }
  if (caja) caja.textContent = "Todas las fichas guardadas en el iPhone";
  aviso("Fichas guardadas para usar sin conexión");
}

// ------------------------------------------------------------------- eventos

function alPulsar(ev) {
  const x = ev.target.closest("[data-explorar]");
  if (x) {
    ev.preventDefault();
    const { q, ...filtros } = JSON.parse(x.dataset.explorar);
    estado.filtros = { ...FILTROS_VACIOS(), ...filtros };
    estado.q = q || ""; estado.limite = 60;
    if (location.hash.startsWith("#/explorar")) vistaExplorar(); else location.hash = "#/explorar";
    return;
  }
  const b = ev.target.closest("[data-accion], [data-quitar]");
  if (!b) return;
  if (b.dataset.quitar) {
    const [k, v] = JSON.parse(b.dataset.quitar);
    if (Array.isArray(estado.filtros[k])) estado.filtros[k] = estado.filtros[k].filter((y) => y !== v); else estado.filtros[k] = false;
    return vistaExplorar();
  }
  const a = b.dataset.accion;
  if (a === "filtros") abrirFiltros();
  else if (a === "atras") { if (history.length > 1) history.back(); else location.hash = "#/explorar"; }
  else if (a === "compartir") {
    const datos = { title: document.title, url: location.href };
    if (navigator.share) navigator.share(datos).catch(() => {}); else navigator.clipboard?.writeText(location.href).then(() => aviso("Enlace copiado"));
  }
  else if (a === "avistar") abrirNuevoAvistamiento(b.dataset.c);
  else if (a === "ver-avistamiento") verAvistamiento(b.dataset.id);
  else if (a === "modo-vistas") { estado.modoVistas = b.dataset.m; vistaAvistamientos(); }
  else if (a === "exportar") abrirExportar();
  else if (a === "estilo") { A.set("estilo", b.dataset.e); estado.abierto = null; vistaAjustes(); }
  else if (a === "restablecer") { A.restablecer(); estado.abierto = null; vistaAjustes(); }
  else if (a === "desplegar") { estado.abierto = estado.abierto === b.dataset.id ? null : b.dataset.id; vistaAjustes(); }
  else if (a === "elegir") { A.fijar(b.dataset.id, b.dataset.v); if (b.dataset.v !== "Personalizado") estado.abierto = null; vistaAjustes(); }
  else if (a === "altura") {
    const v = Math.min(230, Math.max(90, Number(A.get("altura")) + Number(b.dataset.d)));
    A.set("altura", v); const o = document.getElementById("altura"); if (o) o.textContent = `${v} cm`;
  }
  else if (a === "interruptor") { A.set(b.dataset.clave, !A.get(b.dataset.clave)); b.setAttribute("aria-pressed", String(A.get(b.dataset.clave))); }
  else if (a === "sin-conexion") guardarSinConexion().catch((e) => aviso(e.message));
  else if (a === "borrar-todo") {
    if (confirm("¿Borrar todos tus avistamientos? No se puede deshacer.")) V.borrarTodos().then(async () => { estado.vistas = new Set(); aviso("Avistamientos borrados"); });
  }
}

document.addEventListener("submit", (ev) => {
  const f = ev.target.closest('[data-accion="buscar-inicio"]');
  if (!f) return;
  ev.preventDefault();
  estado.q = new FormData(f).get("q") || "";
  estado.filtros = FILTROS_VACIOS();
  location.hash = "#/explorar";
});

// ---------------------------------------------------------------------- hojas

function abrirHoja() {
  cerrarHojas();
  const fondo = document.createElement("div");
  fondo.className = "hoja";
  fondo.innerHTML = '<div class="panel" role="dialog" aria-modal="true"></div>';
  fondo.addEventListener("click", (ev) => { if (ev.target === fondo) cerrarHojas(); });
  hojas.appendChild(fondo);
  document.body.style.overflow = "hidden";
  return { panel: fondo.querySelector(".panel") };
}
function cerrarHojas() { hojas.innerHTML = ""; document.body.style.overflow = ""; }
document.addEventListener("keydown", (ev) => { if (ev.key === "Escape" && hojas.children.length) cerrarHojas(); });

// Re-aplicar el tema cuando cambia la hora (para «Según la hora del día»)
setInterval(() => A.aplicar(), 10 * 60 * 1000);
void presencia;
