# Divergências: original (`timbrador.html` + gerador embutido) × gerador atual

Fonte: pacote do original recebido em 16/10/2026 (fora do git, em `original/`: tem dados reais). O
`timbrador.html` traz **o gerador Python original inteiro** (linhas 194–2282,
`<script type="text/plain" id="gerador-python">`, 2.087 linhas) além do núcleo
JS da página. Pela regra do CLAUDE.md, esse Python manda em regra e formato do
JSON; a página manda no visual.

Legenda: **O** = original · **A** = atual (`gerar_documento.py`, 1.295 linhas).

## 1. Visual

| # | Item | O | A |
|---|---|---|---|
| V1 | Margens (cm) | curto/capa: sup 3,3 · dir 2,0 · inf 3,2 · esq 3,0; interno do longo: inf 2,6; cabeçalho/rodapé a 1,2 cm | 3/3/2/2; cabeçalho 0,9 cm, rodapé 0,8 cm |
| V2 | Borda da página | preta, sz 6, a 28 pt (~1 cm) da borda do papel | na cor da empresa, a 20 pt |
| V3 | Faixa de estado | tabela própria de 18,6 cm (1,2→19,8 cm, dentro da borda), altura exata 0,55 cm, 8 pt negrito, espaçamento 10 | primeira linha da tabela do cabeçalho, largura do texto (16 cm), 7,5 pt |
| V4 | Texto da faixa | separador `  ·  `: `MINUTA  ·  TEXTO PROPOSTO PARA ANÁLISE  ·  SEM VALIDADE OFICIAL`; oficial `DOCUMENTO OFICIAL  ·  VIGENTE  ·  DESDE dd/mm/aaaa`; obsoleto `OBSOLETO  ·  SUBSTITUÍDO POR X  ·  NÃO UTILIZAR` | separador `—` e vírgula; oficial só `DOCUMENTO OFICIAL`; obsoleto `OBSOLETO — NÃO UTILIZAR · SUBSTITUÍDO POR X` |
| V5 | Cores de estado | minuta C99700 (texto preto) · em aprovação 1F5FA8 · oficial 1E7B3C · obsoleto B00020 · rascunho 595959 | F2C200 · 2E75B6 · 2E7D32 · C62828 · 7F7F7F |
| V6 | Bloco de controle | 3 parágrafos centralizados: (1) `CÓDIGO  ·  vX.Y  ·  Página X de Y` (página em negrito preto); (2) frase do estado em negrito na cor do estado (cinza no oficial, precedida de "Aprovado por … em …"); (3) `razão  ·  CNPJ  ·  cidade` cinza 7F7F7F com filete cinza embaixo | tabela: código·versão / página à direita; "Situação: … · Emissão · classificação"; identificação; filete inferior na cor da empresa |
| V7 | Marca d'água | 470 pt de largura, altura pela extensão do texto, centrada na **página**, opacidade 1 com cor clara própria de cada estado, Arial negrito | 440×110 pt fixos, centrada na **margem**, opacidade 0,45 sobre tom da cor do estado |
| V8 | Rodapé curto/capa | filete sz 12 + logo 1,3 cm; sem logo: só o filete | filete sz 8 + logo 0,85 cm (máx. 5 cm); sem logo: nome da marca na cor |
| V9 | Rodapé interno do longo | logo 0,9 cm em coluna de 35 %; título à direita 8 pt | logo 0,85 cm em coluna de 5 cm; `titulo_curto` |
| V10 | Seções do longo | duas seções: capa (margens do timbrado, header1/footer1) e corpo ABNT (header2/footer2) | uma seção com `titlePg` |
| V11 | Capa | tabela de 1 célula com alturas exatas: tipo na cor da empresa 12 pt espaçado, título 22 pt, subtítulo 14 pt, **quadro de 4 células** (CÓDIGO · VERSÃO · ESTADO colorido · CLASSIFICAÇÃO), cidade e ano em negrito no pé | parágrafos com espaçamento; linha "código · Versão"; linha "estado · área · classificação"; cidade/ano 12 pt |
| V12 | Abertura do curto | uma linha `TIPO – TÍTULO` (negrito, caixa alta, 13 pt) + linha `código · Versão · Emissão · ESTADO` (estado na cor) | tipo pequeno na cor + título 14 pt + subtítulo; sem linha de controle |
| V13 | Folha de controle | ordem: Título, Tipo, Código, Versão, Estado, Classificação, Área responsável, Elaborado por, Revisado por, Aprovado por ("Pendente – documento não aprovado"), Data de emissão, Vigência ("A partir da aprovação"/"Encerrada"), Substitui, Substituído por, Motivo. Quadro "Histórico de **revisões**" (Versão, Data, **O que mudou**, Responsável; 1,4/1,6/5/2,4) | Código primeiro, "Situação", "Data de aprovação", "Norma de referência"; "Histórico de **versões**" (…, **Descrição**, …; 2/2,2/7/4) |
| V14 | Listas | numeração real do Word (`numbering.xml`), recuo 1134/425; checklist ☐ em Segoe UI Symbol | prefixo escrito à mão + tabulação |
| V15 | Destaque | parágrafo com borda esquerda sz 24 na cor do nível, "Rótulo:" em negrito, sem fundo | célula sombreada, rótulo em caixa alta |
| V16 | Assinaturas | 2 por linha, nome em caixa alta, cargo/papel/documento; formato **tabela** (Nome, Cargo, Papel, Assinatura, Data) e automático | 2 por linha, sem papel, sem caixa alta, sem tabela |
| V17 | Tabela sem fonte | "Fonte: Elaborado pela empresa (ano)." automático | aviso "tabela sem fonte" |

## 2. Regras e formato do JSON

| # | Item | O | A |
|---|---|---|---|
| R1 | Estados | ativos: MINUTA, **EM_APROVACAO**, OFICIAL, OBSOLETO. RASCUNHO e EM_REVISAO aposentados (só leitura; aviso). Padrão: MINUTA | RASCUNHO (padrão) e EM_REVISAO ativos; EM_APROVACAO não existe |
| R2 | Empresa incompleta | só minuta/em aprovação | só rascunho/minuta/em revisão |
| R3 | Empresa "grupo" | `grupo: true`: sem CNPJ no cabeçalho, rodapé com as logos de todas as empresas (sem logo → nome na cor) | não existe |
| R4 | OFICIAL | `vigencia` = `data_aprovacao` por padrão; acrescenta "Aprovada por X." ao histórico | exige os mesmos campos; não mexe em vigência nem histórico |
| R5 | Título | tira o nome do tipo do começo ("Política de X" → "X") e avisa | não ajusta |
| R6 | Tipos | inclui **RO** (Registro de Ocorrência); nomes com maiúscula ("Comunicação Interna") | sem RO; "Comunicação interna" |
| R7 | Áreas | FIS "Financeiro e fiscal", VEN "Vendas e comercial", ECO "E-commerce e marketplaces", OFC "Oficina e assistência técnica"; lista de ativas | nomes mais curtos; sem noção de ativas |
| R8 | Assinaturas | `com_assinatura`, `envolvidos`, `assinatura_formato` (auto/linhas/tabela); local e data com a data de emissão | não existem |
| R9 | Ficha embutida | JSON da spec em `customXml` + propriedades personalizadas | não existe |
| R10 | Ciclo de vida | `--ler`, `--atualizar` (versão X+1.0 ou X.Y+1, rodadas -rN), `--obsoletar`, cópia obsoleta automática da versão anterior | não existe |
| R11 | Lista mestra | `--lista` reserva número, recusa código repetido, registra publicação; `--inventariar` varre a pasta | não existe |
| R12 | Logos | `--logos` aceita pasta, o próprio `timbrador.html` ou um .docx timbrado | `--marca marca.json` (caminho ou data URI), `--embutir-logos` |
| R13 | Extras só do atual | — | `--checar-marca`, `--pdf`, `TIMBRADOR_SOFFICE`, `documento_rotulo` (CPF), `tipos_extra`/`areas_extra`, avisos de ABNT (alíneas, "Objetivo") |

## 3. Dados fixos no original que precisam ir para o `marca.json`

`EMPRESAS` (com `grupo`, `sem_logo` e empresa aposentada), `EMPRESAS_ATIVAS`,
`AREAS`/`AREAS_ATIVAS`, `TIPOS_ATIVOS`, código da política, nome da lista mestra,
namespace da ficha (`NS_FICHA`, com o nome da organização), prefixo dos logos,
siglas fixas em `RE_CODIGO`, empresa padrão, título e cor da página, `LOGOS`
embutidos. Os valores reais ficam só em `original/`, fora do git.

## 4. O original diverge de si mesmo (página × Python embutido)

Rodapé interno usa `titulo` na página e `titulo_curto` no Python · tipo padrão
da tabela "Quadro" na página e "Tabela" no Python · página não tem checklist ☐ ·
rótulo do bloco `campos` 3,3 cm na página e 4,0 no Python · sumário só com ≥ 3
entradas na página · OBSOLETO na página exige `substituido_por` (o Python aceita
`motivo_obsoleto`) · folha de controle da página sem "Motivo da obsolescência".

**Decisão (20/10/2026): o gerador vence nos sete pontos.** A página portada
(`pagina/timbrador.html`) passou a montar o .docx com um porte direto do
gerador: rodapé interno com `titulo_curto`, tabela "Tabela" por padrão (com
`alinhamento`, legenda e fonte sempre), checklist ☐, rótulo de `campos` 4,0 cm,
sumário sempre (salvo `"sumario": false`), OBSOLETO com `substituido_por` **ou**
`motivo_obsoleto` (a página ganhou o campo) e "Motivo da obsolescência" na folha
de controle. O bloco `gerador-python` foi removido da página: o gerador vive só
em `skills/timbrador/scripts/`. `bash testes/pagina.sh` confere que os dois
caminhos produzem o mesmo pacote.

