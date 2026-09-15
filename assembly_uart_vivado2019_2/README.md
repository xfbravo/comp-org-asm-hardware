# 汇编实验：UART 命令与排序系统

本目录是汇编工程，唯一目标工具为 Vivado 2019.2，器件为 xc7a35tcsg324-1（EES-338）。独立计组工程未修改；不包含全 CPU 指令覆盖、PPT、视频和报告工作。

## 重建和验证

在本目录打开 PowerShell，安装 Python 3.9 或以上（标准库即可），执行：

```powershell
.\vivado\run_all.ps1 -VivadoPath 'D:\Xilinx_2019\Vivado\2019.2\bin\vivado.bat'
```

统一入口按顺序执行：检查实际工具版本、编码器已知编码对照、检查全部 ROM、重新创建工程、10 组 RTL/CPU/板级测试、IP 打包和独立消费者验证、综合实现、DRC 与 setup/hold 检查、生成 bitstream 及哈希记录。也可以直接运行：

```powershell
python -B .\tools\run_validation.py --mode all
python -B .\tools\run_validation.py --mode regression
python -B .\tools\run_validation.py --mode ip
python -B .\tools\run_validation.py --mode build
```

单独仿真与 IP 入口分别是 `vivado/run_regression.ps1` 和 `vivado/run_ip_smoke.ps1`。每个进程有超时，仿真有全局 watchdog 和失败终止；退出码、Fatal/ERROR、完成标志任意一项不符合都算失败。各仿真在独立目录使用本机 2019.2 的 xvlog/xelab/xsim，避免共享仿真目录的日志争用。

工程文件为 `vivado/asm_uart_2019_2.xpr`，综合顶层 `asm_board_top`，默认 ROM 为 `hello_uart.mem`。也可在 Vivado 2019.2 中 `source vivado/create_project.tcl` 后打开工程。GUI 单项仿真脚本保留为 `run_one_sim.tcl`。

## 命令协议

启动发送 `Hi.\r\n`，初始显示原始值 `0x2026`。不自动回显。主机应整行发送，收到结果后发送下一行。

| 输入 | UART 返回 | 32 位显示寄存器 | 低四位十六进制 |
|---|---|---|---|
| HELP | HELP ADD SORT + CRLF | 保持 | 保持 |
| ADD 12 34 | 46 + CRLF | 0x0000002E | 002E |
| ADD -5 8 | 3 + CRLF | 0x00000003 | 0003 |
| SORT 5 8 2 7 3 | 2 3 5 7 8 + CRLF | 0x00000002 | 0002 |
| ADD 2147483647 1 | ERR + CRLF | 保持 | 保持 |

- 支持 CR、LF、CRLF；CRLF 仅结束一次，空行和全空格行忽略。
- 行最多 64 字节，不含结束符；另保留 NUL 终止字节。超长、非法字符、参数错误、数字越界、加法溢出返回一次 ERR。
- 命令大写；参数为十进制 signed 32 位整数，可带负号，可使用多个空格；不接受加号、TAB 或嵌入 NUL。
- SORT 必须有五个参数，支持负数、重复值和 INT32_MIN/MAX，在 RAM 中执行冒泡排序。
- 解析、排序和十进制格式化全部在 RV32I 汇编中实现，不使用乘除扩展。
- UART 错误导致当前行丢弃至结束符，返回 ERR 后恢复。过载期间结束符也可能丢失，主机须停止发送、等待已有响应，再补发结束符以恢复行边界。
- 已验证有限连续命令突发。8 字节 FIFO 不保证无限连续输入零丢失。
- 数码管是**十六进制**扫描，不是十进制。负数显示补码低位；INT32_MIN 低四位为 0000，完整值请看串口。

RAM 布局：输入缓冲区 256～320，排序数组 384～403，十进制位权表 640～679，栈从 4096 向下。最终命令 ROM 331 个字，容量上限 1024 个字。

## UART 和 MMIO

板级输入 100 MHz，CPU/UART 50 MHz；115200、8N1。分频计数为 434，实际波特率约 115207.37。RX 两级同步，确认起始位中点，然后每位中心单点采样；**没有 8×/16× 多数表决过采样**。错误停止位不入队，持续低电平等待回到高电平才重新接收。

| 地址 | 行为 |
|---|---|
| 0x40000000 | 写 TX；仅 ready 时接受，busy/待接受请求期间不覆盖 |
| 0x40000004 | 读旧队首并立即出队；空读返回 0；读操作清除已有错误 |
| 0x40000008 | 读状态，不清除错误 |
| 0x40000010 | 写 32 位数码管显示值 |

状态布局：bit0=TX ready；bit1=RX 非空；bit2=frame_error；bit3=rx_overrun；bit4=数量≥7；bits8:5=数量 0～8；bits31:9=0。错误为粘滞标志，读 RX 清旧错误，同周期新错误优先。

FIFO 深度 8，读写指针各 3 位，数量 4 位。满且不出队时丢新字节并置溢出；满且同时出队时接受新字节；空队列同时读/收时读返回 0，新字节保留。读取只在事务边沿出队，后续入队不会改变当前队首。

系统 RTL 是 UART 的唯一维护源。打包脚本复制并校验两个 RTL，更新 IP 元数据；消费者从 IP catalog 实例化。消费者仿真使用相同 MMIO 事务，并与重命名的系统 RTL 逐周期比较所有公开输出。

## 测试与程序分工

| 文件/测试 | 用途 |
|---|---|
| asm/hello_uart.S → mem/hello_uart.mem | 最终命令应用 |
| asm/hello_echo.S → mem/hello_echo.mem | 原启动 Hi + 回显回归样例 |
| asm/echo_uart.S → mem/echo_uart.mem | 基础回显，每次发送前等待 TX ready |
| asm/mmio_hazards.S → mem/mmio_hazards.mem | 外设访问冒险专用，不能用作板级默认程序 |
| tb_uart_controller | 全帧 TX、独立队列模型、空满、回绕、同时读写、毛刺、错误和恢复 |
| tb_uart_mmio | 连续 RX 读、pending TX 窗口、状态/错误、显示、地址隔离 |
| tb_data_mem / tb_seven_seg_scan | 字节/半字/字 RAM 及原扫描回归 |
| tb_cpu_uart / tb_cpu_uart_echo | 原 CPU 启动输出与基础回显 |
| tb_cpu_mmio_hazards | 前递优先级、load-use、加载后分支/存储/发送、JAL/JALR 错误路径 |
| tb_cpu_uart_command | 三命令、INT32、参数错误、64/65 字节、CRLF、恢复和有限突发 |
| tb_board_top / tb_board_uart_command | 保留原板级回显；验证默认命令 ROM、同步复位和 R17 页面 |
| tools/test_encoder.py | 独立已知编码、li 展开后标签、负立即数、范围和对齐错误 |
| ip/smoke | 独立 IP 综合、相同事务与逐周期 RTL 对照 |

本次仅验证应用所需 CPU 指令和影响外设的冒险，**不宣称完成全部 CPU 指令覆盖**。修改汇编后执行：

```powershell
python -B .\tools\rv32_encoder.py .\asm\hello_uart.S .\mem\hello_uart.mem
python -B .\tools\verify_mem.py
```

## 上板验收

1. 用 Vivado 2019.2 Hardware Manager 下载 `build/asm_board_top.bit`。
2. 使用板卡实际串口（不固定 COM 号），115200 / 8 data / no parity / 1 stop / no flow control；终端关闭本地回显。
3. 复位并释放，应收到十六进制字节 `48 69 2E 0D 0A`，显示 2026。
4. 分别整行发送表中 HELP、ADD、SORT，逐项确认 UART 文本和十六进制显示。每次等返回后再发下一条。
5. 发送 `ADD 2147483647 1`，应返回 ERR 且保持显示；随后发送 `ADD 1 2`，应返回 3 并显示 0003。
6. R17 页面从 4 开始：4 显示寄存器 → 5 UART 状态 → 6 FIFO 数量 → 7 最近成功结果 → 0 PC → 1 当前指令 → 2 x10 → 3 RAM[0] → 4。最终应用中页面 4/7 显示同一结果。

引脚沿用原约束：T5=100 MHz 时钟，P15=低有效复位，T4=UART TX，N5=UART RX，R17=页面按键。复位异步置位、分别在两个时钟域同步释放。

本次新命令固件的**实际开发板验证待完成**；自动仿真和实现结果不能替代上板验收。

## 交付与清理

最终记录在 `build/verification_all.json`，包含工具版本、逐项结果、RTL/汇编/ROM/约束/脚本/IP 的 SHA-256、实际时钟配置与 bitstream SHA-256。实现报告在 `build/reports/`。总体 PASS 仅代表该记录列出的实际已运行项目；失败时不会输出总体通过。

保留源码、测试、可复现入口、封装 IP、最终验证日志/JSON、实现报告、routed checkpoint 和 bitstream。只清理生成的仿真缓存、packager/consumer 工作目录、临时阶段脚本和重复 journal/日志；不以“没有被 Vivado 引用”作为删除依据。
