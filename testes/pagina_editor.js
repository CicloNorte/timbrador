// Configura pelo editor da página a mesma marca de testes/marca.teste.json (logo por upload, CPF, grupo,
// empresa inativa, áreas e tipos), salva e exporta o marca.json. Uso: node testes/pagina_editor.js LOGO SAIDA
const fs = require("fs"), path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");
const [logoArq, saida] = process.argv.slice(2), pagina = path.join(__dirname, "..", "pagina", "timbrador.html");
const vc = new VirtualConsole(); vc.on("jsdomError", e => { if (!/navigation/.test(e.message)) { console.error("erro na página:", e.message); process.exitCode = 1; } });
const blobs = [];
const dom = new JSDOM(fs.readFileSync(pagina, "utf8"), { runScripts: "dangerously", url: "https://timbrador.local/", virtualConsole: vc,
  beforeParse(w) { Object.assign(w, { Blob, File, TextEncoder, TextDecoder }); w.URL.createObjectURL = b => { blobs.push(b); return "blob:x"; }; w.URL.revokeObjectURL = () => {}; } });
const w = dom.window, d = w.document, $ = id => d.getElementById(id), espera = ms => new Promise(r => setTimeout(r, ms));
const set = (el, v) => { el.value = v; el.dispatchEvent(new w.Event("input", { bubbles: true })); el.dispatchEvent(new w.Event("change", { bubbles: true })); };
const marcar = (el, v) => { if (el.checked !== v) el.click(); };
(async () => {
  console.log("1ª visita: sem-marca =", d.body.classList.contains("sem-marca"), "| botão:", $("marca-editar").textContent);
  $("marca-editar").click();
  console.log("editor aberto:", !$("editor-marca").hidden, "| formulário escondido:", d.body.classList.contains("editando"), "| empresas no editor:", $("em-empresas").children.length);
  // validação: empresa sem sigla
  $("em-salvar").click(); console.log("sem sigla →", $("em-msg").textContent);
  set($("em-organizacao"), "Grupo de Teste"); set($("em-politica"), "ACME-POL-ADM-001");
  const emp = [
    { sigla: "acme", marca: "Acme", razao: "Acme Comércio de Testes Ltda", rotulo: "CNPJ", doc: "00.000.000/0001-00", cidade: "Campinas – SP", cor: "1F3864", logo: true },
    { sigla: "SEMLG", marca: "Sem Logo", razao: "", rotulo: "CNPJ", doc: "", cidade: "Campinas – SP", cor: "8C3B2E" },
    { sigla: "PF", marca: "Consultoria PF", razao: "Maria Exemplo", rotulo: "CPF", doc: "000.000.000-00", cidade: "Campinas – SP", cor: "2E6B30", logo: true },
    { sigla: "VELHA", marca: "Marca Antiga", razao: "Antiga Ltda", rotulo: "CNPJ", doc: "00.000.000/0002-00", cidade: "Campinas – SP", cor: "555555", ativa: false },
    { sigla: "GTESTE", marca: "Grupo de Teste", grupo: true, cidade: "Campinas – SP", cor: "4D4D4D" }];
  for (let i = 0; i < emp.length; i++) {
    if (i) $("em-add-empresa").click();
    const c = $("em-empresas").children[i], q = s => c.querySelector(s), e = emp[i];
    set(q(".e-sigla"), e.sigla); set(q(".e-marca"), e.marca); set(q(".e-cidade"), e.cidade); set(q(".e-cor"), e.cor);
    marcar(q(".e-grupo"), !!e.grupo); marcar(q(".e-ativa"), e.ativa !== false);
    if (!e.grupo) { set(q(".e-razao"), e.razao); set(q(".e-rotulo"), e.rotulo); set(q(".e-documento"), e.doc); }
    if (e.logo) { const f = new File([fs.readFileSync(logoArq)], "logo.png", { type: "image/png" });
      Object.defineProperty(q(".e-logo-arq"), "files", { value: [f], configurable: true }); q(".e-logo-arq").dispatchEvent(new w.Event("change")); await espera(100); }
  }
  set($("em-padrao"), "ACME");
  for (const l of $("em-areas").children) marcar(l.querySelector("input"), ["ADM", "RH", "ECO", "TI"].some(a => l.textContent.includes(`(${a})`)));
  for (const l of $("em-tipos").children) marcar(l.querySelector("input"), ["RO", "CI", "TER", "PRO", "POP", "POL", "REG", "PLN"].some(a => l.textContent.includes(`(${a})`)));
  // área extra com sigla inválida e depois válida
  set($("em-nova-area-sigla"), "J1"); set($("em-nova-area-nome"), "Jurídico 1"); $("em-add-area").click(); console.log("área inválida →", $("em-msg").textContent);
  $("em-salvar").click();
  console.log("salvo:", $("editor-marca").hidden, "|", $("msg").textContent, "|", $("marca-estado").textContent);
  console.log("selects: empresas", [...$("empresa").options].map(o => o.value).join(","), "| áreas", [...$("area").options].map(o => o.value).join(","), "| tipos", [...$("tipo").querySelectorAll("option")].map(o => o.value).join(","));
  console.log("guardado no navegador:", !!w.localStorage.getItem("timbrador.marca"));
  $("marca-exportar").click(); await espera(50);
  const exp = await blobs[blobs.length - 1].text(); fs.mkdirSync(saida, { recursive: true }); fs.writeFileSync(path.join(saida, "marca-exportada.json"), exp);
  // reabrir e salvar sem mexer: a marca não muda
  $("marca-editar").click();
  console.log("reaberto: org =", $("em-organizacao").value, "| ACME logo:", !$("em-empresas").children[0].querySelector(".e-logo-img").hidden, "| PF rótulo:", $("em-empresas").children[2].querySelector(".e-doc-rot").textContent, "| GTESTE grupo:", $("em-empresas").children[4].classList.contains("e-grupo"));
  $("em-salvar").click(); $("marca-exportar").click(); await espera(50);
  const igual = (await blobs[blobs.length - 1].text()) === exp;
  console.log("salvar de novo sem mexer → igual:", igual);
  if (!igual || $("editor-marca").hidden === false || !w.localStorage.getItem("timbrador.marca")) process.exitCode = 1;
})().catch(e => { console.error(e); process.exit(1); });
