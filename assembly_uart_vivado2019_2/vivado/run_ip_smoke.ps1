param([string]$VivadoPath = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -ErrorAction Stop).Source
& $python -B (Join-Path $projectRoot 'tools/run_validation.py') --mode ip --vivado="$VivadoPath"
if ($LASTEXITCODE -ne 0) { throw 'Vivado validation failed; see build logs and verification JSON.' }
