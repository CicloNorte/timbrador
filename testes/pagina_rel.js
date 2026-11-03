// Relatório de condução pela página (pagina/timbrador.html num DOM do jsdom), sobre arquivos do gerador.
// Uso: node testes/pagina_rel.js MARCA_COM_LOGOS_EMBUTIDOS REL_v1.1.docx REL_ENCERRADO.docx LISTA.json PASTA_SAIDA
// Confere que a página lê o quadro e o SHA-256 das rodadas como o gerador, recusa rodada no relatório encerrado
// e em linha alterada, e grava em PASTA_SAIDA/rel.docx a v1.2 feita a partir da v1.1 com uma rodada nova.
const fs = require("fs"), path = require("path");
const { JSDOM, VirtualConsole } = require("jsdom");
const [marcaArq, v11, encerrado, listaArq, saida] = process.argv.slice(2);
const vc = new VirtualConsole(), erros = [];
vc.on("jsdomError", e => erros.push("erro na página: " + e.message));
const dom = new JSDOM(fs.readFileSync(path.join(__dirname, "..", "pagina", "timbrador.html"), "utf8"), {
  runScripts: "dangerously", url: "https://timbrador.local/", virtualConsole: vc,
  beforeParse(w) { Object.assign(w, { Blob, File, TextEncoder, TextDecoder, DecompressionStream, Response }); } });
const w = dom.window, $ = id => w.document.getElementById(id);
(async () => {
  $("marca-texto").value = fs.readFileSync(marcaArq, "utf8");
  $("marca-usar").click();
  if (w.document.body.classList.contains("sem-marca")) throw new Error("a página não aceitou a marca: " + $("msg").textContent);
  const buf = f => { const b = fs.readFileSync(f); return b.buffer.slice(b.byteOffset, b.byteOffset + b.length); };
  const teste = w.eval(`(async (v11, fim, lista) => {
    const falhas = [], copia = o => JSON.parse(JSON.stringify(o));
    const reg = lista.documentos.find(d => d.codigo === "ACME-REL-ECO-001");
    const e = await lerDocx(fim);
    if (conferirQuadroRodadas(e.blocos, e.ficha.rodadas).length) falhas.push("quadro do relatório do gerador não confere com a ficha");
    if ((await digitaisRodadas(e.ficha.rodadas)).join() !== reg.rodadas_sha256.join()) falhas.push("SHA-256 das rodadas difere do gerador");
    const nova = { n: 3, tipo: "rodada", data: "21/10/2026", feito: "x", avanco: "sim", compromisso: { oque: "a", quem: "b", ate: "c" } };
    let s = { ...copia(e.ficha), rodadas: e.ficha.rodadas.concat([nova]) }; delete s.codigo;
    if (!(await regrasRel(s, lista, e.ficha)).erros.some(m => m.includes("foi encerrado"))) falhas.push("aceitou rodada no relatório encerrado");
    // a partir da v1.1, com a lista como estava na v1.1
    const a = await lerDocx(v11), l11 = copia(lista), r11 = l11.documentos.find(d => d.codigo === "ACME-REL-ECO-001");
    r11.rodadas_sha256 = r11.rodadas_sha256.slice(0, 2); r11.versao = "1.1"; delete r11.encerrado_por;
    const r2 = { n: 2, tipo: "rodada", data: "15/10/2026", feito: "Frete ainda não ativado.", avanco: "nao", travou: "contrato", depende: "Fulano",
      compromisso: { oque: "Ativar frete", quem: "Logística", ate: "22/10/2026" } };
    const alterada = copia(a.ficha); alterada.rodadas[1].feito = "60 anúncios cadastrados.";
    s = { ...copia(alterada), rodadas: alterada.rodadas.concat([r2]) }; delete s.codigo;
    if (!(await regrasRel(s, l11, alterada)).erros.some(m => m.includes("não confere com a registrada"))) falhas.push("aceitou rodada publicada alterada");
    s = { ...copia(a.ficha), rodadas: a.ficha.rodadas.concat([r2]), estado: "OFICIAL", data_aprovacao: r2.data, data_emissao: r2.data }; delete s.codigo;
    s.historico = historicoAtualizado(a.ficha, versaoRodada(a.ficha.versao), resumoRodada(r2), s.aprovado_por, r2.data);
    const rr = await regrasRel(s, l11, a.ficha);
    if (rr.erros.length) return { falhas: falhas.concat(rr.erros) };
    const v = validar(s);
    if (v.erros.length) return { falhas: falhas.concat(v.erros.map(x => x.msg)) };
    const u = new Uint8Array(await gerarDocx(s, corpoRel(a.blocos, s)).arrayBuffer());
    return { falhas, bytes: Array.from(u), versao: s.versao, codigo: s.codigo };
  })`);
  const r = await teste(buf(v11), buf(encerrado), w.JSON.parse(fs.readFileSync(listaArq, "utf8")));
  erros.push(...(r.falhas || []));
  if (r.bytes) fs.writeFileSync(path.join(saida, "rel.docx"), Buffer.from(r.bytes));
  if (r.bytes && (r.versao !== "1.2" || r.codigo !== "ACME-REL-ECO-001")) erros.push(`gerou ${r.codigo} v${r.versao}`);
  if (erros.length) { console.error(erros.join("\n")); process.exit(1); }
  console.log(path.join(saida, "rel.docx"));
})().catch(e => { console.error(e.message); process.exit(1); });
