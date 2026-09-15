`timescale 1ns / 1ps
// Single centre sample per bit, two-stage input synchronizer; no oversampling.
module uart_controller #(parameter CLOCK_HZ=50_000_000, parameter BAUD_HZ=115200)(
    input wire clk, input wire rst_n, input wire [7:0] tx_data, input wire tx_start,
    output reg tx_busy, output wire tx, input wire rx, output wire [7:0] rx_data,
    output wire rx_ready, input wire rx_ack, output reg frame_error,
    output reg rx_overrun, output wire [3:0] rx_level
);
    localparam integer BAUD_DIV = (CLOCK_HZ/BAUD_HZ < 2) ? 2 : CLOCK_HZ/BAUD_HZ;
    localparam IDLE=0, START=1, DATA=2, STOP=3, RECOVER=4;
    localparam integer COUNT_BITS = (BAUD_DIV <= 2) ? 1 : $clog2(BAUD_DIV);
    reg [COUNT_BITS-1:0] tx_count, rx_count;
    reg [3:0] tx_bit;
    reg [2:0] rx_bit, rx_state;
    reg [9:0] tx_shift;
    reg [7:0] rx_shift;
    (* ASYNC_REG="TRUE" *) reg rx_meta, rx_sync;
    reg [7:0] fifo [0:7];
    reg [2:0] wr_ptr, rd_ptr;
    reg [3:0] fifo_count;
    wire arrival = rx_state == STOP && rx_count == 0 && rx_sync;
    wire bad_frame = rx_state == STOP && rx_count == 0 && !rx_sync;
    wire pop = rx_ack && fifo_count != 0;
    wire push = arrival && (fifo_count < 8 || pop);
    assign rx_ready = fifo_count != 0;
    assign rx_level = fifo_count;
    assign rx_data = rx_ready ? fifo[rd_ptr] : 8'd0;
    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rx_meta <= 1; rx_sync <= 1; end
        else begin rx_meta <= rx; rx_sync <= rx_meta; end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_count <= 0; tx_bit <= 0; tx_shift <= 10'h3ff; tx_busy <= 0;
        end else if (!tx_busy) begin
            if (tx_start) begin
                tx_shift <= {1'b1,tx_data,1'b0}; tx_count <= 0; tx_bit <= 0; tx_busy <= 1;
            end
        end else if (tx_count == BAUD_DIV-1) begin
            tx_count <= 0;
            if (tx_bit == 9) begin tx_busy <= 0; tx_shift <= 10'h3ff; end
            else begin tx_bit <= tx_bit+1'b1; tx_shift <= {1'b1,tx_shift[9:1]}; end
        end else tx_count <= tx_count+1'b1;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE; rx_count <= 0; rx_bit <= 0; rx_shift <= 0;
        end else case (rx_state)
            IDLE: if (!rx_sync) begin rx_state <= START; rx_count <= BAUD_DIV/2-1; end
            START: if (rx_count != 0) rx_count <= rx_count-1'b1;
                   else if (rx_sync) rx_state <= IDLE;
                   else begin rx_state <= DATA; rx_count <= BAUD_DIV-1; rx_bit <= 0; end
            DATA: if (rx_count != 0) rx_count <= rx_count-1'b1;
                  else begin
                      rx_shift[rx_bit] <= rx_sync; rx_count <= BAUD_DIV-1;
                      if (rx_bit == 7) rx_state <= STOP;
                      else rx_bit <= rx_bit+1'b1;
                  end
            STOP: if (rx_count != 0) rx_count <= rx_count-1'b1;
                  else if (rx_sync) rx_state <= IDLE;
                  else rx_state <= RECOVER;
            RECOVER: if (rx_sync) rx_state <= IDLE;
            default: rx_state <= IDLE;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0; rd_ptr <= 0; fifo_count <= 0;
            frame_error <= 0; rx_overrun <= 0;
        end else begin
            // Any RX address read clears old errors; a new error has priority.
            if (rx_ack) begin frame_error <= 0; rx_overrun <= 0; end
            if (bad_frame) frame_error <= 1;
            if (arrival && !push) rx_overrun <= 1;
            if (push) begin fifo[wr_ptr] <= rx_shift; wr_ptr <= wr_ptr+1'b1; end
            if (pop) rd_ptr <= rd_ptr+1'b1;
            case ({push,pop})
                2'b10: fifo_count <= fifo_count+1'b1;
                2'b01: fifo_count <= fifo_count-1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule
