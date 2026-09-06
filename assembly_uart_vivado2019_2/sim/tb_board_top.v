`timescale 1ns / 1ps
module tb_board_top;
    localparam integer CLOCK_HZ = 1600;
    localparam integer BAUD_HZ = 100;
    // The board top divides the 10 ns test clock by two for the CPU/UART clock.
    localparam integer BIT_TIME_NS = 320;

    reg clk = 1'b0, rst_n = 1'b0, uart_rxd = 1'b1, key_next = 1'b0;
    wire uart_txd; wire [7:0] anode; wire [7:0] segment;
    wire [31:0] seg7_value;
    assign seg7_value = dut.seg7;
    asm_board_top #(
        .PROGRAM_FILE("hello_uart.mem"),
        .UART_CLOCK_HZ(CLOCK_HZ),
        .UART_BAUD_HZ(BAUD_HZ)
    ) dut(
        .clk(clk), .rst_n(rst_n), .uart_rxd(uart_rxd), .key_next(key_next),
        .uart_txd(uart_txd), .anode(anode), .segment(segment)
    );
    always #5 clk = ~clk;

    integer failures;
    integer cycles;
    reg [7:0] echoed;

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
                $display("BOARD_TX_STOP_BIT_FAIL");
                failures = failures + 1;
            end
        end
    endtask

    task expect_tx_byte;
        input [7:0] expected;
        reg [7:0] received;
        begin
            receive_uart_byte(received);
            if (received !== expected) begin
                $display("BOARD_TX_BYTE_FAIL expected=%02x got=%02x", expected, received);
                failures = failures + 1;
            end else begin
                $display("BOARD_TX_BYTE_PASS %02x", received);
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
        if (uart_txd !== 1'b1) begin
            $display("BOARD_RESET_FAIL");
            failures = failures + 1;
        end
        rst_n = 1'b1;

        expect_tx_byte(8'h48); // H
        expect_tx_byte(8'h69); // i
        expect_tx_byte(8'h2e); // .
        expect_tx_byte(8'h0d); // CR
        expect_tx_byte(8'h0a); // LF

        cycles = 0;
        while (cycles < 2000 && seg7_value !== 32'h00002026) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        if (seg7_value !== 32'h00002026) begin
            $display("BOARD_SEG7_INIT_FAIL value=%08x", seg7_value);
            failures = failures + 1;
        end else begin
            $display("BOARD_SEG7_INIT_PASS value=%08x", seg7_value);
        end

        fork
            send_uart_byte(8'h41);
            receive_uart_byte(echoed);
        join
        if (echoed !== 8'h41) begin
            $display("BOARD_ECHO_BYTE_FAIL expected=41 got=%02x", echoed);
            failures = failures + 1;
        end else begin
            $display("BOARD_ECHO_BYTE_PASS 41");
        end

        cycles = 0;
        while (cycles < 2000 && seg7_value !== 32'h00000041) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        if (seg7_value !== 32'h00000041) begin
            $display("BOARD_SEG7_ECHO_FAIL value=%08x", seg7_value);
            failures = failures + 1;
        end else begin
            $display("BOARD_SEG7_ECHO_PASS value=%08x", seg7_value);
        end

        repeat(16) @(posedge clk);
        if (^anode === 1'bx || ^anode === 1'bz ||
            ^segment === 1'bx || ^segment === 1'bz) begin
            $display("BOARD_DISPLAY_FAIL");
            failures = failures + 1;
        end else begin
            $display("BOARD_DISPLAY_PASS");
        end

        if (failures == 0) $display("BOARD_TOP_TEST_PASSED");
        else $display("BOARD_TOP_TEST_FAILED count=%0d", failures);
        $finish;
    end
endmodule
