param(
    [string]$VivadoPath = ''
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$packageScript = Join-Path $scriptDir 'package_uart_ip.tcl'
$smokeScript = Join-Path $scriptDir 'run_ip_smoke.tcl'
$component = Join-Path $projectRoot 'ip\uart_mmio_bridge_1_0\component.xml'
$packageLog = Join-Path $scriptDir 'package_uart_ip_vivado.log'
$packageJournal = Join-Path $scriptDir 'package_uart_ip_vivado.jou'
$smokeLog = Join-Path $scriptDir 'ip_smoke_vivado.log'
$smokeJournal = Join-Path $scriptDir 'ip_smoke_vivado.jou'

if ([string]::IsNullOrWhiteSpace($VivadoPath)) {
    $candidates = @(
        $(if ($env:XILINX_VIVADO) { Join-Path $env:XILINX_VIVADO 'bin\vivado.bat' }),
        'C:\Xilinx\Vivado\2019.2\bin\vivado.bat',
        'D:\Xilinx\Vivado\2019.2\bin\vivado.bat',
        'D:\Xilinx_2019\Vivado\2019.2\bin\vivado.bat'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $VivadoPath = $candidates | Select-Object -First 1
}

if (-not $VivadoPath -or -not (Test-Path -LiteralPath $VivadoPath)) {
    throw 'Vivado 2019.2 was not found. Pass -VivadoPath explicitly.'
}

& $VivadoPath -mode batch -log $packageLog -journal $packageJournal -source $packageScript
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $component)) {
    throw 'UART IP packaging failed.'
}
if (-not (Select-String -Path $packageLog -SimpleMatch 'IP_INTEGRITY=1' -Quiet)) {
    throw 'UART IP packaging integrity check did not pass.'
}

& $VivadoPath -mode batch -log $smokeLog -journal $smokeJournal -source $smokeScript
if ($LASTEXITCODE -ne 0) {
    throw "UART IP smoke project failed with Vivado exit code $LASTEXITCODE"
}
if (-not (Select-String -Path $smokeLog -SimpleMatch 'IP_CONSUMER_SYNTHESIS=COMPLETE' -Quiet)) {
    throw 'Clean consumer synthesis did not complete.'
}
if (-not (Select-String -Path $smokeLog -SimpleMatch 'IP_SMOKE_TEST_PASSED' -Quiet)) {
    throw 'UART IP smoke test did not print IP_SMOKE_TEST_PASSED.'
}
$failureMatches = Select-String -Path $smokeLog -Pattern '^\s*[A-Z0-9]+(?:_[A-Z0-9]+)*_(?:FAIL|FAILED)(?:\s|$)'
if ($failureMatches) {
    $details = ($failureMatches | ForEach-Object { $_.Line.Trim() }) -join ' | '
    throw "UART IP smoke test printed failure marker(s): $details"
}
Write-Host 'UART_IP_PACKAGE_PASS'
Write-Host 'UART_IP_SMOKE_PASS'
