`timescale 1ns / 1ps

module tb_uart_mmio_bridge_ip;
    localparam integer CLOCK_HZ = 1600;
    localparam integer BAUD_HZ = 100;
    localparam integer BIT_TIME_NS = 160;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg mmio_read = 1'b0;
    reg mmio_write = 1'b0;
    reg [31:0] mmio_addr = 32'd0;
    reg [31:0] mmio_wdata = 32'd0;
    reg uart_rxd = 1'b1;
    wire uart_txd;
    wire [31:0] mmio_rdata;
    wire uart_tx_busy;
    wire uart_rx_ready;
    wire [7:0] uart_rx_data;
    wire uart_tx_start;
    wire [7:0] uart_tx_data;
    wire uart_rx_ack;
    wire seg7_we;
    wire [31:0] seg7_value;

    integer failures;
    reg [7:0] received;
    reg [31:0] status;
    reg [31:0] rx_word;

    uart_mmio_bridge_consumer dut (
        .clk(clk), .rst_n(rst_n),
        .mmio_read(mmio_read), .mmio_write(mmio_write),
        .mmio_addr(mmio_addr), .mmio_wdata(mmio_wdata),
        .mmio_rdata(mmio_rdata),
        .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .uart_tx_busy(uart_tx_busy), .uart_rx_ready(uart_rx_ready),
        .uart_rx_data(uart_rx_data), .uart_tx_start(uart_tx_start),
        .uart_tx_data(uart_tx_data), .uart_rx_ack(uart_rx_ack),
        .seg7_we(seg7_we), .seg7_value(seg7_value)
    );

    always #5 clk = ~clk;

    task mmio_write_word;
        input [31:0] address;
        input [31:0] data;
        begin
            @(negedge clk);
            mmio_addr = address;
            mmio_wdata = data;
            mmio_write = 1'b1;
            @(negedge clk);
            mmio_write = 1'b0;
        end
    endtask

    task mmio_read_word;
        input [31:0] address;
        output [31:0] data;
        begin
            @(negedge clk);
            mmio_addr = address;
            mmio_read = 1'b1;
            #1 data = mmio_rdata;
            @(negedge clk);
            mmio_read = 1'b0;
        end
    endtask

    task receive_uart_byte;
        output [7:0] data;
        integer bit_index;
        begin
            @(negedge uart_txd);
            #(BIT_TIME_NS + BIT_TIME_NS / 2);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                data[bit_index] = uart_txd;
                #(BIT_TIME_NS);
            end
            if (uart_txd !== 1'b1) begin
                $display("IP_TX_STOP_BIT_FAIL");
                failures = failures + 1;
            end
        end
    endtask

    task send_uart_byte;
        input [7:0] data;
        integer bit_index;
        begin
            uart_rxd = 1'b0;
            #(BIT_TIME_NS);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rxd = data[bit_index];
                #(BIT_TIME_NS);
            end
            uart_rxd = 1'b1;
            #(BIT_TIME_NS);
        end
    endtask

    initial begin
        failures = 0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;

        mmio_write_word(32'h4000_0010, 32'h1234_5678);
        #1;
        if (seg7_value !== 32'h1234_5678 || !seg7_we) begin
            $display("IP_SEG7_WRITE_FAIL value=%08x we=%b", seg7_value, seg7_we);
            failures = failures + 1;
        end else begin
            $display("IP_SEG7_WRITE_PASS");
        end

        fork
            begin
                mmio_write_word(32'h4000_0000, 32'h0000_0041);
            end
            begin
                receive_uart_byte(received);
            end
        join
        if (received !== 8'h41) begin
            $display("IP_TX_BYTE_FAIL expected=41 got=%02x", received);
            failures = failures + 1;
        end else begin
            $display("IP_TX_BYTE_PASS 41");
        end

        send_uart_byte(8'h5a);
        wait (uart_rx_ready);
        mmio_read_word(32'h4000_0008, status);
        if (status[1] !== 1'b1) begin
            $display("IP_RX_STATUS_FAIL status=%08x", status);
            failures = failures + 1;
        end else begin
            $display("IP_RX_STATUS_PASS status=%08x", status);
        end
        mmio_read_word(32'h4000_0004, rx_word);
        if (rx_word[7:0] !== 8'h5a) begin
            $display("IP_RX_DATA_FAIL expected=5a got=%02x", rx_word[7:0]);
            failures = failures + 1;
        end else begin
            $display("IP_RX_DATA_PASS 5a");
        end
        // The bridge asserts rx_ack for one clock after the read handshake;
        // allow the UART controller's next clock to consume it.
        repeat(2) @(posedge clk);
        #1;
        if (uart_rx_ready !== 1'b0) begin
            $display("IP_RX_ACK_FAIL");
            failures = failures + 1;
        end else begin
            $display("IP_RX_ACK_PASS");
        end

        if (failures == 0) $display("IP_SMOKE_TEST_PASSED");
        else $display("IP_SMOKE_TEST_FAILED count=%0d", failures);
        $finish;
    end
endmodule
