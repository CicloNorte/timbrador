// Versão da atualização: abre pagina/timbrador.html num DOM (jsdom) e imprime, em JSON, a versão e o estado que
// sugerirAtualizacao dá para cada caso (ficha anterior + tipo de alteração). pagina.sh compara com o gerador.
// Uso: node testes/pagina_versao.js CASOS.json
const fs = require("fs"), path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");
const vc = new VirtualConsole();
vc.on("jsdomError", e => { console.error("erro na página:", e.message); process.exitCode = 1; });
const dom = new JSDOM(fs.readFileSync(path.join(__dirname, "..", "pagina", "timbrador.html"), "utf8"), {
  runScripts: "dangerously", url: "https://timbrador.local/", virtualConsole: vc,
  beforeParse(w) { Object.assign(w, { Blob, File, TextEncoder, TextDecoder, DecompressionStream, CompressionStream, Response }); } });
const sugerir = dom.window.eval("sugerirAtualizacao");
const casos = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
console.log(JSON.stringify(casos.map(([ficha, mudanca]) => {
  const r = sugerir(dom.window.JSON.parse(JSON.stringify(ficha)), mudanca);
  return { versao: r.versao, estado: r.estado };
})));
