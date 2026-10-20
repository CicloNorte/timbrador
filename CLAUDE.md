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
**Falta portar a página de navegador** — ver "Próximo passo" abaixo. As
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
| `testes/` | marca e especificações fictícias + teste de fumaça |
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
bash testes/fumaca.sh        # marca, curto/longo, travas, grupo, CPF, ciclo de vida, lista mestra, PDF, XML
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

## Invariantes

1. **O `marca.json` é a única coisa que varia entre organizações.** Sigla, nome,
   razão social, documento (CNPJ ou CPF), cidade, cor, logo, `grupo`, `ativa` —
   mais `areas`, `areas_extra`, `areas_ativas`, `tipos_extra`, `tipos_ativos` e
   `politica` opcionais. **Nenhum dado de empresa pode voltar para o código.**
2. **O visual é o do original e não se negocia com o conteúdo**: faixa de
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
   Claude deixa de ser igual ao gerado pela página.

## Próximo passo: portar a página (`original/timbrador.html`)

A página tem dois scripts: `nucleo` (JS que repete o gerador: estados, faixa,
cabeçalho, blocos, montagem do .docx, lista mestra, leitura de .docx/.txt/.md) e
`interface`. Para o porte:

1. Os dados fixos (`EMPRESAS`, `EMPRESAS_ATIVAS`, `AREAS`, `AREAS_ATIVAS`,
   `TIPOS_ATIVOS`, `LOGOS`, `GRP-POL-ADM-001`, `urn:ciclonorte:timbrador:ficha`,
   `CN_LOGO|`, siglas em `RE_CODIGO`, título e cor da página) saem do HTML e
   passam a vir do mesmo `marca.json` (upload ou colado; logos em data URI, como
   `--embutir-logos` gera). Nenhuma empresa fixa no código.
2. O bloco `<script id="gerador-python">` deixa de existir na página (o gerador
   vive em `scripts/`), ou passa a ser cópia exata dele — decidir com o usuário.
3. Alinhar ao gerador portado: ficha com `urn:timbrador:ficha` (a leitura aceita
   qualquer `…timbrador:ficha`), logo com `TIMBRADOR_LOGO|`, `documento_rotulo`.
4. O original diverge de si mesmo em alguns pontos (seção 4 de
   `docs/divergencias-original.md`): o Python embutido manda em regra e JSON, a
   página no visual; perguntar ao usuário onde as duas discordarem.
5. Gerar o mesmo documento pelos dois caminhos e comparar.

## Estado da validação

Coberto pelo `fumaca.sh` (gerador portado, 20/10/2026): curto e longo; minuta,
em aprovação, oficial; estados e empresa aposentados (aviso); empresa sem logo,
incompleta, com CPF e de grupo; assinaturas em linhas e em tabela; título sem o
nome do tipo; `--ler`, `--atualizar`, lista mestra (registro e número
repetido), `--inventariar --conferir`, `--pdf`; XML bem formado. Conferência
visual em PDF via LibreOffice em 20/10/2026: capa, folha de controle, sumário
numerado e página interna do POP; CI do grupo com assinaturas e rodapé de logos.

**Não coberto ainda:** `--obsoletar` e a cópia obsoleta automática, inventário
gravando, `assinatura_formato` automático trocando para tabela, figuras JPEG grandes, tabelas que quebram entre páginas,
apêndices com muitos níveis, documentos acima de ~30 páginas, e a aparência real
no Word (a conferência foi toda via LibreOffice).

## Convenções

- Documentos gerados (`.docx`, `.pdf`) e `marca.json` de organização real **não
  entram no repositório** — ver `.gitignore`. Só `marca.exemplo.json` e as
  marcas fictícias de `testes/` são versionados.
- Mensagens de commit em português, no padrão conventional commits.
