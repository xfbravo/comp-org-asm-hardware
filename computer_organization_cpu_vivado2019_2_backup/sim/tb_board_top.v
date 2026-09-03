`timescale 1ns / 1ps

module tb_board_top;
    reg clk;
    reg rst_n;
    reg [15:0] switches;

    wire [15:0] leds;
    wire [7:0]  seg_an;
    wire [7:0]  seg;
    wire        halted;

    integer cycles;
    integer failures;

    board_top #(
        .PROGRAM_FILE("program.mem"),
        .REFRESH_BITS(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .leds(leds),
        .seg_an(seg_an),
        .seg(seg),
        .halted(halted)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task expect_display;
        input [2:0] mode;
        input [31:0] expected;
        begin
            switches[2:0] = mode;
            #1;
            if (dut.display_value !== expected) begin
                $display("FAIL: display mode %0d expected %08x, got %08x",
                         mode, expected, dut.display_value);
                failures = failures + 1;
            end else begin
                $display("PASS: display mode %0d = %08x", mode, expected);
            end
        end
    endtask

    initial begin
        failures = 0;
        cycles = 0;
        switches = 16'd0;
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        while (!halted && cycles < 200) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!halted) begin
            $display("FAIL: board_top timeout waiting for halted");
            failures = failures + 1;
        end

        #1;
        expect_display(3'd0, dut.pc_current);
        expect_display(3'd1, dut.debug_wb_pc);
        expect_display(3'd2, {26'd0, dut.debug_wb_reg_write, dut.debug_wb_rd});
        expect_display(3'd3, dut.debug_wb_data);
        expect_display(3'd4, {31'd0, halted});

        if (leds[15] !== halted) begin
            $display("FAIL: leds[15] does not mirror halted");
            failures = failures + 1;
        end else begin
            $display("PASS: leds[15] mirrors halted");
        end

        repeat (16) @(posedge clk);
        if (seg_an === 8'hff || ^seg_an === 1'bx || ^seg === 1'bx) begin
            $display("FAIL: seven-segment output is invalid");
            failures = failures + 1;
        end else begin
            $display("PASS: seven-segment output is active");
        end

        if (failures == 0) begin
            $display("BOARD TOP TEST PASSED in %0d cycles", cycles);
        end else begin
            $display("BOARD TOP TEST FAILED with %0d failure(s)", failures);
        end

        $finish;
    end
endmodule
