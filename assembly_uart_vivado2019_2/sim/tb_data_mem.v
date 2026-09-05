`timescale 1ns / 1ps
`include "cpu_defs.vh"

module tb_data_mem;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg mem_read = 1'b0;
    reg mem_write = 1'b0;
    reg [1:0] mem_size = `MEM_WORD;
    reg load_unsigned = 1'b0;
    reg [31:0] addr = 32'd0;
    reg [31:0] write_data = 32'd0;
    wire [31:0] read_data;
    wire [31:0] debug_word0;
    integer failures = 0;

    data_mem #(.MEM_BYTES(256), .ADDR_BITS(8)) dut (
        .clk(clk), .rst_n(rst_n), .mem_read(mem_read), .mem_write(mem_write),
        .mem_size(mem_size), .load_unsigned(load_unsigned), .addr(addr),
        .write_data(write_data), .read_data(read_data), .debug_word0(debug_word0)
    );

    always #5 clk = ~clk;

    task check_read;
        input [31:0] test_addr;
        input [1:0] test_size;
        input test_unsigned;
        input [31:0] expected;
        begin
            addr = test_addr;
            mem_size = test_size;
            load_unsigned = test_unsigned;
            mem_read = 1'b1;
            #1;
            if (read_data !== expected) begin
                $display("DATA_MEM_READ_FAIL addr=%0d expected=%08x got=%08x", test_addr, expected, read_data);
                failures = failures + 1;
            end
            mem_read = 1'b0;
        end
    endtask

    task do_write;
        input [31:0] test_addr;
        input [1:0] test_size;
        input [31:0] value;
        begin
            addr = test_addr;
            mem_size = test_size;
            write_data = value;
            mem_write = 1'b1;
            @(posedge clk);
            #1;
            mem_write = 1'b0;
        end
    endtask

    initial begin
        #1100;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        do_write(0, `MEM_WORD, 32'h80ff_7f01);
        check_read(0, `MEM_WORD, 1'b0, 32'h80ff_7f01);
        check_read(2, `MEM_BYTE, 1'b0, 32'hffff_ffff);
        check_read(2, `MEM_BYTE, 1'b1, 32'h0000_00ff);
        check_read(3, `MEM_BYTE, 1'b0, 32'hffff_ff80);
        check_read(0, `MEM_HALF, 1'b0, 32'h0000_7f01);
        check_read(2, `MEM_HALF, 1'b0, 32'hffff_80ff);
        check_read(2, `MEM_HALF, 1'b1, 32'h0000_80ff);
        do_write(1, `MEM_BYTE, 32'h0000_00aa);
        check_read(0, `MEM_WORD, 1'b0, 32'h80ff_aa01);
        do_write(2, `MEM_HALF, 32'h0000_1234);
        check_read(0, `MEM_WORD, 1'b0, 32'h1234_aa01);
        if (debug_word0 !== 32'h1234_aa01) begin
            $display("DATA_MEM_DEBUG_FAIL got=%08x", debug_word0);
            failures = failures + 1;
        end
        if (failures == 0) $display("DATA_MEM_TEST_PASSED");
        else $display("DATA_MEM_TEST_FAILED count=%0d", failures);
        $finish;
    end
endmodule
