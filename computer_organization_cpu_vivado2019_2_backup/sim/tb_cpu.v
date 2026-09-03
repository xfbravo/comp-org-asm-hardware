`timescale 1ns / 1ps

module tb_cpu;
    reg clk;
    reg rst_n;

    wire        halted;
    wire [31:0] pc_current;
    wire        debug_wb_valid;
    wire [31:0] debug_wb_pc;
    wire        debug_wb_reg_write;
    wire [4:0]  debug_wb_rd;
    wire [31:0] debug_wb_data;

    cpu_core #(
        .PROGRAM_FILE("program.mem")
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .halted(halted),
        .pc_current(pc_current),
        .debug_wb_valid(debug_wb_valid),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_reg_write(debug_wb_reg_write),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_data(debug_wb_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    integer cycles;
    integer failures;

    task expect_reg;
        input [4:0] reg_id;
        input [31:0] expected;
        begin
            if (dut.u_reg_file.regs[reg_id] !== expected) begin
                $display("FAIL: x%0d expected %08x, got %08x",
                         reg_id, expected, dut.u_reg_file.regs[reg_id]);
                failures = failures + 1;
            end else begin
                $display("PASS: x%0d = %08x", reg_id, expected);
            end
        end
    endtask

    task expect_mem_word;
        input [31:0] addr;
        input [31:0] expected;
        reg [31:0] actual;
        begin
            actual = {dut.u_data_mem.mem[addr + 3],
                      dut.u_data_mem.mem[addr + 2],
                      dut.u_data_mem.mem[addr + 1],
                      dut.u_data_mem.mem[addr]};
            if (actual !== expected) begin
                $display("FAIL: mem[%0d] expected %08x, got %08x",
                         addr, expected, actual);
                failures = failures + 1;
            end else begin
                $display("PASS: mem[%0d] = %08x", addr, expected);
            end
        end
    endtask

    initial begin
        failures = 0;
        cycles = 0;
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        while (!halted && cycles < 200) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (debug_wb_valid) begin
                $display("WB pc=%08x we=%0d rd=x%0d data=%08x",
                         debug_wb_pc, debug_wb_reg_write, debug_wb_rd, debug_wb_data);
            end
        end

        if (!halted) begin
            $display("FAIL: timeout waiting for ecall");
            failures = failures + 1;
        end

        #1;
        expect_reg(5'd1,  32'd5);
        expect_reg(5'd2,  32'd7);
        expect_reg(5'd3,  32'd12);
        expect_reg(5'd4,  32'd12);
        expect_reg(5'd5,  32'd13);
        expect_reg(5'd6,  32'd1);
        expect_reg(5'd7,  32'h12345000);
        expect_reg(5'd8,  32'h0000102c);
        expect_reg(5'd9,  32'h00000034);
        expect_reg(5'd10, 32'd42);
        expect_reg(5'd11, 32'hffff_ffff);
        expect_reg(5'd12, 32'd0);
        expect_reg(5'd13, 32'd1);
        expect_reg(5'd15, 32'hffff_ffff);
        expect_reg(5'd16, 32'h0000_00ff);
        expect_reg(5'd17, 32'h0000_8000);
        expect_reg(5'd18, 32'hffff_8000);
        expect_reg(5'd19, 32'h0000_8000);
        expect_reg(5'd20, 32'h0000_0070);
        expect_reg(5'd21, 32'h0000_006c);
        expect_reg(5'd22, 32'd22);
        expect_mem_word(32'd0, 32'd12);

        if (failures == 0) begin
            $display("CPU TEST PASSED in %0d cycles", cycles);
        end else begin
            $display("CPU TEST FAILED with %0d failure(s)", failures);
        end

        $finish;
    end
endmodule
