# Inventariar.ps1 - Timbrador (white label)
# Varre a pasta dos documentos (subpastas com as siglas de tipo), le cada .docx e monta o lista-mestra.json.
# Nao instala nada: usa so o que ja vem no Windows PowerShell 5.1 ou superior.
# A organizacao (nome, politica, empresa padrao, tipos extras) vem do marca.json: -Marca, a variavel
# TIMBRADOR_MARCA ou um marca.json na mesma pasta deste script. Nenhum dado de empresa fica aqui.
#
#   .\Inventariar.ps1 -Pasta "G:\Documentos"
#   .\Inventariar.ps1 -Pasta "G:\Documentos" -Marca "G:\Controle\marca.json"
#   .\Inventariar.ps1 -Pasta "G:\Documentos" -Conferir      # so mostra o relatorio, nao grava
#   .\Inventariar.ps1 -Pasta "G:\Documentos" -Lista "G:\Controle"   # grava a lista em outro lugar

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Pasta,
  [string]$Lista,
  [string]$Marca,
  [string[]]$Ignorar = @(),
  [switch]$Conferir
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$TIPOS_CURTOS = @("CI","COM","OFI","DEC","TER","ATA","RO","AUT","NOT","CTR","PRO","FOR","REC")
$TIPOS_LONGOS = @("MAN","POL","REG","POP","INS","PLN","PRJ","REL")
# A ficha embutida tem namespace terminado em "timbrador:ficha" (urn:timbrador:ficha e o dos documentos antigos).
$MARCA_FICHA  = "timbrador:ficha"
$RE_CODIGO    = [regex]"\b([A-Z0-9]{2,6})-([A-Z]{2,3})-([A-Z]{2,3})-(\d{3}|XXX)(?:/(\d{4}))?\s+·\s+(?:v|[Vv]ersão\s+)([0-9][0-9.]*(?:-r\d+)?)"
$RE_NOME      = [regex]"(?i)^([A-Z0-9]{2,6})-([A-Z]{2,4})-([A-Z]{2,4})-(\d{3}|XXX)(?:-(\d{4}))?_v([0-9][0-9.]*(?:-r\d+)?)_([A-Z_]+)_(.+)\.docx$"
$TARJAS       = [ordered]@{ "DOCUMENTO OFICIAL" = "OFICIAL"; "OBSOLETO" = "OBSOLETO"; "EM APROVAÇÃO" = "EM_APROVACAO"; "EM REVISÃO" = "EM_REVISAO"; "MINUTA" = "MINUTA"; "RASCUNHO" = "RASCUNHO" }
$ORDEM_ESTADO = @{ "OBSOLETO" = 0; "RASCUNHO" = 1; "MINUTA" = 2; "EM_REVISAO" = 3; "EM_APROVACAO" = 3; "OFICIAL" = 4 }

function Valor($obj, [string]$nome) {
  if ($null -eq $obj) { return $null }
  $p = $obj.PSObject.Properties[$nome]
  if ($null -eq $p) { return $null }
  if ($p.Value -is [string] -and $p.Value.Trim() -eq "") { return $null }
  return $p.Value
}

function Texto-Zip($zip, [string]$padrao) {
  $saida = New-Object System.Text.StringBuilder
  foreach ($e in $zip.Entries) {
    if ($e.FullName -match $padrao) {
      $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
      [void]$saida.Append(" ").Append($sr.ReadToEnd())
      $sr.Close()
    }
  }
  return $saida.ToString()
}

function Chave-Versao([string]$v) {
  if (-not $v) { $v = "0" }
  $partes = $v -split "-r", 2
  $nums = ($partes[0] -split "\.")
  $x = 0; $y = 0
  if ($nums.Count -ge 1 -and $nums[0] -match "^\d+$") { $x = [int]$nums[0] }
  if ($nums.Count -ge 2 -and $nums[1] -match "^\d+$") { $y = [int]$nums[1] }
  $temRodada = $partes.Count -gt 1
  $rod = 0
  if ($temRodada -and $partes[1] -match "^\d+$") { $rod = [int]$partes[1] }
  # oficial (sem -r) vale mais que qualquer rodada da mesma versao
  return @($x, $y, $(if ($temRodada) { 0 } else { 1 }), $rod)
}

function Compara-Versao($a, $b) {
  $A = Chave-Versao $a; $B = Chave-Versao $b
  for ($i = 0; $i -lt 4; $i++) { if ($A[$i] -ne $B[$i]) { return $A[$i] - $B[$i] } }
  return 0
}

function Ficha-Do-Docx([string]$caminho) {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($caminho)
  try {
    $spec = [ordered]@{}; $origem = "sem_timbrado"
    $xml = Texto-Zip $zip "^customXml/item\d+\.xml$"
    if ($xml -and $xml.Contains($MARCA_FICHA)) {
      $m = [regex]::Match($xml, "<ficha[^>]*>(.*?)</ficha>", "Singleline")
      if ($m.Success) {
        $json = $m.Groups[1].Value -replace "&quot;", '"' -replace "&lt;", "<" -replace "&gt;", ">" -replace "&amp;", "&"
        try {
          $f = $json | ConvertFrom-Json
          foreach ($p in $f.PSObject.Properties) { $spec[$p.Name] = $p.Value }
          $origem = "ficha"
        } catch { }
      }
    }
    if ($origem -ne "ficha") {
      $cab = (Texto-Zip $zip "^word/(header|footer)\d*\.xml$") -replace "<[^>]+>", " " -replace "\s+", " "
      $m = $RE_CODIGO.Match($cab)
      if ($m.Success) {
        $origem = "cabecalho"
        $spec["empresa"] = $m.Groups[1].Value; $spec["tipo"] = $m.Groups[2].Value
        $spec["area"] = $m.Groups[3].Value;    $spec["versao"] = $m.Groups[6].Value
        if ($m.Groups[4].Value -ne "XXX") { $spec["numero"] = [int]$m.Groups[4].Value }
        if ($m.Groups[5].Success) { $spec["ano"] = [int]$m.Groups[5].Value }
        foreach ($t in $TARJAS.Keys) { if ($cab.Contains($t)) { $spec["estado"] = $TARJAS[$t]; break } }
        $ma = [regex]::Match($cab, "Aprovado por (.+?) em (\d{2}/\d{2}/\d{4})")
        if ($ma.Success) { $spec["aprovado_por"] = $ma.Groups[1].Value.Trim(); $spec["data_aprovacao"] = $ma.Groups[2].Value }
      }
    }
    return @{ spec = $spec; origem = $origem }
  } finally { $zip.Dispose() }
}

function Ficha-Do-Nome([string]$nome) {
  $m = $RE_NOME.Match($nome)
  if (-not $m.Success) { return $null }
  $spec = [ordered]@{
    empresa = $m.Groups[1].Value.ToUpper(); tipo = $m.Groups[2].Value.ToUpper()
    area = $m.Groups[3].Value.ToUpper();    versao = $m.Groups[6].Value
    estado = $m.Groups[7].Value.ToUpper()
  }
  $titulo = ($m.Groups[8].Value -replace "-", " ").Trim()
  if ($titulo) { $spec["titulo"] = $titulo.Substring(0,1).ToUpper() + $titulo.Substring(1) }
  if ($m.Groups[4].Value.ToUpper() -ne "XXX") { $spec["numero"] = [int]$m.Groups[4].Value }
  if ($m.Groups[5].Success) { $spec["ano"] = [int]$m.Groups[5].Value }
  return $spec
}

function Sigla-Da-Pasta([string]$nome) {
  # aceita "POP", "Politicas (POL)", "REG - regulamentos"
  foreach ($m in [regex]::Matches($nome.ToUpper(), "[A-Z]{2,4}")) {
    if ($TIPOS_CURTOS -contains $m.Value -or $TIPOS_LONGOS -contains $m.Value) { return $m.Value }
  }
  return $null
}

function Chave-Registro($codigo, $numero, $arquivo) {
  # documento com numero e unico pelo codigo; sem numero (XXX), cada arquivo vale como uma entrada
  if ($numero) { return "$codigo" }
  return "$codigo|$arquivo"
}

function Sem-Acento([string]$t) {
  if (-not $t) { return "" }
  $d = $t.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder
  foreach ($c in $d.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
  }
  return (($sb.ToString().ToLower()) -replace "[^a-z0-9]+", " ").Trim()
}

# ---------------------------------------------------------------- marca.json
# Mesmas regras do gerador (gerar_documento.py --inventariar --marca): empresa padrao, nome da organizacao,
# codigo da politica e tipos extras vem dele.
if (-not $Marca) { $Marca = $env:TIMBRADOR_MARCA }
if (-not $Marca) { $Marca = Join-Path $PSScriptRoot "marca.json" }
if (-not (Test-Path -LiteralPath $Marca)) {
  Write-Host "marca.json nao encontrado ($Marca). Informe -Marca, defina TIMBRADOR_MARCA ou deixe o marca.json na pasta deste script."
  exit 1
}
try { $cfg = (Get-Content -LiteralPath $Marca -Raw -Encoding UTF8) | ConvertFrom-Json }
catch { Write-Host "Nao consegui ler o marca.json ($Marca): $($_.Exception.Message)"; exit 1 }
$empresasAtivas = @(@($cfg.empresas) | Where-Object { $_.sigla -and $_.ativa -ne $false } | ForEach-Object { "$($_.sigla)".ToUpper() })
if ($empresasAtivas.Count -eq 0) { Write-Host "marca.json: nenhuma empresa ativa."; exit 1 }
$EMPRESA_PADRAO = if (Valor $cfg "empresa_padrao") { "$($cfg.empresa_padrao)".ToUpper() } else { $empresasAtivas[0] }
$ORGANIZACAO = "$(Valor $cfg 'organizacao')"
$POLITICA = "$(Valor (Valor $cfg 'politica') 'codigo')"
if ($ORGANIZACAO -eq "[definir]") { $ORGANIZACAO = "" }
if ($POLITICA -eq "[definir]") { $POLITICA = "" }
$tiposExtra = Valor $cfg "tipos_extra"
if ($tiposExtra) {
  foreach ($p in $tiposExtra.PSObject.Properties) {
    $sig = $p.Name.ToUpper()
    if ($p.Value.variante -eq "curto") { $TIPOS_CURTOS += $sig } elseif ($p.Value.variante -eq "longo") { $TIPOS_LONGOS += $sig }
  }
}

# ---------------------------------------------------------------- varredura
$raiz = (Resolve-Path -LiteralPath $Pasta).Path
Write-Host "INVENTARIO de $raiz"

# procura um lista-mestra.json que ja exista na arvore, para nao criar uma segunda lista
$listasNaArvore = @(Get-ChildItem -LiteralPath $raiz -Recurse -File -Filter "lista-mestra.json" -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.FullName } | Sort-Object)
if ($Lista) {
  $destino = $Lista
} elseif ($listasNaArvore.Count -eq 1) {
  $destino = $listasNaArvore[0]
  Write-Host "  lista mestra encontrada em: $destino"
} elseif ($listasNaArvore.Count -gt 1) {
  Write-Host "  Ha mais de um lista-mestra.json nesta arvore:"
  foreach ($l in $listasNaArvore) { Write-Host "    $l" }
  Write-Host "  Use -Lista para dizer qual vale."
  return
} else {
  $destino = $raiz
}
if (-not $destino.ToLower().EndsWith(".json")) { $destino = Join-Path $destino "lista-mestra.json" }

$achados = @(); $semId = @(); $ignorados = 0; $modelos = @()
# Pastas puladas por padrao: o arquivo morto nao faz parte do que esta em uso.
# Para inventariar o proprio arquivo morto, aponte -Pasta para ele: a raiz nunca e pulada.
$PASTAS_IGNORADAS = @("obsoletos")
$pular = @($Ignorar | ForEach-Object { $_.ToLower() }) + $PASTAS_IGNORADAS
foreach ($arq in Get-ChildItem -LiteralPath $raiz -Recurse -File) {
  if ($arq.Name.StartsWith("~$") -or $arq.Name.StartsWith(".")) { continue }
  if ($pular.Count -gt 0) {
    $partes = @($arq.DirectoryName.Substring($raiz.Length).Split([char]"\", [char]"/") | Where-Object { $_ } | ForEach-Object { $_.ToLower() })
    $achouPular = $false
    foreach ($p in $partes) { if ($pular -contains $p) { $achouPular = $true; break } }
    if ($achouPular) { continue }
  }
  if ($arq.Extension -ne ".docx") { if ($arq.Extension -ne ".json") { $ignorados++ }; continue }
  $rel = $arq.FullName.Substring($raiz.Length).TrimStart("\", "/")
  try { $r = Ficha-Do-Docx $arq.FullName }
  catch { $semId += ,@($rel, "nao foi possivel abrir o arquivo"); continue }
  $spec = $r.spec; $origem = $r.origem
  # arquivo de partida de modelo: nao e documento, nao entra na lista
  if ($spec.Contains("modelo") -and $spec["modelo"]) { $modelos += $rel; continue }
  $peloNome = Ficha-Do-Nome $arq.Name
  if ($origem -eq "sem_timbrado") {
    if ($null -eq $peloNome) { $semId += ,@($rel, "sem ficha, sem codigo no cabecalho e fora do padrao de nome"); continue }
    $spec = $peloNome; $origem = "nome"
  } elseif ($peloNome) {
    foreach ($k in $peloNome.Keys) { if (-not $spec.Contains($k) -or $null -eq $spec[$k] -or "$($spec[$k])" -eq "") { $spec[$k] = $peloNome[$k] } }
  }
  $sigla = Sigla-Da-Pasta $arq.Directory.Name
  if ((-not $spec.Contains("tipo") -or -not $spec["tipo"]) -and $sigla) { $spec["tipo"] = $sigla }
  if (-not $spec.Contains("tipo") -or -not $spec["tipo"]) { $semId += ,@($rel, "nao deu para saber o tipo do documento"); continue }
  if (-not $spec.Contains("empresa") -or -not $spec["empresa"]) { $spec["empresa"] = $EMPRESA_PADRAO }
  if (-not $spec.Contains("area")    -or -not $spec["area"])    { $spec["area"] = "ADM" }
  if (-not $spec.Contains("estado")  -or -not $spec["estado"])  { $spec["estado"] = "MINUTA" }
  if (-not $spec.Contains("versao")  -or -not $spec["versao"])  { $spec["versao"] = "1.0" }
  if (-not $spec.Contains("titulo")  -or -not $spec["titulo"])  { $spec["titulo"] = [IO.Path]::GetFileNameWithoutExtension($arq.Name) }
  if (-not $spec.Contains("codigo") -or -not $spec["codigo"]) {
    $num = "XXX"
    if ($spec.Contains("numero") -and $spec["numero"]) { $num = "{0:d3}" -f [int]$spec["numero"] }
    $codigo = "$($spec['empresa'])-$($spec['tipo'])-$($spec['area'])-$num"
    if (($TIPOS_CURTOS -contains $spec["tipo"]) -and $spec.Contains("ano") -and $spec["ano"]) { $codigo += "/$($spec['ano'])" }
    $spec["codigo"] = $codigo
  }
  $pastaRel = [IO.Path]::GetDirectoryName($rel); if (-not $pastaRel) { $pastaRel = "." }
  $achados += ,[pscustomobject]@{ spec = $spec; origem = $origem; nome = $arq.Name; pasta = $pastaRel }
}

# ---------------------------------------------------------------- uma entrada por codigo
$existentes = [ordered]@{}
$antiga = $null
if (Test-Path -LiteralPath $destino) {
  try {
    $antiga = (Get-Content -LiteralPath $destino -Raw -Encoding UTF8) | ConvertFrom-Json
      foreach ($d in @($antiga.documentos)) { if ($d.codigo) { $existentes[(Chave-Registro $d.codigo $d.numero $d.arquivo)] = $d } }
  } catch { Write-Host "  (lista existente ilegivel: sera refeita)" }
}

$porCodigo = [ordered]@{}
foreach ($a in $achados) {
  $num = $null; if ($a.spec.Contains("numero")) { $num = $a.spec["numero"] }
  $c = Chave-Registro $a.spec["codigo"] $num $a.nome
  if (-not $porCodigo.Contains($c)) { $porCodigo[$c] = @() }
  $porCodigo[$c] += ,$a
}

$agora = (Get-Date).ToString("dd/MM/yyyy HH:mm")
$documentos = @(); $conflitos = @(); $varias = @()
foreach ($chave in $porCodigo.Keys) {
  $itens = @($porCodigo[$chave] | Sort-Object @{ Expression = { (Chave-Versao $_.spec["versao"])[0] } },
                                              @{ Expression = { (Chave-Versao $_.spec["versao"])[1] } },
                                              @{ Expression = { (Chave-Versao $_.spec["versao"])[2] } },
                                              @{ Expression = { (Chave-Versao $_.spec["versao"])[3] } },
                                              @{ Expression = { $ORDEM_ESTADO["$($_.spec['estado'])"] } })
  $atual = $itens[-1]; $s = $atual.spec
  $titulos = @($itens | ForEach-Object { $_.spec["titulo"] } | Where-Object { $_ } | Select-Object -Unique)
  $codigo = $s["codigo"]
  if (@($titulos | ForEach-Object { Sem-Acento $_ } | Select-Object -Unique).Count -gt 1) { $conflitos += ,@($codigo, $titulos) }
  if ($itens.Count -gt 1) { $varias += ,@($codigo, @($itens | ForEach-Object { "$($_.spec['versao']) $($_.spec['estado'])" })) }
  $antes = $existentes[$chave]
  $numero = $null; if ($s.Contains("numero") -and $s["numero"]) { $numero = [int]$s["numero"] }
  $ano = $null;    if ($s.Contains("ano") -and $s["ano"])       { $ano = [int]$s["ano"] }
  $data = $null
  foreach ($k in @("data_aprovacao", "data_emissao")) { if (-not $data -and $s.Contains($k)) { $data = $s[$k] } }
  $resp = ""; if ($s.Contains("elaborado_por") -and $s["elaborado_por"]) { $resp = $s["elaborado_por"] }
  $reg = [ordered]@{
    codigo = $codigo; titulo = $s["titulo"]; empresa = $s["empresa"]; tipo = $s["tipo"]; area = $s["area"]
    numero = $numero; ano = $ano; versao = $s["versao"]; estado = $s["estado"]; data = $data
    responsavel = $resp; arquivo = $atual.nome; pasta = $atual.pasta; origem = $atual.origem
  }
  if ($s.Contains("substituido_por") -and $s["substituido_por"]) { $reg["substituido_por"] = $s["substituido_por"] }
  if ($itens.Count -gt 1) { $reg["arquivos"] = $itens.Count }
  $reg["registrado_em"] = if ($antes -and $antes.registrado_em) { $antes.registrado_em } else { $agora }
  $reg["atualizado_em"] = $agora
  $documentos += ,$reg
  $existentes.Remove($chave) | Out-Null
}
# documentos que estavam na lista e nao foram encontrados agora continuam registrados
foreach ($c in @($existentes.Keys)) {
  $d = $existentes[$c]; $o = [ordered]@{}
  foreach ($p in $d.PSObject.Properties) { $o[$p.Name] = $p.Value }
  $documentos += ,$o
}
$documentos = @($documentos | Sort-Object @{ Expression = { "$($_.empresa)" } }, @{ Expression = { "$($_.tipo)" } },
                                          @{ Expression = { "$($_.area)" } }, @{ Expression = { "$($_.ano)" } },
                                          @{ Expression = { [int]("0" + "$($_.numero)") } }, @{ Expression = { "$($_.arquivo)" } })

# ---------------------------------------------------------------- relatorio
$conta = { param($valores)
  $t = ($valores | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) $($_.Count)" }) -join " - "
  if ($t) { $t } else { "nenhum" } }
Write-Host ("  {0} arquivo(s) .docx  -  {1} documento(s) distintos" -f $achados.Count, $porCodigo.Count)
Write-Host ("  origem dos dados: " + (& $conta @($achados | ForEach-Object { $_.origem })))
Write-Host ("  por tipo: "         + (& $conta @($achados | ForEach-Object { $_.spec["tipo"] })))
Write-Host ("  por estado: "       + (& $conta @($achados | ForEach-Object { $_.spec["estado"] })))
Write-Host ""
foreach ($d in $documentos) {
  $marca = " "; if ($d.origem -eq "nome" -or $d.origem -eq "cabecalho") { $marca = "*" }
  $resp = "$($d.responsavel)"; if (-not $resp) { $resp = "-" }
  $titulo = "$($d.titulo)"; if ($titulo.Length -gt 44) { $titulo = $titulo.Substring(0, 44) }
  Write-Host ("{0} {1,-22} v{2,-8} {3,-10} {4,-44} {5,-10} {6}" -f $marca, $d.codigo, $d.versao, $d.estado, $titulo, $d.pasta, $resp)
}
Write-Host ""
if (@($documentos | Where-Object { $_.origem -eq "nome" -or $_.origem -eq "cabecalho" }).Count -gt 0) {
  Write-Host "  (* dados lidos do cabecalho ou do nome do arquivo: confira titulo e responsavel)"
}
if ($varias.Count -gt 0) {
  Write-Host ("  {0} documento(s) com mais de um arquivo na pasta (ficou a versao mais alta):" -f $varias.Count)
  foreach ($v in $varias) { Write-Host ("    {0}: {1}" -f $v[0], ($v[1] -join ", ")) }
}
if ($conflitos.Count -gt 0) {
  Write-Host "  ATENCAO - mesmo codigo com titulos diferentes (numeracao repetida):"
  foreach ($c in $conflitos) { Write-Host ("    {0}: {1}" -f $c[0], ($c[1] -join " | ")) }
}
$versoesRuins = @($achados | Where-Object { "$($_.spec['versao'])" -notmatch "^\d+\.\d+(-r\d+)?$" } |
                   ForEach-Object { "$($_.spec['codigo']): v$($_.spec['versao'])" } | Select-Object -Unique)
if ($versoesRuins.Count -gt 0) {
  Write-Host "  Versoes fora do padrao X.Y ou X.Y-rN (acerte ao gerar a proxima versao):"
  foreach ($v in $versoesRuins) { Write-Host "    $v" }
}
$semNumero = @($achados | Where-Object { -not $_.spec.Contains("numero") -or -not $_.spec["numero"] })
if ($semNumero.Count -gt 0) {
  Write-Host ("  {0} arquivo(s) sem numero (codigo com XXX): reserve o numero:" -f $semNumero.Count)
  foreach ($x in $semNumero) { Write-Host ("    {0} - {1}" -f $x.spec["codigo"], $x.nome) }
}
if ($semId.Count -gt 0) {
  Write-Host ("  {0} arquivo(s) .docx nao identificados (ficaram de fora):" -f $semId.Count)
  foreach ($s in $semId) { Write-Host ("    {0} - {1}" -f $s[0], $s[1]) }
}
if ($ignorados -gt 0) { Write-Host ("  {0} arquivo(s) que nao sao .docx foram ignorados." -f $ignorados) }
if ($modelos.Count -gt 0) { Write-Host ("  {0} arquivo(s) de partida de modelo foram pulados (nao sao documentos)." -f $modelos.Count) }
Write-Host ""

if ($Conferir) { Write-Host "Nada foi gravado (-Conferir)."; return }

# nome diferente de $Lista (parametro): variavel de mesmo nome herdaria o tipo [string] do parametro
# lista que ja existia mantem o nome e o padrao dela; lista nova leva os do marca.json
$nomeLista = $ORGANIZACAO; if (Valor $antiga "lista_mestra") { $nomeLista = $antiga.lista_mestra }
$padraoLista = $POLITICA;  if (Valor $antiga "padrao") { $padraoLista = $antiga.padrao }
$controle = [ordered]@{
  lista_mestra = $nomeLista; padrao = $padraoLista
  atualizado_em = $agora; documentos = $documentos
}
$json = ConvertTo-Json -InputObject $controle -Depth 6   # -InputObject (e nao pipe): pipe converte o dicionario em texto
$pastaDestino = [IO.Path]::GetDirectoryName($destino)
if ($pastaDestino -and -not (Test-Path -LiteralPath $pastaDestino)) { New-Item -ItemType Directory -Path $pastaDestino | Out-Null }
[IO.File]::WriteAllText($destino, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host ("LISTA MESTRA: {0} ({1} documentos)" -f $destino, $documentos.Count)
