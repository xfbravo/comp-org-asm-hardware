# UART MMIO Bridge IP

This directory contains the packaged custom IP required by the assembly and
interface course design.

## Interface contract

The top-level IP is `uart_mmio_bridge`. Its public parameters are:

- `CLOCK_HZ`: UART clock frequency, default `50000000`;
- `BAUD_HZ`: UART baud rate, default `115200`.

The MMIO map is fixed:

| Address | Access | Meaning |
| --- | --- | --- |
| `0x40000000` | write | transmit low byte |
| `0x40000004` | read | received byte |
| `0x40000008` | read | bit 0 transmit-ready, bit 1 receive-ready |
| `0x40000010` | write | seven-segment display value |

The package includes `uart_mmio_bridge.v` and its internal
`uart_controller.v` dependency. The public port list is intentionally kept
identical to the tested RTL bridge so it can be inserted at the CPU MMIO
boundary without changing the CPU or address map.

## Clock, reset, and UART electrical contract

- `clk` is the rising-edge synchronous clock. Set `CLOCK_HZ` to its actual
  frequency; the default is 50 MHz.
- `rst_n` is an asynchronous active-low reset and must be released high before
  MMIO transactions.
- `uart_rxd` and `uart_txd` are single-ended 3.3 V LVCMOS-level UART signals
  external to the IP. The idle level is high and the protocol is 115200 baud,
  8 data bits, no parity, one stop bit (8N1) by default. The board-level XDC
  assigns the EES-338 pins and I/O standard.
- `mmio_read` and `mmio_write` are one-cycle request strobes in the `clk`
  domain. `mmio_addr` and `mmio_wdata` must remain valid for the request
  cycle. `uart_rx_ack` and `seg7_we` are one-cycle output strobes.

## Rebuild the package

From Vivado 2019.2 Tcl:

```tcl
cd D:/path/to/comp-org-asm-hardware/assembly_uart_vivado2019_2
source ./vivado/package_uart_ip.tcl
```

The generated package root is `ip/uart_mmio_bridge_1_0/component.xml`.
Vivado work products are written below `ip/packager_work/` and are ignored by
Git.

## Smoke test

The smoke test creates a fresh consumer project, adds this directory as a
custom IP repository, instantiates the IP through the catalog, and verifies
MMIO transmit, receive, acknowledge, and seven-segment writes.

```powershell
.\vivado\run_ip_smoke.ps1 -VivadoPath 'D:\Xilinx\Vivado\2019.2\bin\vivado.bat'
```
