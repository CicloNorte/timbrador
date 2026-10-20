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
falhas=0
for f in "$saida"/pagina/*.docx; do
  n="$(basename "$f")"
  if python3 "$raiz/testes/comparar_docx.py" "$f" "$saida/gerador/$n" > "$saida/.log"; then echo "  ok    $n"
  else echo "  FALHA $n"; sed 's/^/        /' "$saida/.log"; falhas=$((falhas + 1)); fi
done
exit $falhas
