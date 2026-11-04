#!/usr/bin/env bash
# Teste de fumaça do Timbrador: confere a marca, gera documentos curtos e longos, verifica que as travas de estado
# recusam o que devem recusar e exercita assinaturas previstas, projeto, anexos externos, lista mestra, inventário e
# o relatório de condução de projeto.
# Uso: bash testes/fumaca.sh [PASTA_DE_SAIDA]
set -u

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ger="$raiz/skills/timbrador/scripts/gerar_documento.py"
marca="$raiz/testes/marca.teste.json"
saida="${1:-$raiz/saida}"
mkdir -p "$saida"
rm -f "$saida"/*.docx "$saida"/*.pdf

falhas=0
ok()   { printf '  ok    %s\n' "$1"; }
erro() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

# Espera sucesso (código 0).
espera_ok() {
  local nome="$1"; shift
  if "$@" > "$saida/.log" 2>&1; then ok "$nome"; else erro "$nome"; sed 's/^/        /' "$saida/.log"; fi
}

# Espera recusa (código != 0) com uma mensagem contendo o trecho informado.
espera_recusa() {
  local nome="$1" trecho="$2"; shift 2
  if "$@" > "$saida/.log" 2>&1; then
    erro "$nome (deveria ter sido recusado)"
  elif grep -q "$trecho" "$saida/.log"; then
    ok "$nome"
  else
    erro "$nome (recusou pelo motivo errado)"; sed 's/^/        /' "$saida/.log"
  fi
}

echo "== marca =="
espera_ok "checar-marca" python3 "$ger" --checar-marca "$marca"
python3 "$ger" --checar-marca "$marca" | sed 's/^/  /'

echo "== geração =="
espera_ok "curto (CI, MINUTA)"  python3 "$ger" "$raiz/testes/espec-curto.json" --marca "$marca" --saida "$saida"
espera_ok "longo (POP, OFICIAL)" python3 "$ger" "$raiz/testes/espec-longo.json" --marca "$marca" --saida "$saida"

echo "== travas de estado =="
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 - "$raiz/testes/espec-longo.json" "$tmp" <<'PY'
import json, sys, os
espec = json.load(open(sys.argv[1], encoding="utf-8"))
tmp = sys.argv[2]

def grava(nome, **mud):
    d = dict(espec); d.update(mud)
    json.dump(d, open(os.path.join(tmp, nome), "w", encoding="utf-8"), ensure_ascii=False)

grava("sem-aprovador.json", aprovado_por="", data_aprovacao="")
grava("sem-numero.json", numero="")
grava("empresa-incompleta.json", empresa="SEMLG")
grava("obsoleto-sem-motivo.json", estado="OBSOLETO", substituido_por="", motivo_obsoleto="")
PY

espera_recusa "OFICIAL sem aprovador"        "aprovado_por"  python3 "$ger" "$tmp/sem-aprovador.json"      --marca "$marca" --saida "$tmp"
espera_recusa "OFICIAL sem número"           "número"        python3 "$ger" "$tmp/sem-numero.json"         --marca "$marca" --saida "$tmp"
espera_recusa "OFICIAL de empresa incompleta" "razão social" python3 "$ger" "$tmp/empresa-incompleta.json" --marca "$marca" --saida "$tmp"
espera_recusa "OBSOLETO sem substituto/motivo" "substituido_por" python3 "$ger" "$tmp/obsoleto-sem-motivo.json" --marca "$marca" --saida "$tmp"

echo "== empresas e estados =="
python3 - "$raiz/testes/espec-curto.json" "$tmp" <<'PY'
import json, sys, os
espec = json.load(open(sys.argv[1], encoding="utf-8"))
tmp = sys.argv[2]

def grava(nome, **mud):
    d = dict(espec); d.update(mud)
    json.dump(d, open(os.path.join(tmp, nome), "w", encoding="utf-8"), ensure_ascii=False)

envolvidos = [{"nome": "Ana Teste", "cargo": "Diretora", "papel": "Aprovou"},
              {"nome": "Bruno Teste", "cargo": "Gerente", "papel": "Elaborou"}]
grava("grupo.json", empresa="GTESTE", estado="EM_APROVACAO", com_assinatura=True, envolvidos=envolvidos)
grava("cpf.json", empresa="PF", titulo="Comunicação Interna sobre prazos")
grava("aposentada.json", empresa="VELHA")
grava("rascunho.json", estado="RASCUNHO")
grava("tabela-assinaturas.json", com_assinatura=True, envolvidos=envolvidos, assinatura_formato="tabela")
PY
espera_ok "grupo, em aprovação, com assinatura" python3 "$ger" "$tmp/grupo.json" --marca "$marca" --saida "$saida"
grep -q "Assinaturas não entram pelo gerador" "$saida/.log" && ok "aviso: assinatura só pela página" || erro "aviso: assinatura só pela página"
# assinatura entra só pela página: o gerador guarda os envolvidos como previstos na ficha e o corpo sai sem eles
python3 - "$saida" <<'PY2' && ok "assinaturas viram previstas na ficha" || erro "assinaturas viram previstas na ficha"
import sys, glob, zipfile, json, re
z = zipfile.ZipFile(glob.glob(sys.argv[1] + "/GTESTE-*.docx")[0])
f = json.loads(re.search(r">(\{.*\})<", z.read("customXml/item1.xml").decode()).group(1))
# primeiro os envolvidos da caixa, depois as assinaturas do corpo, sem repetir nome
assert [a["nome"] for a in f["assinaturas_previstas"]] == ["Ana Teste", "Bruno Teste", "[definir]"], f.get("assinaturas_previstas")
assert "com_assinatura" not in f and "ANA TESTE" not in z.read("word/document.xml").decode()
PY2
espera_ok "assinaturas em tabela (previstas)"   python3 "$ger" "$tmp/tabela-assinaturas.json" --marca "$marca" --saida "$tmp"
espera_ok "empresa com CPF"                     python3 "$ger" "$tmp/cpf.json" --marca "$marca" --saida "$tmp"
grep -q "Título sem o nome do tipo" "$saida/.log" && ok "título sem o nome do tipo" || erro "título sem o nome do tipo"
python3 - "$tmp" <<'PY' && ok "cabeçalho com CPF" || erro "cabeçalho com CPF"
import sys, glob, zipfile
f = glob.glob(sys.argv[1] + "/PF-*.docx")[0]
assert "CPF 000.000.000-00" in zipfile.ZipFile(f).read("word/header1.xml").decode()
PY
espera_ok "empresa aposentada (aviso)"          python3 "$ger" "$tmp/aposentada.json" --marca "$marca" --saida "$tmp"
grep -q "aposentada" "$saida/.log" && ok "aviso de empresa aposentada" || erro "aviso de empresa aposentada"
espera_ok "estado aposentado (aviso)"           python3 "$ger" "$tmp/rascunho.json" --marca "$marca" --saida "$tmp"
grep -q "aposentado" "$saida/.log" && ok "aviso de estado aposentado" || erro "aviso de estado aposentado"

echo "== ciclo de vida =="
longo="$(ls "$saida"/ACME-POP-*OFICIAL*.docx | head -1)"
espera_ok "--ler (ficha embutida)" python3 "$ger" --ler "$longo" --marca "$marca" --json-saida "$tmp/lido.json"
grep -q "ORIGEM: ficha" "$saida/.log" && ok "origem: ficha" || erro "origem: ficha"
espera_ok "--atualizar (nova versão)" python3 "$ger" --atualizar "$longo" --marca "$marca" --o-que-mudou "Teste." --json-saida "$tmp/nova.json"
python3 - "$tmp/nova.json" <<'PY' && ok "nova versão 2.0-r1 em minuta" || erro "nova versão 2.0-r1 em minuta"
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
assert s["versao"] == "2.0-r1" and s["estado"] == "MINUTA" and s["substitui"].startswith("ACME-POP-ECO-003"), s
PY
espera_ok "gera a nova versão" python3 "$ger" "$tmp/nova.json" --marca "$marca" --saida "$tmp"
# minuta de nova versão: sem --mudanca segue na rodada seguinte; --mudanca correcao conta da versão oficial substituída
minuta_nova="$(ls "$tmp"/ACME-POP-ECO-003_v2.0-r1_MINUTA_*.docx | head -1)"
for caso in "rodada:2.0-r2:" "correcao:1.1-r1:--mudanca correcao" "conteudo:2.0-r2:--mudanca conteudo"; do
  IFS=: read -r nome esperada arg <<< "$caso"
  python3 "$ger" --atualizar "$minuta_nova" --marca "$marca" $arg --o-que-mudou "Teste." --json-saida "$tmp/minuta-$nome.json" > "$saida/.log" 2>&1 &&
  python3 -c "import json,sys; s=json.load(open(sys.argv[1],encoding='utf-8')); sys.exit(0 if (s['versao'],s['estado'])==(sys.argv[2],'MINUTA') and s['substitui'].endswith(' v1.0') else 1)" "$tmp/minuta-$nome.json" "$esperada" \
    && ok "minuta de nova versão ($nome): $esperada" || { erro "minuta de nova versão ($nome): $esperada"; sed 's/^/        /' "$saida/.log"; }
done

echo "== lista mestra =="
mkdir -p "$tmp/pasta"
espera_ok "publica e registra" python3 "$ger" "$raiz/testes/espec-longo.json" --marca "$marca" --saida "$tmp/pasta" --lista "$tmp/pasta"
python3 - "$tmp/pasta/lista-mestra.json" <<'PY' && ok "registro na lista" || erro "registro na lista"
import json, sys
l = json.load(open(sys.argv[1], encoding="utf-8"))
assert l["lista_mestra"] == "Grupo de Teste" and l["padrao"] == "ACME-POL-ADM-001"
assert [d["codigo"] for d in l["documentos"]] == ["ACME-POP-ECO-003"], l
PY
python3 - "$raiz/testes/espec-longo.json" "$tmp/repetido.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); d["titulo"] = "Outro assunto com o mesmo número"
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY
espera_recusa "número repetido" "já é" python3 "$ger" "$tmp/repetido.json" --marca "$marca" --saida "$tmp/pasta" --lista "$tmp/pasta"
espera_ok "--inventariar --conferir" python3 "$ger" --inventariar "$tmp/pasta" --marca "$marca" --conferir

echo "== projeto e anexos externos =="
mkdir -p "$tmp/anx"
printf 'conversa exportada\n' > "$tmp/anx/conversa.xml"; printf 'a;b\n1;2\n' > "$tmp/anx/planilha.csv"
python3 - "$raiz/testes/espec-curto.json" "$raiz/testes/espec-longo.json" "$tmp" <<'PY2'
import json, sys, os
curto = json.load(open(sys.argv[1], encoding="utf-8")); longo = json.load(open(sys.argv[2], encoding="utf-8")); tmp = sys.argv[3]
def grava(nome, base, **mud):
    d = json.loads(json.dumps(base)); d.update(mud)
    json.dump(d, open(os.path.join(tmp, nome), "w", encoding="utf-8"), ensure_ascii=False)
grava("pln-sem-projeto.json", longo, tipo="PLN", numero=7, titulo="Abertura da loja")
grava("com-projeto.json", curto, projeto="Loja Nova", titulo="Escala do projeto")
grava("com-anexos.json", curto, titulo="Registro da conversa com o cliente")
PY2
espera_recusa "plano sem projeto"                   "Plano é sempre de um projeto" python3 "$ger" "$tmp/pln-sem-projeto.json" --marca "$marca" --saida "$tmp"
espera_ok     "documento de projeto"                python3 "$ger" "$tmp/com-projeto.json" --marca "$marca" --saida "$tmp/proj"
python3 - "$tmp/proj" <<'PY2' && ok "projeto na ficha" || erro "projeto na ficha"
import sys, glob, zipfile
assert '"projeto": "Loja Nova"' in zipfile.ZipFile(glob.glob(sys.argv[1] + "/*.docx")[0]).read("customXml/item1.xml").decode()
PY2
espera_ok     "anexos externos (--anexo)"           python3 "$ger" "$tmp/com-anexos.json" --marca "$marca" --saida "$tmp/anxdoc" --anexo "$tmp/anx/conversa.xml" --anexo "$tmp/anx/planilha.csv" --anexo "$tmp/anx/conversa.xml"
grep -q "arquivo repetido" "$saida/.log" && ok "anexo repetido entra uma vez" || erro "anexo repetido entra uma vez"
python3 - "$tmp/anxdoc" "$tmp/anx/conversa.xml" <<'PY2' && ok "pasta do documento com os anexos e SHA-256" || erro "pasta do documento com os anexos e SHA-256"
import sys, glob, zipfile, hashlib, os
pasta = glob.glob(sys.argv[1] + "/ACME-CI-RH-012-2026")[0]   # a pasta do documento é o código
nomes = sorted(os.listdir(pasta)); docx = [n for n in nomes if n.endswith(".docx")]
assert [n for n in nomes if not n.endswith(".docx")] == ["Anexo 01 – conversa.xml", "Anexo 02 – planilha.csv"] and len(docx) == 1, nomes
doc = zipfile.ZipFile(os.path.join(pasta, docx[0])).read("word/document.xml").decode()
assert hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest() in doc and "Anexo 02 – planilha.csv" in doc
PY2
anx="$(ls "$tmp"/anxdoc/*/ACME-*.docx)"
espera_ok     "nova versão leva os anexos (--atualizar)" python3 "$ger" --atualizar "$anx" --marca "$marca" --o-que-mudou "Texto revisto." --json-saida "$tmp/anx-nova.json"
espera_ok     "gera a nova versão com os anexos conferidos" python3 "$ger" "$tmp/anx-nova.json" --marca "$marca" --saida "$tmp/anxdoc2"
printf 'alterado\n' > "$(ls -d "$tmp"/anxdoc/*/)Anexo 01 – conversa.xml"
python3 - "$tmp/anx-nova.json" "$tmp/anx-adulterado.json" <<'PY2'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY2
espera_recusa "anexo alterado na pasta é recusado"   "mesmo conteúdo (SHA-256)" python3 "$ger" "$tmp/anx-adulterado.json" --marca "$marca" --saida "$tmp/anxdoc3"

echo "== inventário: Obsoletos e projetos =="
mkdir -p "$tmp/inv/Obsoletos" "$tmp/inv/Projetos/Loja Nova"
python3 - "$raiz/testes/espec-curto.json" "$tmp" <<'PY2'
import json, sys, os
d = json.load(open(sys.argv[1], encoding="utf-8")); tmp = sys.argv[2]
d.update(estado="OFICIAL", numero=5, aprovado_por="Fulano de Tal", data_aprovacao="18/09/2026", titulo="Horário de verão", corpo=[{"t": "p", "texto": "Texto."}])
json.dump(d, open(os.path.join(tmp, "inv-oficial.json"), "w", encoding="utf-8"), ensure_ascii=False)
d.update(projeto="Loja Nova", numero=6, titulo="Escala da loja")
json.dump(d, open(os.path.join(tmp, "inv-projeto.json"), "w", encoding="utf-8"), ensure_ascii=False)
PY2
python3 "$ger" "$tmp/inv-oficial.json" --marca "$marca" --saida "$tmp/inv" > /dev/null 2>&1
python3 "$ger" --obsoletar "$(ls "$tmp"/inv/ACME-CI-RH-005-*.docx)" --substituido-por "ACME-CI-RH-009/2026 v1.0" --marca "$marca" --saida "$tmp/inv/Obsoletos" > /dev/null 2>&1
python3 "$ger" "$tmp/inv-projeto.json" --marca "$marca" --saida "$tmp/inv" > /dev/null 2>&1
espera_ok "--inventariar com Obsoletos e projeto fora da pasta" python3 "$ger" --inventariar "$tmp/inv" --marca "$marca" --conferir
grep -q "já tem cópia obsoleta" "$saida/.log" && ok "alerta: oficial com cópia obsoleta" || erro "alerta: oficial com cópia obsoleta"
grep -q 'é do projeto "Loja Nova"' "$saida/.log" && ok "alerta: documento de projeto fora da pasta" || erro "alerta: documento de projeto fora da pasta"

echo "== relatório de condução =="
# REL com rodadas: número herdado do plano oficial do projeto, uma rodada por versão, SHA-256 das rodadas na lista
mkdir -p "$tmp/rel"
python3 - "$raiz/testes" "$tmp" <<'PY2'
import json, sys, os
base, tmp = sys.argv[1], sys.argv[2]
plano = {"empresa": "ACME", "tipo": "PLN", "area": "ECO", "numero": 1, "titulo": "Loja nova no marketplace", "projeto": "Loja Nova",
         "estado": "OFICIAL", "aprovado_por": "Fulano de Tal", "data_aprovacao": "01/10/2026", "data_emissao": "01/10/2026",
         "elaborado_por": "Fulano de Tal", "corpo": [{"t": "h1", "texto": "Objetivo"}, {"t": "p", "texto": "Abrir a loja."}]}
json.dump(plano, open(os.path.join(tmp, "rel-plano.json"), "w", encoding="utf-8"), ensure_ascii=False)
rel = json.load(open(os.path.join(base, "espec-rel.json"), encoding="utf-8"))
json.dump(dict(rel, projeto="Sem Plano"), open(os.path.join(tmp, "rel-sem-plano.json"), "w", encoding="utf-8"), ensure_ascii=False)
json.dump(dict(rel, corpo=[{"t": "h1", "texto": "Identificação"}, {"t": "p", "texto": "Projeto Loja Nova."}]),
          open(os.path.join(tmp, "rel-sem-quadro.json"), "w", encoding="utf-8"), ensure_ascii=False)
rodadas = {"r1": {"data": "12/10/2026", "feito": "50 anúncios cadastrados.", "avanco": "sim",
                  "compromisso": {"oque": "Ativar frete", "quem": "Logística", "ate": "19/10/2026"}},
           "rx": {"n": 7, "data": "13/10/2026", "feito": "x", "avanco": "sim", "compromisso": {"oque": "a", "quem": "b", "ate": "c"}},
           "fim": {"tipo": "encerramento", "data": "20/10/2026", "feito": "Loja aberta.", "termo": "ACME-TER-ECO-002/2026", "situacao": "concluído"},
           "depois": {"data": "21/10/2026", "feito": "x", "avanco": "sim", "compromisso": {"oque": "a", "quem": "b", "ate": "c"}}}
for k, v in rodadas.items():
    json.dump(v, open(os.path.join(tmp, f"rodada-{k}.json"), "w", encoding="utf-8"), ensure_ascii=False)
PY2
docs="$tmp/rel"; rel_vigente() { ls "$docs"/ACME-REL-ECO-001_v*_OFICIAL_*.docx | sort -V | tail -1; }
espera_ok     "plano oficial do projeto"            python3 "$ger" "$tmp/rel-plano.json" --marca "$marca" --saida "$docs" --lista "$docs"
espera_recusa "projeto sem plano oficial"           "não tem plano"  python3 "$ger" "$tmp/rel-sem-plano.json" --marca "$marca" --saida "$tmp" --lista "$docs"
espera_recusa "relatório sem a lista mestra"        "precisa da lista mestra" python3 "$ger" "$raiz/testes/espec-rel.json" --marca "$marca" --saida "$tmp"
espera_ok     "abertura (v1.0, número do plano)"    python3 "$ger" "$raiz/testes/espec-rel.json" --marca "$marca" --saida "$docs" --lista "$docs"
espera_recusa "abertura repetida"                   "já existe"      python3 "$ger" "$raiz/testes/espec-rel.json" --marca "$marca" --saida "$tmp" --lista "$docs"
espera_ok     "prepara a rodada 1 (--rodada)"       python3 "$ger" --marca "$marca" --atualizar "$(rel_vigente)" --rodada "$tmp/rodada-r1.json" --json-saida "$tmp/rel-v11.json"
espera_ok     "publica a v1.1"                      python3 "$ger" "$tmp/rel-v11.json" --marca "$marca" --saida "$docs" --lista "$docs"
espera_recusa "rodada fora de ordem"                "rodada nova é a 2" python3 "$ger" --marca "$marca" --atualizar "$(rel_vigente)" --rodada "$tmp/rodada-rx.json"
espera_recusa "rodada a partir de versão antiga"    "já registra 2"  python3 "$ger" "$tmp/rel-v11.json" --marca "$marca" --saida "$tmp" --lista "$docs"
espera_recusa "--obsoletar recusa o relatório"      "não tem cópia obsoleta" python3 "$ger" --marca "$marca" --obsoletar "$(rel_vigente)" --substituido-por x --saida "$tmp"
python3 - "$(rel_vigente)" "$tmp/rel-adulterado.docx" <<'PY2'
import sys, zipfile
zi, zo = zipfile.ZipFile(sys.argv[1]), zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED)
for i in zi.infolist():
    b = zi.read(i.filename)
    if i.filename.startswith("customXml/item") or i.filename == "word/document.xml":
        b = b.replace("50 anúncios".encode(), "60 anúncios".encode())
    zo.writestr(i, b)
zo.close()
PY2
python3 "$ger" --marca "$marca" --atualizar "$tmp/rel-adulterado.docx" --rodada "$tmp/rodada-fim.json" --json-saida "$tmp/rel-adulterado.json" > /dev/null 2>&1
espera_recusa "rodada publicada alterada"           "não confere com a registrada" python3 "$ger" "$tmp/rel-adulterado.json" --marca "$marca" --saida "$tmp" --lista "$docs"
espera_ok     "encerramento (v1.2)"                 python3 "$ger" --marca "$marca" --atualizar "$(rel_vigente)" --rodada "$tmp/rodada-fim.json" --json-saida "$tmp/rel-v12.json"
espera_ok     "publica o encerramento"              python3 "$ger" "$tmp/rel-v12.json" --marca "$marca" --saida "$docs" --lista "$docs"
espera_recusa "encerrado não recebe rodada"         "foi encerrado"  python3 "$ger" --marca "$marca" --atualizar "$(rel_vigente)" --rodada "$tmp/rodada-depois.json"
if python3 -c "
import json,sys; d=[x for x in json.load(open(sys.argv[1]))['documentos'] if x['codigo']=='ACME-REL-ECO-001'][0]
sys.exit(0 if d['versao']=='1.2' and len(d['rodadas_sha256'])==3 and d['plano']=='ACME-PLN-ECO-001' else 1)" "$docs/lista-mestra.json"; then
  ok "lista: v1.2, plano e 3 SHA-256"; else erro "lista do relatório"; fi
if ls "$docs" | grep -q OBSOLETO; then erro "relatório gerou cópia obsoleta"; else ok "sem cópia obsoleta"; fi
espera_ok     "inventário confere as rodadas"       python3 "$ger" --inventariar "$docs" --marca "$marca" --conferir
mkdir -p "$tmp/rel2"
cp "$(ls "$docs"/ACME-PLN-*.docx)" "$tmp/rel2/"
python3 "$ger" --inventariar "$tmp/rel2" --marca "$marca" > /dev/null 2>&1
espera_ok     "corpo sem o Quadro de rodadas: a seção entra no fim" python3 "$ger" "$tmp/rel-sem-quadro.json" --marca "$marca" --saida "$tmp/rel2" --lista "$tmp/rel2"
python3 - "$tmp/rel2" <<'PY2' && ok "Quadro de rodadas criado" || erro "Quadro de rodadas criado"
import sys, glob, zipfile
doc = zipfile.ZipFile(glob.glob(sys.argv[1] + "/ACME-REL-*.docx")[0]).read("word/document.xml").decode()
assert "Rodadas do projeto" in doc and "Cadastrar os 50 primeiros anúncios" in doc
PY2
cp "$(rel_vigente)" "$saida/"

echo "== PDF =="
if python3 -c "import sys; sys.path.insert(0, '$(dirname "$ger")'); import gerar_documento as g; sys.exit(0 if g.comando_soffice() else 1)"; then
  espera_ok "--pdf" python3 "$ger" "$raiz/testes/espec-curto.json" --marca "$marca" --saida "$saida" --pdf
  ls "$saida"/ACME-CI-*.pdf > /dev/null 2>&1 && ok "PDF gravado" || erro "PDF gravado"
else
  echo "  (LibreOffice ausente: PDF não testado)"
fi

echo "== XML bem formado =="
for f in "$saida"/*.docx; do
  if python3 - "$f" <<'PY'
import sys, zipfile
from xml.dom.minidom import parseString
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if n.endswith(".xml") or n.endswith(".rels"):
        parseString(z.read(n))
PY
  then ok "$(basename "$f")"; else erro "$(basename "$f")"; fi
done

rm -f "$saida/.log"
echo
if [ "$falhas" -eq 0 ]; then echo "Tudo certo. Saída em: $saida"; else echo "$falhas falha(s)."; fi
exit $((falhas > 0))
