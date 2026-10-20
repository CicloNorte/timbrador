#!/usr/bin/env bash
# Teste de fumaça do Timbrador: confere a marca, gera um documento curto e um
# longo e verifica que as travas de estado recusam o que devem recusar.
# Uso: bash testes/fumaca.sh [PASTA_DE_SAIDA]
set -u

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ger="$raiz/skills/timbrador/scripts/gerar_documento.py"
marca="$raiz/testes/marca.teste.json"
saida="${1:-$raiz/saida}"
mkdir -p "$saida"

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
espera_ok "assinaturas em tabela"               python3 "$ger" "$tmp/tabela-assinaturas.json" --marca "$marca" --saida "$tmp"
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
