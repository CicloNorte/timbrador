# Timbrador (white label)

Plugin para o Claude que transforma qualquer conteúdo em um .docx timbrado com a identidade da **sua** organização, seguindo ABNT e um controle documental com código, versão e estado (minuta, em aprovação, oficial, obsoleto), ficha embutida para reler e versionar o documento e lista mestra de numeração.

## Como personalizar

1. Copie `skills/timbrador/assets/marca.exemplo.json` para `marca.json` e preencha sigla, nome, razão social, CNPJ (ou CPF), cidade, cor e logo (PNG/JPEG).
2. Confira: `python3 skills/timbrador/scripts/gerar_documento.py --checar-marca marca.json`
3. Escolha como distribuir:
   - **Plugin já personalizado** (para a sua equipe): salve o arquivo como `skills/timbrador/assets/marca.json`, junto do logo.
   - **Plugin genérico** (para qualquer pessoa): não inclua `marca.json`. Na primeira conversa o Claude pergunta os dados e entrega um `marca.json` para reutilizar.
4. Para ter um arquivo único e portátil (logo embutido): `--embutir-logos marca.json --saida marca_portatil.json`.

Empresas sem razão social ou documento cadastrados só emitem minuta ou documento em aprovação. Um grupo de empresas pode ter uma entrada `"grupo": true` (documento que vale para todas, com as logos de todas no rodapé), e empresa aposentada fica com `"ativa": false`.

## Uso direto, sem o Claude

```bash
python3 skills/timbrador/scripts/gerar_documento.py especificacao.json --marca marca.json --saida saida/ --pdf
```

Outros comandos: `--ler` e `--atualizar` (documento já timbrado), `--obsoletar`, `--lista PASTA` (reserva e registra o número na publicação), `--inventariar PASTA`, `--anexo ARQUIVO` (anexos externos, com SHA-256, numa pasta com o código do documento) e `--rodada` (relatório de condução de projeto, uma rodada por versão). Assinatura entra só pela página: o gerador guarda os envolvidos como assinaturas previstas na ficha. O formato da especificação está em `skills/timbrador/SKILL.md` (seção 6). Requer só Python 3.8+. LibreOffice e `pdftotext` são opcionais: numeram o sumário e geram o PDF de conferência (`TIMBRADOR_SOFFICE` define outro comando para o LibreOffice).

## Página no navegador

`pagina/timbrador.html` faz o mesmo sem Python e sem o Claude: abra no Chrome ou no Edge, configure a marca em **Marca → Configurar** (organização, empresas com razão social, documento, cidade, cor e logo, áreas e tipos) e solte o arquivo (.docx, .txt, .md) ou cole o texto. A página não tem nenhuma empresa fixa. A marca fica guardada no navegador. **Exportar** baixa o `marca.json` que o Claude e o gerador usam, já com os logos embutidos. **Importar** aceita um `marca.json`; se os logos dele forem caminhos de arquivo, embuta-os antes com:

```bash
python3 skills/timbrador/scripts/gerar_documento.py --embutir-logos marca.json --saida marca_portatil.json
```

Quem tem manual de marca pode acrescentar ao `marca.json` um `visual` com as fontes (TrueType, embutidas no .docx) e as cores de texto, títulos e realce; a página também se veste com ele (ver `skills/timbrador/SKILL.md`). O documento sai igual ao do gerador. Diferenças só de ambiente: o sumário sai sem números de página (o Word numera ao abrir, quando pergunta se deve atualizar os campos), a escolha automática entre assinaturas em linhas e em tabela é estimada (o gerador renderiza com o LibreOffice) e blocos `figura` não entram (o gerador lê a imagem do disco). Com a pasta dos documentos conectada (Chrome/Edge), a página reserva o número, grava o .docx na pasta do tipo e atualiza o `lista-mestra.json`.

**Visualizar** mostra, na metade direita da tela, o documento em PDF como ele sairia agora, e acompanha o que se muda no formulário; a borda do formulário fica na cor do estado escolhido. A prévia é desenhada no próprio navegador, sem mandar nada para fora. A paginação é estimada e pode diferir um pouco da do Word, e as fontes do `visual` não entram nela: o documento que vale é o .docx.

Ao conectar a pasta, o bloco da lista mestra mostra o progresso (quantas pastas já foram lidas). **Inventariar** abre um painel à direita, como a prévia, com cada arquivo lido e o relatório no topo.

A página tem modo escuro: segue o tema do sistema, e o botão **Tema**, no canto do formulário, fixa claro ou escuro neste navegador. As cores neutras do `visual` (`cor_papel`, `cor_cartao`, `cor_linha`, `cor_texto`, `cor_secundaria`) valem só no tema claro; a cor dos títulos clareia no escuro. O documento e a prévia em PDF não mudam.

A página também cuida do campo Projeto (o documento vai para `Projetos/Nome`), dos anexos externos, do relatório de condução de projeto e guarda um rascunho do que está na tela se a página for recarregada.

No Windows, `pagina/Abrir-Timbrador.cmd` abre a página no Edge ou no Chrome, e `pagina/Inventariar.cmd` (arraste a pasta dos documentos sobre ele) monta o `lista-mestra.json` do que já existe, sem Python. Deixe o `marca.json` na mesma pasta dos scripts.

