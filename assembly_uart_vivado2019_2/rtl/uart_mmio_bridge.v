`timescale 1ns / 1ps

module uart_mmio_bridge #(
    parameter CLOCK_HZ = 50_000_000,
    parameter BAUD_HZ = 115200
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mmio_read,
    input  wire        mmio_write,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    output reg  [31:0] mmio_rdata,
    input  wire        uart_rxd,
    output wire        uart_txd,
    output wire        uart_tx_busy,
    output wire        uart_rx_ready,
    output wire [7:0]  uart_rx_data,
    output reg         uart_tx_start,
    output reg  [7:0]  uart_tx_data,
    output reg         uart_rx_ack,
    output reg         seg7_we,
    output reg  [31:0] seg7_value
);
    wire tx_room = ~uart_tx_busy;
    uart_controller #(.CLOCK_HZ(CLOCK_HZ), .BAUD_HZ(BAUD_HZ)) u_uart (
        .clk(clk), .rst_n(rst_n), .tx_data(uart_tx_data), .tx_start(uart_tx_start),
        .tx_busy(uart_tx_busy), .tx(uart_txd), .rx(uart_rxd),
        .rx_data(uart_rx_data), .rx_ready(uart_rx_ready), .rx_ack(uart_rx_ack)
    );
    always @(*) begin
        case (mmio_addr)
            32'h4000_0004: mmio_rdata = {24'd0, uart_rx_data};
            32'h4000_0008: mmio_rdata = {30'd0, uart_rx_ready, tx_room};
            default:      mmio_rdata = 32'd0;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_start <= 1'b0; uart_tx_data <= 8'd0; uart_rx_ack <= 1'b0;
            seg7_we <= 1'b0; seg7_value <= 32'd0;
        end else begin
            uart_tx_start <= 1'b0; uart_rx_ack <= 1'b0; seg7_we <= 1'b0;
            if (mmio_write && mmio_addr == 32'h4000_0000 && !uart_tx_busy) begin
                uart_tx_data <= mmio_wdata[7:0]; uart_tx_start <= 1'b1;
            end
            if (mmio_read && mmio_addr == 32'h4000_0004 && uart_rx_ready)
                uart_rx_ack <= 1'b1;
            if (mmio_write && mmio_addr == 32'h4000_0010) begin
                seg7_value <= mmio_wdata; seg7_we <= 1'b1;
            end
        end
    end
endmodule
