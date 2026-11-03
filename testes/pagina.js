// Abre pagina/timbrador.html num DOM (jsdom), cola o marca.json e gera cada especificação pelo núcleo da página,
// do jeito que o botão Gerar faz. Uso: node testes/pagina.js MARCA_COM_LOGOS_EMBUTIDOS SAIDA espec.json [...]
const fs = require("fs"), path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");
const [marcaArq, saida, ...specs] = process.argv.slice(2);
const vc = new VirtualConsole();
vc.on("jsdomError", e => { console.error("erro na página:", e.message); process.exitCode = 1; });
const dom = new JSDOM(fs.readFileSync(path.join(__dirname, "..", "pagina", "timbrador.html"), "utf8"), {
  runScripts: "dangerously", url: "https://timbrador.local/", virtualConsole: vc,
  beforeParse(w) { Object.assign(w, { Blob, File, TextEncoder, TextDecoder, DecompressionStream, Response }); } });
const w = dom.window, $ = id => w.document.getElementById(id);
(async () => {
  $("marca-texto").value = fs.readFileSync(marcaArq, "utf8");
  $("marca-usar").click();
  if (w.document.body.classList.contains("sem-marca")) throw new Error("a página não aceitou a marca: " + $("msg").textContent);
  fs.mkdirSync(saida, { recursive: true });
  // o mesmo caminho do gerar() do gerador: relatório de condução, assinaturas adiadas, anexos e assinaturas
  const gerar = w.eval(`(spec => { const { erros, avisos } = validar(spec); if (erros.length) return { erros };
    for (const b of spec.corpo || []) if (b.t === "local_data" && !b.data) b.data = spec.data_emissao;
    if (spec.tipo === "REL" && (spec.rodadas || []).length) spec.corpo = corpoRel(spec.corpo, spec);
    if (spec.estado !== "OBSOLETO") adiarAssinaturas(spec);
    const blob = gerarDocx(spec, montarAssinaturas(montarAnexos(spec.corpo || [], spec), spec)); return { blob, nome: nomeArquivo(spec) }; })`);
  for (const arq of specs) {
    const r = gerar(w.JSON.parse(fs.readFileSync(arq, "utf8")));
    if (r.erros) throw new Error(`${arq}: ${r.erros.map(e => e.msg).join(" ")}`);
    fs.writeFileSync(path.join(saida, r.nome), Buffer.from(await r.blob.arrayBuffer()));
    console.log(r.nome);
  }
})().catch(e => { console.error(e.message); process.exit(1); });
