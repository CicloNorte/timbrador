# Timbrador (white label) — contexto do projeto

Plugin do Claude que gera documentos `.docx` timbrados (papel timbrado + ABNT +
controle documental), com a identidade visual e os dados cadastrais de qualquer
organização vindos de um `marca.json`.

O fluxo: o Claude lê o conteúdo bruto do usuário, classifica (empresa, tipo,
área, estado), escreve uma especificação JSON e chama o gerador, que monta o
`.docx` escrevendo WordprocessingML direto num zip. **Nada de `python-docx` ou
`docx-js`**: a dependência zero é intencional, para o plugin rodar em qualquer
lugar. Só biblioteca padrão do Python 3.8+.

## Estado atual

O gerador **é o original** (o Python embutido no `timbrador.html`, recebido em
20/10/2026), portado para white label: empresas, áreas e tipos ativos vêm do
`marca.json`; do gerador anterior ficaram só `--marca`, `--checar-marca`,
`--embutir-logos`, `--pdf`, `TIMBRADOR_SOFFICE` e `documento_rotulo` (CPF).
A página de navegador também foi portada (20/10/2026): `pagina/timbrador.html`,
sem nenhuma empresa fixa, lendo o mesmo `marca.json` e montando o .docx com um
porte direto do gerador — o pacote sai igual (`testes/pagina.sh`). As
divergências que motivaram o porte estão em `docs/divergencias-original.md`.

## Estrutura

| Caminho | Papel |
|---|---|
| `.claude-plugin/plugin.json` | manifesto do plugin |
| `README.md` | instruções de personalização para humanos |
| `skills/timbrador/SKILL.md` | a norma: estados, códigos, ABNT, formato do JSON |
| `skills/timbrador/scripts/gerar_documento.py` | gerador (original portado), ~2.200 linhas, só stdlib |
| `skills/timbrador/assets/marca.exemplo.json` | modelo de configuração |
| `skills/timbrador/assets/logo-exemplo.png` | logo genérico do exemplo |
| `pagina/timbrador.html` | página de navegador (porte do original), lê o `marca.json` com logos embutidos |
| `pagina/Inventariar.ps1` (+ `.cmd`) | inventário da pasta no Windows sem Python; lê o `marca.json` (`-Marca`, `TIMBRADOR_MARCA` ou ao lado do script) |
| `pagina/Abrir-Timbrador.cmd` | abre a página no Edge ou no Chrome (os que gravam direto na pasta) |
| `testes/` | marca e especificações fictícias + teste de fumaça + página × gerador |
| `docs/divergencias-original.md` | original × gerador anterior, item a item |
| `original/` (fora do git) | pacote recebido: `timbrador.html`, `.cmd`, `.ps1`; tem dados reais |

`Timbrador-white-label-v1.zip` é a entrega original
(md5 `128a94c59c82bdf24c2392a6b0a2f79d`); está no `.gitignore` porque o conteúdo
já está versionado. O commit `70a7137` é esse estado intacto — a linha de base
para qualquer diff contra o original.

## Comandos

```bash
python3 skills/timbrador/scripts/gerar_documento.py espec.json --marca marca.json --saida saida/ --pdf
python3 skills/timbrador/scripts/gerar_documento.py --checar-marca marca.json
python3 skills/timbrador/scripts/gerar_documento.py --embutir-logos marca.json --saida marca_portatil.json
python3 skills/timbrador/scripts/gerar_documento.py --ler|--atualizar|--obsoletar DOCX --marca marca.json ...
python3 skills/timbrador/scripts/gerar_documento.py --inventariar PASTA --marca marca.json [--conferir]
bash testes/fumaca.sh        # marca, curto/longo, travas, grupo, CPF, assinaturas previstas, ciclo de vida, projeto, anexos, lista mestra, inventário, relatório de condução, PDF, XML
bash testes/pagina.sh        # página × gerador, editor da marca, relatório de condução lido e continuado pelos dois lados e prévia em PDF (precisa de node + jsdom; pula sem eles)
bash testes/inventario.sh    # Inventariar.ps1 × --inventariar: lista mestra e alertas iguais (precisa de pwsh ou TIMBRADOR_PWSH; pula sem ele)
```

LibreOffice e `pdftotext` são **opcionais**: com eles o gerador converte para
PDF, descobre em que página cada título caiu e grava os números no sumário; sem
eles o sumário sai vazio e o Word atualiza ao abrir. `TIMBRADOR_SOFFICE` troca o
comando do LibreOffice (necessário em sandboxes onde `soffice` precisa de
wrapper).

Nesta máquina os dois estão instalados (18/09/2026): LibreOffice 24.2.7
(`soffice`) e poppler-utils 24.02 (`pdftotext`, `pdftoppm`). O caminho do PDF e
da numeração do sumário **é** exercitado localmente — se o aviso "sumário sem
números de página" reaparecer, alguma das duas sumiu do PATH.

## No homeserver

Esta máquina é o homeserver. `docker compose up -d` (na raiz) sobe o container
`timbrador` (nginx:alpine, `restart: unless-stopped`) servindo `pagina/` em
**127.0.0.1:8091**, com CSP que só deixa a página ler arquivos do próprio site
(`deploy/nginx.conf`). O volume é a própria pasta `pagina/` do checkout: o que
estiver no branch atual é o que está no ar. O acesso de fora é por um hostname
público do túnel Cloudflare (configurado no painel, token no serviço
`cloudflared`) apontando para `http://localhost:8091`; o HTTPS do túnel é o que
deixa a página gravar direto na pasta dos documentos.

**Marca padrão do site: mhdn** (atualizada em 03/11/2026). `pagina/marca.json`
(fora do git, `.gitignore`) é a marca da mhdn, montada a partir do brandbook
(claude.ai/artifact/RSANaxBgb5bQ7Rquwgbezz): logo = livro novo (`MHDN -logo.svg`)
+ assinatura `mhdn`, compostos nas proporções da horizontal antiga e rasterizados
com resvg (o renderizador do ImageMagick desenha o M errado); cor `anil`
#233F61; CPF, Rio Claro, política `MHDN-POL-ADM-001`, todas as áreas e tipos; e
`visual` com os tokens do brandbook (tinta, anil, grafite, anil-claro; papel,
papel-cartao e linha na página) e EB Garamond (títulos) + Newsreader (texto)
embutidas. As fontes vieram dos woff2 do brandbook → TTF (wawoff2) com a tabela
de nomes refeita para uma família por fonte (Regular, Italic e Bold = Garamond
500 / Newsreader 600, peso marcado 700). Insumos e a versão anterior da marca
estão em `saida/mhdn/` (fora do git). A página busca esse arquivo ao abrir e o usa enquanto o navegador não
guardou uma marca própria (Editar/Importar guardam; "Usar a do site" volta). A
mesma cópia está em `skills/timbrador/assets/marca.json` (também fora do git),
que o gerador acha sozinho. O ícone do site (`pagina/favicon.svg`, `favicon.png`, `apple-touch-icon.png`,
fora do git) é o livro de capa azul (`Mhdn logo simplificada capa azul.SVG` do
brandbook) sem o fundo, recortado em quadrado; a página só aponta para esses nomes. **O `marca.json` do site é público** (tem o CPF):
sem Cloudflare Access no hostname, qualquer um o baixa.

## Invariantes

1. **O `marca.json` é a única coisa que varia entre organizações.** Sigla, nome,
   razão social, documento (CNPJ ou CPF), cidade, cor, logo, `grupo`, `ativa` —
   mais `areas`, `areas_extra`, `areas_ativas`, `tipos_extra`, `tipos_ativos`,
   `politica` e `visual` opcionais. **Nenhum dado de empresa pode voltar para o código.**
2. **O visual é o do original e não se negocia com o conteúdo** (exceção, decidida
   pelo usuário em 03/11/2026: o `visual` opcional do `marca.json` troca fontes e
   cores de texto/títulos/realce; sem ele, nada muda — e nunca muda faixa, cores de
   estado, borda, margens nem linhas de tabela): faixa de
   estado de borda a borda e bloco de controle centralizado (código · versão ·
   Página X de Y; frase do estado; razão social · documento · cidade), rodapé com
   filete na cor da empresa e logo, borda preta a 1 cm do papel, marca d'água nos
   estados não oficiais, margens esq. 3 · dir. 2 · sup. 3,3 · inf. 3,2 (curto e
   capa) ou 2,6 (páginas internas do longo).
3. **As travas de estado são de segurança documental, não de validação.**
   OFICIAL exige aprovador, data de aprovação, número reservado e empresa com
   cadastro completo; OBSOLETO exige substituto ou motivo. Empresa com
   `razao_social` ou `documento` em `[definir]` só emite MINUTA ou
   EM_APROVACAO (RASCUNHO e EM_REVISAO estão aposentados: só leitura). Nunca
   contorne: rebaixe o estado ou peça o dado.
4. **Dado que falta vira `[definir]`.** Não invente razão social, CNPJ, número,
   cláusula, data ou valor.
5. **Gerador e página andam juntos.** Qualquer mudança de visual, de regra ou de
   formato da marca precisa acontecer nos dois, ou o documento gerado pelo
   Claude deixa de ser igual ao gerado pela página. `testes/pagina.sh` confere.
6. **Assinatura entra só pela página** (caixa "Com assinatura"). O gerador tira do
   corpo as assinaturas e guarda os envolvidos como `assinaturas_previstas` na
   ficha (`adiar_assinaturas`; na página, `adiarAssinaturas`, que o teste usa para
   seguir o caminho do gerador).

## Recursos restaurados e relatório de condução (03/11/2026)

O PR #3 trouxe o porte de uma versão mais antiga do original. Voltaram, nos dois
lados, os recursos da versão mais recente: campo `projeto` (ficha, lista mestra,
pasta `Projetos/Nome`, PLN exige projeto), anexos externos com SHA-256 (`--anexo`;
na página, a caixa "Com anexos externos"), assinaturas previstas, inventário que lê
`Obsoletos` e pula `Modelos` (com alertas e entradas sem arquivo), figuras relativas
à especificação, rascunho da página no navegador e data da aprovação acompanhando o
dia. Na página, o campo Projeto substituiu o "Salvar em".

Relatório de condução (REL com rodadas), vindo do PR #2: número herdado do plano
oficial do projeto, cada rodada é uma versão OFICIAL nova, sem cópia obsoleta, e a
lista mestra guarda o SHA-256 de cada rodada (`rodadas_sha256`). As mesmas regras
estão no gerador (`regras_rel`, `celulas_rodada`) e na página (`regrasRel`,
`celulasRodada`): a impressão digital é calculada sobre o texto das cinco células
da linha. Corpo sem o Quadro de rodadas ganha a seção "Rodadas" no fim. Na página,
o modo de condução é opcional para REL novo (caixa "Relatório de condução de
projeto"); REL sem rodadas é relatório comum.

`Inventariar.ps1` acompanha o `--inventariar` (03/11/2026): lê `Obsoletos` e pula
`Modelos`, registra `projeto` (da ficha ou da pasta), mescla a entrada antiga, tira da
lista a entrada cujo arquivo sumiu de pasta varrida, dá os mesmos alertas e calcula o
SHA-256 das rodadas sobre o mesmo texto das células (`Celulas-Rodada`, espelho de
`celulas_rodada`). `testes/inventario.sh` compara as duas listas e os alertas, inclusive
com rodada adulterada; precisa de `pwsh` (ou `TIMBRADOR_PWSH`) e pula sem ele.

## A página (`pagina/timbrador.html`)

Porte de `original/timbrador.html` (fora do git, com dados reais). Decisões do
usuário (20/10/2026): o bloco `gerador-python` **saiu** da página; onde página e
Python embutido divergiam, **o gerador venceu nos sete pontos** (ver seção 4 de
`docs/divergencias-original.md`).

- Núcleo (`<script id="nucleo">`): `carregarMarca()` é o `carregar_marca()` do
  gerador; montagem (`montar`, `blocos`, estilos, numeração, ficha) é porte
  linha a linha do Python — mesma ordem de ids, rels, mídia (`img1.png`),
  `round()` com meio para o par (`arred`), ficha em `json.dumps` (`jsonPy`).
  Mexeu num, mexa no outro e rode `testes/pagina.sh`.
- O que não dá para portar: números de página do sumário (o Word atualiza ao
  abrir), assinatura automática (a página estima a paginação; o gerador
  renderiza), bloco `figura` (vira aviso). Logo só em data URI (`--embutir-logos`).
- Prévia em PDF (`<script id="pdf">`, 03/11/2026): o botão **Visualizar** abre o
  documento em PDF na metade direita da tela (o formulário vai para a esquerda) e
  acompanha as mudanças do formulário. `gerarPdf(spec, conteudo)` recebe o mesmo
  pedido do Gerar (`montarPedido` + `corpoDoPedido`) e desenha, sem biblioteca, o
  leiaute do `montar` em pontos: faixa, controle, borda, marca d'água, rodapés,
  capa, folha de controle, sumário (já com as páginas) e os blocos de conteúdo.
  Texto em Helvetica (métricas AFM embutidas, WinAnsi; fora dela sai "?"), JPEG
  direto e PNG decodificado em RGB + máscara alfa. É estimativa: paginação e quebra
  de linha podem diferir um pouco do Word, o `visual` só troca cores (as fontes do
  `visual` não entram no PDF) e `figura` não aparece, como no .docx da página.
  Pendências do formulário não impedem a prévia: aparecem acima dela. A CSP do
  nginx libera `frame-src blob:` e `object-src blob:` para o leitor de PDF do
  navegador. A borda do formulário tem a cor do estado escolhido (`--estado`).
  Mexeu no `montar`/`blocos`, confira a prévia (`testes/pagina.sh` gera os PDFs).
- Modo escuro (03/11/2026): as cores da página são variáveis no `:root`, redefinidas
  em `@media (prefers-color-scheme:dark)` e em `:root[data-tema="escuro"]`; o botão
  `#tema` cicla automático → claro → escuro e guarda em `localStorage`
  (`timbrador.tema`), lido por um script no `<head>` antes de desenhar. O `visual`
  grava as cores neutras em `--v-*`, que só o tema claro usa; texto na cor da marca
  usa `--cor-texto` (clareada no escuro). Cor nova na página: variável, nos dois temas.
- Progresso da pasta e painel do inventário (04/11/2026): pela rede, conectar a pasta
  (procurar o `lista-mestra.json` e mapear as pastas) leva segundos. `progresso(texto)`
  mostra uma barra e quantas pastas já foram lidas no próprio bloco da lista mestra, e
  o botão fica desabilitado até terminar (`finally`). **Inventariar** abre o painel
  `#registro` no lugar da prévia (um painel por vez, o formulário vai para a esquerda):
  cada arquivo lido entra numa linha (`registrar`) e o relatório fica no topo do painel;
  a mensagem do fim da página só resume.
- Leitura, lista mestra, inventário e pastas continuam os da página original,
  com siglas genéricas (`[A-Z0-9]{2,6}`) e ficha `…timbrador:ficha`.
- `visual` (opcional): `carregarVisual`/`lerVisual` nos dois lados; `sec()`,
  `cor_texto()`/`corTexto()` e `realce()` devolvem o valor do original quando ele
  não existe (sem `visual` a saída é byte a byte a de antes). Fontes embutidas:
  `word/fontTable.xml` + `word/fonts/fontN.odttf` ofuscadas (ECMA-376 17.8.1), GUID
  tirado do CRC32 da própria fonte, para página e gerador darem o mesmo pacote.
  A interface também se veste com ele (cores em variáveis CSS, fontes via `FontFace`).
  O editor da marca ainda não edita o `visual` (só preserva).
- A marca é configurada na própria página (Marca → Configurar/Editar: organização,
  política, empresas com logo por upload, áreas e tipos ativos e extras) e fica no
  `localStorage` (`timbrador.marca`) **no formato do marca.json**, validada por
  `carregarMarca`. Exportar baixa esse `marca.json` (logos em data URI), que
  serve direto ao gerador; Importar/colar aceita um. Campos que o editor não
  mostra (`areas`, `_instrucoes`) passam intactos.

`Inventariar.ps1` e os `.cmd` também foram portados (20/10/2026): empresa
padrão, nome da organização, código da política e tipos extras vêm do
`marca.json`; ficha `…timbrador:ficha`; siglas `[A-Z0-9]{2,6}`. Lista que já
existe mantém o `lista_mestra`/`padrao` dela (como o gerador). Testado com
PowerShell 7.4 no Linux contra `gerar_documento.py --inventariar`: lista mestra
igual (ficha nova e antiga, cabeçalho, nome). Em 03/11/2026 passou a seguir as
regras atuais (ver "Recursos restaurados"), conferido com PowerShell 7.4.6 no Linux
por `testes/inventario.sh`. Os `.cmd` estão
em CRLF (`.gitattributes`).

**Pendente:** no Chrome real só foram vistos a carga da marca e o editor (sem
erro de console); falta gerar um documento e conectar a pasta por lá. O `.ps1`
não rodou no Windows PowerShell 5.1.

## Estado da validação

Coberto pelo `fumaca.sh` (gerador portado, 20/10/2026): curto e longo; minuta,
em aprovação, oficial; estados e empresa aposentados (aviso); empresa sem logo,
incompleta, com CPF e de grupo; assinaturas em linhas e em tabela; título sem o
nome do tipo; `--ler`, `--atualizar`, lista mestra (registro e número
repetido), `--inventariar --conferir`, `--pdf`; XML bem formado. Conferência
visual em PDF via LibreOffice em 20/10/2026: capa, folha de controle, sumário
numerado e página interna do POP; CI do grupo com assinaturas e rodapé de logos.

Página (20/10/2026, `testes/pagina.sh` e jsdom): curto e longo do teste, grupo,
CPF, empresa incompleta, obsoleto por motivo, estado/tipo/área aposentados,
assinaturas em linhas e em tabela, e um curto e um longo pela interface
(texto colado + formulário + Gerar) — pacote igual ao do gerador parte a parte
e PDFs idênticos pixel a pixel no LibreOffice.

Visual (03/11/2026): regressão sem `visual` idêntica ao gerador anterior (6
documentos); `testes/pagina.sh` com visual e fontes embutidas (DejaVu Serif do
sistema); marca mhdn com visual igual página × gerador (25 e 28 partes); PDFs
com Newsreader e EB Garamond embutidas (LibreOffice usa as fontes do .docx).

Recursos restaurados e relatório (03/11/2026): `fumaca.sh` com 64 verificações
(assinaturas previstas, projeto, anexos com SHA-256 e anexo alterado recusado,
inventário com Obsoletos e projeto fora da pasta, 19 casos do relatório de condução);
`pagina.sh` com o documento de grupo com assinatura e o relatório lido e continuado
pelos dois lados; interface no Chromium (Playwright): texto colado, Projeto,
assinatura, anexo, Gerar (zip com documento e anexo), caixa do relatório e rascunho
recuperado ao recarregar, sem erro de console.

Prévia em PDF (03/11/2026): `pagina.sh` gera pelo núcleo da página o PDF do curto,
do longo, do grupo com assinatura e do relatório de condução e confere estrutura,
código e "Página X de Y"; comparados ao .docx convertido pelo LibreOffice, saem com a
mesma paginação (o longo com 10 páginas contra 11, porque o LibreOffice põe uma
página em branco depois da capa). Interface no Chromium: borda na cor do estado,
formulário à esquerda, prévia atualizada ao mudar o estado, pendências acima dela;
no Google Chrome (Playwright, `channel="chrome"`), a prévia aparece no leitor de
PDF tanto aberta como arquivo quanto servida pelo nginx com a CSP. O Chromium e o
Firefox do Playwright vêm sem leitor de PDF: neles o quadro fica cinza.

**Não coberto ainda:** a prévia no Edge e no Firefox de verdade, as fontes embutidas abertas no Word de verdade, `--obsoletar` e a cópia obsoleta automática, inventário
gravando, `assinatura_formato` automático trocando para tabela, figuras JPEG grandes, tabelas que quebram entre páginas,
apêndices com muitos níveis, documentos acima de ~30 páginas, e a aparência real
no Word (a conferência foi toda via LibreOffice).

## Convenções

- Documentos gerados (`.docx`, `.pdf`) e `marca.json` de organização real **não
  entram no repositório** — ver `.gitignore`. Só `marca.exemplo.json` e as
  marcas fictícias de `testes/` são versionados.
- Mensagens de commit em português, no padrão conventional commits.
