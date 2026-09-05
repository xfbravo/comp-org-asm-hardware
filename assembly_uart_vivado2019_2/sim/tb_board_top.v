`timescale 1ns / 1ps
module tb_board_top;
    reg clk = 1'b0, rst_n = 1'b0, uart_rxd = 1'b1, key_next = 1'b0;
    wire uart_txd; wire [7:0] anode; wire [7:0] segment;
    asm_board_top dut(.clk(clk),.rst_n(rst_n),.uart_rxd(uart_rxd),.key_next(key_next),
                      .uart_txd(uart_txd),.anode(anode),.segment(segment));
    always #5 clk = ~clk;
    initial begin
        repeat(4) @(posedge clk);
        if (uart_txd !== 1'b1) $display("BOARD_RESET_FAIL");
        rst_n = 1'b1;
        // Keep the test alive beyond Vivado's automatic 1000 ns launch window.
        repeat(120) @(posedge clk);
        if (^anode === 1'bx || ^segment === 1'bx) $display("BOARD_DISPLAY_FAIL");
        else $display("BOARD_TOP_PORTS_PASS");
        $finish;
    end
endmodule
