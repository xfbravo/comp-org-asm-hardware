# UART MMIO Bridge IP（Vivado 2019.2）

VLNV：`bit.edu.cn:interface:uart_mmio_bridge:1.0`。
维护源仅为项目 `rtl/uart_controller.v` 和 `rtl/uart_mmio_bridge.v`；不要直接修改包内副本。
参数 CLOCK_HZ 默认 50000000，BAUD_HZ 默认 115200，FIFO 固定 8 字节。

| 地址 | 行为 |
|---|---|
| 0x40000000 | TX 写；仅在 ready=1 时接受 |
| 0x40000004 | RX 读旧队首并在本次边沿出队；空读返回 0；清除已有错误 |
| 0x40000008 | 读状态，保持错误标志 |
| 0x40000010 | 写 32 位显示寄存器 |

状态：bit0 TX ready（包含 busy 和待接受的 tx_start），bit1 RX 非空，bit2 帧错误，bit3 溢出，bit4 数量≥7，bits8:5 数量0～8，bits31:9=0。新错误与清除同周期发生时，新错误优先。

每个 clk 上升沿是一次 MMIO 事务。连续周期的 mmio_read 可读取不同队首；uart_rx_ack 是当前 RX 地址读事务的组合确认，不能再额外延迟一拍。seg7_we 和 tx_start 是寄存输出。

rst_n 异步有效，消费者应在 clk 域同步释放；本项目板级顶层已实现同步释放。RX 两级同步、起始位中点确认、逐位中心单点采样、停止位检查；无多数表决过采样。错误停止位丢弃该帧，持续低电平等待高电平恢复。

在汇编项目目录运行：

```powershell
.\vivado\run_ip_smoke.ps1 -VivadoPath 'D:\Xilinx_2019\Vivado\2019.2\bin\vivado.bat'
```

脚本从维护源复制并重打包，检查完整性和副本一致性；独立消费者通过 IP catalog 生成目标并综合。消费者仿真复用 `sim/tb_uart_mmio.v` 的事务，与临时重命名的系统 RTL 逐周期比较全部公开输出，同时检查 TX 位流、连续 RX 出队、状态、错误与数码管。参考 RTL 仅供仿真，消费者综合不依赖它。

完成标志为 UART_IP_PACKAGE_PASS 和 UART_IP_SMOKE_PASS。最终日志和哈希记录位于 build；packager/consumer 缓存自动清理，封装 HDL、component.xml 和 xgui 元数据保留。
