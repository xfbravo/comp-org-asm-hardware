`timescale 1ns / 1ps

// 冒泡排序程序的五级流水线 CPU 测试平台。
// program.mem 中 x8 指向数组首地址 16；x9 的 AUIPC 位于 PC=8，
// 随后的 lw x9,4(x9) 因而读取地址 12 处的数组长度 5。
module tb_pipeline_cpu1;
    reg clk;
    reg rst_n;
    wire halted;
    wire [31:0] pc_current;
    wire debug_wb_valid;
    wire [31:0] debug_wb_pc;
    wire debug_wb_reg_write;
    wire [4:0] debug_wb_rd;
    wire [31:0] debug_wb_data;

    integer total_cycles;
    integer total_insts;
    integer load_use_stalls;
    integer redirects;
    real cpi;
    real ipc;

    cpu_core #(
        .PROGRAM_FILE("program.mem"),
        .IMEM_WORDS(1024),
        .IMEM_ADDR_BITS(10),
        .DMEM_BYTES(4096),
        .DMEM_ADDR_BITS(12)
    ) u_cpu (
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

    task init_data_memory;
        begin
            // little-endian: [12..15] = 5，数组 [16..35] = {5,8,2,7,3}
            u_cpu.u_data_mem.mem[12] = 8'd5;
            u_cpu.u_data_mem.mem[13] = 8'd0;
            u_cpu.u_data_mem.mem[14] = 8'd0;
            u_cpu.u_data_mem.mem[15] = 8'd0;

            u_cpu.u_data_mem.mem[16] = 8'd5;
            u_cpu.u_data_mem.mem[17] = 8'd0;
            u_cpu.u_data_mem.mem[18] = 8'd0;
            u_cpu.u_data_mem.mem[19] = 8'd0;
            u_cpu.u_data_mem.mem[20] = 8'd8;
            u_cpu.u_data_mem.mem[21] = 8'd0;
            u_cpu.u_data_mem.mem[22] = 8'd0;
            u_cpu.u_data_mem.mem[23] = 8'd0;
            u_cpu.u_data_mem.mem[24] = 8'd2;
            u_cpu.u_data_mem.mem[25] = 8'd0;
            u_cpu.u_data_mem.mem[26] = 8'd0;
            u_cpu.u_data_mem.mem[27] = 8'd0;
            u_cpu.u_data_mem.mem[28] = 8'd7;
            u_cpu.u_data_mem.mem[29] = 8'd0;
            u_cpu.u_data_mem.mem[30] = 8'd0;
            u_cpu.u_data_mem.mem[31] = 8'd0;
            u_cpu.u_data_mem.mem[32] = 8'd3;
            u_cpu.u_data_mem.mem[33] = 8'd0;
            u_cpu.u_data_mem.mem[34] = 8'd0;
            u_cpu.u_data_mem.mem[35] = 8'd0;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        total_cycles = 0;
        total_insts = 0;
        load_use_stalls = 0;
        redirects = 0;

        // 保持复位跨过两个上升沿，确保寄存器堆和数据存储器已清零。
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        #1 init_data_memory;

        $display("============================================");
        $display("  五级流水线 CPU：冒泡排序仿真开始");
        $display("============================================");

        // #1 确保采样的是该上升沿后流水线寄存器更新完成的值。
        while (!halted && total_cycles < 1000) begin
            @(posedge clk);
            #1;
            total_cycles = total_cycles + 1;
            if (debug_wb_valid && !halted)
                total_insts = total_insts + 1;
            if (u_cpu.stall)
                load_use_stalls = load_use_stalls + 1;
            if (u_cpu.redirect_ex)
                redirects = redirects + 1;
        end

        if (total_cycles >= 1000) begin
            $display("FAIL: 程序在 1000 个周期内未执行到 ecall。");
        end else if ({u_cpu.u_data_mem.mem[19], u_cpu.u_data_mem.mem[18],
                      u_cpu.u_data_mem.mem[17], u_cpu.u_data_mem.mem[16]} != 32'd2 ||
                     {u_cpu.u_data_mem.mem[23], u_cpu.u_data_mem.mem[22],
                      u_cpu.u_data_mem.mem[21], u_cpu.u_data_mem.mem[20]} != 32'd3 ||
                     {u_cpu.u_data_mem.mem[27], u_cpu.u_data_mem.mem[26],
                      u_cpu.u_data_mem.mem[25], u_cpu.u_data_mem.mem[24]} != 32'd5 ||
                     {u_cpu.u_data_mem.mem[31], u_cpu.u_data_mem.mem[30],
                      u_cpu.u_data_mem.mem[29], u_cpu.u_data_mem.mem[28]} != 32'd7 ||
                     {u_cpu.u_data_mem.mem[35], u_cpu.u_data_mem.mem[34],
                      u_cpu.u_data_mem.mem[33], u_cpu.u_data_mem.mem[32]} != 32'd8) begin
            $display("FAIL: 排序结果不是 [2, 3, 5, 7, 8]。");
        end else begin
            $display("PASS: 排序结果为 [2, 3, 5, 7, 8]。");
        end

        if (total_insts != 0) begin
            cpi = total_cycles * 1.0 / total_insts;
            ipc = total_insts * 1.0 / total_cycles;
        end else begin
            cpi = 0.0;
            ipc = 0.0;
        end

        $display("总周期 C             : %0d", total_cycles);
        $display("有效退休指令 IC      : %0d", total_insts);
        $display("load-use 停顿        : %0d", load_use_stalls);
        $display("实际重定向次数       : %0d", redirects);
        $display("CPI / IPC            : %f / %f", cpi, ipc);
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            #1;
            if (debug_wb_valid && debug_wb_reg_write && debug_wb_rd != 5'd0)
                $display("[WB] PC=%h  x%0d <= %h", debug_wb_pc,
                         debug_wb_rd, debug_wb_data);
            if (u_cpu.ex_mem_mem_write)
                $display("[MEM] addr=%h <= %h", u_cpu.ex_mem_alu_result,
                         u_cpu.ex_mem_store_data);
        end
    end
endmodule
