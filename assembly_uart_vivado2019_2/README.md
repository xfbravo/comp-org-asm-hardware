# 汇编实验 UART 计算机系统

本目录是在本组五级流水线 RV32I CPU 基础上完成的汇编实验工程。CPU 通过 MMIO 访问 UART 和八位数码管，适用于 Vivado 2019.2、EES-338 开发板和 `xc7a35tcsg324-1`。

## 已实现功能

- RV32I 五级流水线 CPU、数据前递、Load-Use 停顿和控制流刷新
- UART 发送、接收和状态查询，50 MHz、115200 baud、8N1
- MMIO UART：发送 `0x40000000`、接收 `0x40000004`、状态 `0x40000008`
- MMIO 数码管：写地址 `0x40000010`
- 上电发送 `Hi.\r\n`，随后接收并回显字符
- 数码管扫描接口保留原八路端口，但本实验板级验收使用当前四位显示：默认 `2026`，收到 `A` 后显示 `0041`
- 六组自检：RAM、UART、CPU 发送、CPU 回显、数码管扫描和板级顶层

## 目录

```text
rtl/       CPU、UART、MMIO、数码管和板级顶层
asm/       hello_uart.S 和 echo_uart.S
mem/       Vivado 可直接加载的机器码
sim/       自检 testbench
constr/    EES-338 引脚与时钟约束
tools/     RV32I 汇编编码脚本
vivado/    工程创建、回归、bitstream 构建和 IP 打包脚本
ip/        可复用的 `uart_mmio_bridge` Vivado IP 及干净消费者 smoke test
```

Vivado 生成的工程缓存、日志、波形、报告和 bitstream 不提交到仓库，可由脚本重新生成。

## 创建 Vivado 2019.2 工程

启动 Vivado 2019.2，在 Tcl Console 中切换到本目录并执行：

```tcl
cd D:/path/to/comp-org-asm-hardware/assembly_uart_vivado2019_2
source ./vivado/create_project.tcl
```

脚本会生成：

```text
vivado/asm_uart_2019_2.xpr
```

随后通过 `File > Open Project` 打开该文件。设计顶层应为 `asm_board_top`，默认仿真顶层应为 `tb_cpu_uart`，器件应为 `xc7a35tcsg324-1`。

## 运行全部仿真

在 PowerShell 中进入本目录并运行：

```powershell
.\vivado\run_regression.ps1
```

如果脚本没有自动找到 Vivado，请明确传入路径：

```powershell
.\vivado\run_regression.ps1 -VivadoPath 'C:\Xilinx\Vivado\2019.2\bin\vivado.bat'
```

脚本在工程不存在时会自动创建工程。全部通过时最后输出：

```text
ALL_REGRESSION_TESTS_PASSED
```

## 生成 bitstream

先创建工程，然后从本目录执行：

```powershell
& 'C:\Xilinx\Vivado\2019.2\bin\vivado.bat' -mode batch `
  -source '.\vivado\build_bitstream.tcl'
```

生成结果位于：

```text
build/asm_board_top.bit
```

签核报告位于 `build/reports/`。下载前确认 `drc.rpt` 的违规数为 0，并确认 `timing_summary.rpt` 中所有用户时序约束均满足。

## EES-338 上板

- FPGA：`xc7a35tcsg324-1`
- 时钟：T5，100 MHz
- 低有效复位：P15
- UART TX/RX：T4/N5
- 页面按键：R17
- 串口：115200、8 data bits、no parity、1 stop bit、no flow control

下载 `build/asm_board_top.bit` 后释放复位，串口应显示 `Hi.\r\n`，数码管应显示 `2026`。直接在串口终端按一个字符即可发送，不需要回车；收到 `A` 时应回显 `A`，数码管应变为 `0041`。

R17 按键依次显示 UART 状态、PC、当前指令、x10、RAM 地址 0 和程序显示值。

## 当前验收基线

- 器件：`xc7a35tcsg324-1`；串口：`COM9`，115200、8N1、无流控。
- MMIO：`0x40000000` 发送，`0x40000004` 接收，`0x40000008` 状态，`0x40000010` 数码管数据。
- 板级实测：上电收到 `48 69 2E 0D 0A`（`Hi.\r\n`），发送 `A` 收到 `41`，数码管由 `2026` 更新为 `0041`。
- 签核：六项回归输出 `ALL_REGRESSION_TESTS_PASSED`；IP smoke 输出 `UART_IP_PACKAGE_PASS`、`UART_IP_SMOKE_PASS`；实现报告 `DRC=0`、`WNS=3.269 ns`、`TNS=0 ns`。
- 当前 `build/asm_board_top.bit`：2,192,121 bytes，SHA-256 `C24AFA982E269C042E95F068BA16772CF2441DD51F21D59A092A1B8F58055EF5`。

## 修改汇编程序

修改 `.S` 后重新生成机器码：

```powershell
python .\tools\rv32_encoder.py .\asm\hello_uart.S .\mem\hello_uart.mem
python .\tools\rv32_encoder.py .\asm\echo_uart.S .\mem\echo_uart.mem
```

重新运行仿真和 bitstream 构建即可。

## 打包和验证 UART IP

`uart_mmio_bridge` 的 IP 元数据为 `bit.edu.cn:interface:uart_mmio_bridge:1.0`，封装内容包含 `uart_mmio_bridge.v` 和 `uart_controller.v`。打包、干净工程综合及行为 smoke test 使用：

```powershell
.\vivado\run_ip_smoke.ps1 -VivadoPath 'D:\Xilinx\Vivado\2019.2\bin\vivado.bat'
```

通过时输出 `UART_IP_PACKAGE_PASS` 和 `UART_IP_SMOKE_PASS`。smoke test 覆盖 MMIO 发送 `0x41`、接收 `0x5A`、状态读取、读后清零和数码管写入。
