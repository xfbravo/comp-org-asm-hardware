param(
    [string]$VivadoPath = ''
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

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
    throw 'Vivado 2019.2 was not found. Run again with -VivadoPath "C:\path\to\Vivado\2019.2\bin\vivado.bat".'
}

$projectFile = Join-Path $scriptDir 'asm_uart_2019_2.xpr'
if (-not (Test-Path -LiteralPath $projectFile)) {
    & $VivadoPath -mode batch -log (Join-Path $scriptDir 'create_project.log') `
        -journal (Join-Path $scriptDir 'create_project.jou') `
        -source (Join-Path $scriptDir 'create_project.tcl')
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $projectFile)) {
        throw 'Vivado project creation failed.'
    }
}

$tests = @(
    @{ Top = 'tb_data_mem';        Marker = 'DATA_MEM_TEST_PASSED' },
    @{ Top = 'tb_uart_controller'; Marker = 'UART_RX_PASS' },
    @{ Top = 'tb_cpu_uart';        Marker = 'CPU_UART_TEST_PASSED' },
    @{ Top = 'tb_cpu_uart_echo';   Marker = 'CPU_UART_ECHO_TEST_PASSED' },
    @{ Top = 'tb_seven_seg_scan';  Marker = 'SEVEN_SEG_2026_TEST_PASSED' },
    @{ Top = 'tb_board_top';       Marker = 'BOARD_TOP_PORTS_PASS' }
)

Push-Location $projectRoot
try {
    foreach ($test in $tests) {
        $top = $test.Top
        $log = Join-Path $scriptDir "${top}_vivado.log"
        $journal = Join-Path $scriptDir "${top}_vivado.jou"
        & $VivadoPath -mode batch -log $log -journal $journal `
            -source (Join-Path $scriptDir 'run_one_sim.tcl') -tclargs $top
        if ($LASTEXITCODE -ne 0) {
            throw "$top failed with Vivado exit code $LASTEXITCODE"
        }
        if (-not (Select-String -Path $log -SimpleMatch $test.Marker -Quiet)) {
            throw "$top did not print expected marker: $($test.Marker)"
        }
        Write-Host "REGRESSION_PASS $top"
    }
    Write-Host 'ALL_REGRESSION_TESTS_PASSED'
}
finally {
    Pop-Location
}
