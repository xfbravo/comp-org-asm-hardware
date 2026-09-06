`timescale 1ns / 1ps

// Minimal clean-project consumer. It depends only on the packaged IP
// repository; no source from the parent CPU project is referenced here.
module uart_mmio_bridge_consumer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mmio_read,
    input  wire        mmio_write,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    output wire [31:0] mmio_rdata,
    input  wire        uart_rxd,
    output wire        uart_txd,
    output wire        uart_tx_busy,
    output wire        uart_rx_ready,
    output wire [7:0]  uart_rx_data,
    output wire        uart_tx_start,
    output wire [7:0]  uart_tx_data,
    output wire        uart_rx_ack,
    output wire        seg7_we,
    output wire [31:0] seg7_value
);
    uart_mmio_bridge_0 u_uart_mmio_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .mmio_read(mmio_read),
        .mmio_write(mmio_write),
        .mmio_addr(mmio_addr),
        .mmio_wdata(mmio_wdata),
        .mmio_rdata(mmio_rdata),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .uart_tx_busy(uart_tx_busy),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_data(uart_rx_data),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data(uart_tx_data),
        .uart_rx_ack(uart_rx_ack),
        .seg7_we(seg7_we),
        .seg7_value(seg7_value)
    );
endmodule
