@echo off
rem Inventariar.cmd - atalho para rodar o Inventariar.ps1 sem esbarrar na politica de execucao.
rem Use de dois jeitos: arraste a pasta dos documentos em cima deste arquivo,
rem ou de duplo clique e digite o caminho quando ele perguntar.
rem O marca.json da organizacao fica na mesma pasta deste arquivo (ou em TIMBRADOR_MARCA).
setlocal
set "PASTA=%~1"
if "%PASTA%"=="" set /p PASTA=Caminho da pasta dos documentos (ex.: G:\Documentos):
if "%PASTA%"=="" goto fim
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inventariar.ps1" -Pasta "%PASTA%"
:fim
echo.
pause
