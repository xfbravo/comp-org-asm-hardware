`timescale 1ns / 1ps

module uart_controller #(
    parameter CLOCK_HZ = 50_000_000,
    parameter BAUD_HZ  = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output wire       tx,
    input  wire       rx,
    output reg [7:0]  rx_data,
    output reg        rx_ready,
    input  wire       rx_ack
);
    localparam integer BAUD_DIV = (CLOCK_HZ / BAUD_HZ < 1) ? 1 : CLOCK_HZ / BAUD_HZ;
    reg [15:0] tx_count;
    reg [3:0]  tx_bit;
    reg [9:0]  tx_shift;
    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    reg [15:0] rx_count;
    reg [3:0]  rx_bit;
    reg [7:0]  rx_shift;
    reg        rx_active;
    reg        rx_meta;
    reg        rx_sync;

    // UART RX is asynchronous to the local clock. Synchronize it before
    // start-bit detection to prevent metastability from reaching the FSM.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_count <= 0; tx_bit <= 0; tx_shift <= 10'h3ff; tx_busy <= 1'b0;
        end else if (!tx_busy) begin
            if (tx_start) begin
                tx_shift <= {1'b1, tx_data, 1'b0};
                tx_count <= 0; tx_bit <= 0; tx_busy <= 1'b1;
            end
        end else if (tx_count == BAUD_DIV-1) begin
            tx_count <= 0;
            if (tx_bit == 4'd9) begin
                tx_busy <= 1'b0; tx_shift <= 10'h3ff;
            end else begin
                tx_bit <= tx_bit + 1'b1;
                tx_shift <= {1'b1, tx_shift[9:1]};
            end
        end else begin
            tx_count <= tx_count + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_count <= 0; rx_bit <= 0; rx_shift <= 0;
            rx_active <= 1'b0; rx_data <= 0; rx_ready <= 1'b0;
        end else begin
            if (rx_ack) rx_ready <= 1'b0;
            if (!rx_active) begin
                if (!rx_sync) begin
                    rx_active <= 1'b1; rx_count <= BAUD_DIV + BAUD_DIV/2; rx_bit <= 0;
                end
            end else if (rx_count == 0) begin
                if (rx_bit < 4'd8) begin
                    rx_shift[rx_bit] <= rx_sync;
                    rx_bit <= rx_bit + 1'b1;
                    rx_count <= BAUD_DIV-1;
                end else begin
                    rx_active <= 1'b0;
                    rx_data <= rx_shift;
                    rx_ready <= 1'b1;
                end
            end else begin
                rx_count <= rx_count - 1'b1;
            end
        end
    end
endmodule
