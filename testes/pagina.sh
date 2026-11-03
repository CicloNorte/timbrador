#!/usr/bin/env bash
# Página × gerador: gera as especificações de teste pelos dois caminhos e compara os .docx parte a parte
# (XML canonizado, mídia byte a byte). Precisa de Node e do jsdom (npm install jsdom; NODE_PATH se for global).
# Uso: bash testes/pagina.sh [PASTA_DE_SAIDA]
set -u
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ger="$raiz/skills/timbrador/scripts/gerar_documento.py"
saida="${1:-$raiz/saida/pagina}"
if ! command -v node >/dev/null || ! node -e 'require("jsdom")' 2>/dev/null; then
  echo "pulado: precisa de node e jsdom (npm install jsdom)"; exit 0
fi
rm -rf "$saida"; mkdir -p "$saida/pagina" "$saida/gerador"
python3 "$ger" --embutir-logos "$raiz/testes/marca.teste.json" --saida "$saida/marca.json" >/dev/null || exit 1
specs=("$raiz/testes/espec-curto.json" "$raiz/testes/espec-longo.json")
node "$raiz/testes/pagina.js" "$saida/marca.json" "$saida/pagina" "${specs[@]}" >/dev/null || { echo "  FALHA página não gerou"; exit 1; }
# sem LibreOffice para o gerador: a página não numera o sumário, então o gerador também não
for s in "${specs[@]}"; do TIMBRADOR_SOFFICE=false python3 "$ger" "$s" --marca "$raiz/testes/marca.teste.json" --saida "$saida/gerador" >/dev/null; done
# marca configurada pelo editor da página (exportada): tem de dar os mesmos documentos
node "$raiz/testes/pagina_editor.js" "$raiz/skills/timbrador/assets/logo-exemplo.png" "$saida/editor" > "$saida/editor.log" 2>&1 \
  || { echo "  FALHA editor da marca"; sed 's/^/        /' "$saida/editor.log"; exit 1; }
node "$raiz/testes/pagina.js" "$saida/editor/marca-exportada.json" "$saida/editor/pagina" "${specs[@]}" >/dev/null || { echo "  FALHA página com a marca do editor"; exit 1; }
# marca com "visual" (fontes embutidas e cores): uma TrueType do sistema faz o papel das fontes da organização
ttf="$(fc-match -f '%{file}' 'DejaVu Serif' 2>/dev/null)"
if [ -n "$ttf" ] && [ "${ttf##*.}" = "ttf" ]; then
  python3 - "$saida/marca.json" "$ttf" "$saida/visual/marca.json" <<'PY2'
import json, sys, os, shutil
cfg = json.load(open(sys.argv[1], encoding="utf8")); os.makedirs(os.path.dirname(sys.argv[3]), exist_ok=True)
shutil.copy(sys.argv[2], os.path.join(os.path.dirname(sys.argv[3]), "fonte.ttf"))
cfg["visual"] = {"fonte_texto": "Teste Texto", "fonte_titulo": "Teste Titulo", "cor_texto": "1C2533", "cor_titulo": "233F61",
                 "cor_secundaria": "5A6372", "cor_realce": "DBE4EF",
                 "fontes": [{"familia": "Teste Texto", "estilo": "regular", "arquivo": "fonte.ttf"},
                            {"familia": "Teste Titulo", "estilo": "negrito", "arquivo": "fonte.ttf"}]}
json.dump(cfg, open(sys.argv[3], "w", encoding="utf8"), ensure_ascii=False)
PY2
  python3 "$ger" --embutir-logos "$saida/visual/marca.json" --saida "$saida/visual/marca_portatil.json" >/dev/null || exit 1
  node "$raiz/testes/pagina.js" "$saida/visual/marca_portatil.json" "$saida/visual/pagina" "${specs[@]}" >/dev/null || { echo "  FALHA página com visual"; exit 1; }
  for s in "${specs[@]}"; do TIMBRADOR_SOFFICE=false python3 "$ger" "$s" --marca "$saida/visual/marca.json" --saida "$saida/visual/gerador" >/dev/null; done
else
  echo "  pulado: visual (sem DejaVu Serif .ttf no sistema)"
fi
falhas=0
for f in "$saida"/visual/pagina/*.docx; do
  [ -e "$f" ] || continue
  n="$(basename "$f")"
  if python3 "$raiz/testes/comparar_docx.py" "$f" "$saida/visual/gerador/$n" > "$saida/.log" &&
     python3 -c "import zipfile,sys; sys.exit('word/fontTable.xml' not in zipfile.ZipFile(sys.argv[1]).namelist())" "$f"; then echo "  ok    com visual e fontes embutidas: $n"
  else echo "  FALHA com visual: $n"; sed 's/^/        /' "$saida/.log"; falhas=$((falhas + 1)); fi
done
for f in "$saida"/editor/pagina/*.docx; do
  n="$(basename "$f")"
  if python3 "$raiz/testes/comparar_docx.py" "$f" "$saida/gerador/$n" > "$saida/.log"; then echo "  ok    marca do editor: $n"
  else echo "  FALHA marca do editor: $n"; sed 's/^/        /' "$saida/.log"; falhas=$((falhas + 1)); fi
done
for f in "$saida"/pagina/*.docx; do
  n="$(basename "$f")"
  if python3 "$raiz/testes/comparar_docx.py" "$f" "$saida/gerador/$n" > "$saida/.log"; then echo "  ok    $n"
  else echo "  FALHA $n"; sed 's/^/        /' "$saida/.log"; falhas=$((falhas + 1)); fi
done
exit $falhas
