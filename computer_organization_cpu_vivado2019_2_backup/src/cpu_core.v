`timescale 1ns / 1ps
`include "cpu_defs.vh"

module cpu_core #(
    parameter PROGRAM_FILE = "program.mem",
    parameter IMEM_WORDS = 1024,
    parameter IMEM_ADDR_BITS = 10,
    parameter DMEM_BYTES = 4096,
    parameter DMEM_ADDR_BITS = 12
)(
    input  wire        clk,
    input  wire        rst_n,
    output wire        halted,
    output wire [31:0] pc_current,
    output wire        debug_wb_valid,
    output wire [31:0] debug_wb_pc,
    output wire        debug_wb_reg_write,
    output wire [4:0]  debug_wb_rd,
    output wire [31:0] debug_wb_data
);
    reg [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] if_instr;
    wire        stall;
    wire        redirect_ex;
    wire [31:0] redirect_pc_ex;

    assign pc_current = pc;
    assign pc_next = redirect_ex ? redirect_pc_ex : (pc + 32'd4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'd0;
        end else if (redirect_ex) begin
            pc <= redirect_pc_ex;
        end else if (!stall) begin
            pc <= pc + 32'd4;
        end
    end

    instr_mem #(
        .MEM_WORDS(IMEM_WORDS),
        .ADDR_BITS(IMEM_ADDR_BITS),
        .PROGRAM_FILE(PROGRAM_FILE)
    ) u_imem (
        .pc(pc),
        .instr(if_instr)
    );

    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;
    wire        if_id_valid;

    if_id_reg u_if_id (
        .clk(clk),
        .rst_n(rst_n),
        .enable(!stall),
        .flush(redirect_ex),
        .pc_i(pc),
        .instr_i(if_instr),
        .valid_i(1'b1),
        .pc_o(if_id_pc),
        .instr_o(if_id_instr),
        .valid_o(if_id_valid)
    );

    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [4:0] id_rd  = if_id_instr[11:7];

    wire        id_reg_write;
    wire        id_mem_read;
    wire        id_mem_write;
    wire [1:0]  id_a_sel;
    wire        id_b_sel;
    wire [1:0]  id_wb_sel;
    wire [3:0]  id_alu_op;
    wire        id_branch;
    wire        id_jump;
    wire        id_jalr;
    wire [2:0]  id_imm_type;
    wire [1:0]  id_mem_size;
    wire        id_load_unsigned;
    wire        id_uses_rs1;
    wire        id_uses_rs2;
    wire        id_illegal_instr;
    wire [31:0] id_imm;
    wire [31:0] id_rs1_value;
    wire [31:0] id_rs2_value;

    controller u_controller (
        .instr(if_id_instr),
        .reg_write(id_reg_write),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .a_sel(id_a_sel),
        .b_sel(id_b_sel),
        .wb_sel(id_wb_sel),
        .alu_op(id_alu_op),
        .branch(id_branch),
        .jump(id_jump),
        .jalr(id_jalr),
        .imm_type(id_imm_type),
        .mem_size(id_mem_size),
        .load_unsigned(id_load_unsigned),
        .uses_rs1(id_uses_rs1),
        .uses_rs2(id_uses_rs2),
        .illegal_instr(id_illegal_instr)
    );

    imm_gen u_imm_gen (
        .instr(if_id_instr),
        .imm_type(id_imm_type),
        .imm(id_imm)
    );

    wire [31:0] wb_data;
    wire        wb_commit_reg_write;
    wire [4:0]  mem_wb_rd;

    reg_file u_reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .we(wb_commit_reg_write),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(mem_wb_rd),
        .wd(wb_data),
        .rd1(id_rs1_value),
        .rd2(id_rs2_value)
    );

    wire        id_ex_valid;
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc4;
    wire [31:0] id_ex_instr;
    wire [31:0] id_ex_rs1_value;
    wire [31:0] id_ex_rs2_value;
    wire [31:0] id_ex_imm;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire [4:0]  id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire        id_ex_reg_write;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire [1:0]  id_ex_a_sel;
    wire        id_ex_b_sel;
    wire [1:0]  id_ex_wb_sel;
    wire [3:0]  id_ex_alu_op;
    wire        id_ex_branch;
    wire        id_ex_jump;
    wire        id_ex_jalr;
    wire [1:0]  id_ex_mem_size;
    wire        id_ex_load_unsigned;

    hazard_unit u_hazard_unit (
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_rd(id_ex_rd),
        .if_id_rs1(id_rs1),
        .if_id_rs2(id_rs2),
        .if_id_uses_rs1(id_uses_rs1),
        .if_id_uses_rs2(id_uses_rs2),
        .stall(stall)
    );

    id_ex_reg u_id_ex (
        .clk(clk),
        .rst_n(rst_n),
        .flush(stall || redirect_ex || id_illegal_instr),
        .valid_i(if_id_valid),
        .pc_i(if_id_pc),
        .pc4_i(if_id_pc + 32'd4),
        .instr_i(if_id_instr),
        .rs1_value_i(id_rs1_value),
        .rs2_value_i(id_rs2_value),
        .imm_i(id_imm),
        .rs1_i(id_rs1),
        .rs2_i(id_rs2),
        .rd_i(id_rd),
        .funct3_i(if_id_instr[14:12]),
        .reg_write_i(id_reg_write),
        .mem_read_i(id_mem_read),
        .mem_write_i(id_mem_write),
        .a_sel_i(id_a_sel),
        .b_sel_i(id_b_sel),
        .wb_sel_i(id_wb_sel),
        .alu_op_i(id_alu_op),
        .branch_i(id_branch),
        .jump_i(id_jump),
        .jalr_i(id_jalr),
        .mem_size_i(id_mem_size),
        .load_unsigned_i(id_load_unsigned),
        .valid_o(id_ex_valid),
        .pc_o(id_ex_pc),
        .pc4_o(id_ex_pc4),
        .instr_o(id_ex_instr),
        .rs1_value_o(id_ex_rs1_value),
        .rs2_value_o(id_ex_rs2_value),
        .imm_o(id_ex_imm),
        .rs1_o(id_ex_rs1),
        .rs2_o(id_ex_rs2),
        .rd_o(id_ex_rd),
        .funct3_o(id_ex_funct3),
        .reg_write_o(id_ex_reg_write),
        .mem_read_o(id_ex_mem_read),
        .mem_write_o(id_ex_mem_write),
        .a_sel_o(id_ex_a_sel),
        .b_sel_o(id_ex_b_sel),
        .wb_sel_o(id_ex_wb_sel),
        .alu_op_o(id_ex_alu_op),
        .branch_o(id_ex_branch),
        .jump_o(id_ex_jump),
        .jalr_o(id_ex_jalr),
        .mem_size_o(id_ex_mem_size),
        .load_unsigned_o(id_ex_load_unsigned)
    );

    wire        ex_mem_valid;
    wire [31:0] ex_mem_pc4;
    wire [31:0] ex_mem_instr;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_store_data;
    wire [4:0]  ex_mem_rd;
    wire        ex_mem_reg_write;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire [1:0]  ex_mem_wb_sel;
    wire [1:0]  ex_mem_mem_size;
    wire        ex_mem_load_unsigned;

    wire [1:0] forward_a_sel;
    wire [1:0] forward_b_sel;
    wire [31:0] ex_mem_forward_data;
    wire [31:0] ex_rs1_forwarded;
    wire [31:0] ex_rs2_forwarded;

    assign ex_mem_forward_data = (ex_mem_wb_sel == `WB_PC4) ? ex_mem_pc4 : ex_mem_alu_result;

    forwarding_unit u_forwarding_unit (
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(wb_commit_reg_write),
        .forward_a(forward_a_sel),
        .forward_b(forward_b_sel)
    );

    assign ex_rs1_forwarded = (forward_a_sel == 2'b10) ? ex_mem_forward_data :
                              (forward_a_sel == 2'b01) ? wb_data :
                              id_ex_rs1_value;
    assign ex_rs2_forwarded = (forward_b_sel == 2'b10) ? ex_mem_forward_data :
                              (forward_b_sel == 2'b01) ? wb_data :
                              id_ex_rs2_value;

    wire [31:0] alu_a = (id_ex_a_sel == `ASEL_PC)   ? id_ex_pc :
                        (id_ex_a_sel == `ASEL_ZERO) ? 32'd0 :
                        ex_rs1_forwarded;
    wire [31:0] alu_b = (id_ex_b_sel == `BSEL_IMM) ? id_ex_imm : ex_rs2_forwarded;
    wire [31:0] alu_result;

    alu u_alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(id_ex_alu_op),
        .y(alu_result)
    );

    branch_unit u_branch_unit (
        .branch(id_ex_branch && id_ex_valid),
        .jump(id_ex_jump && id_ex_valid),
        .jalr(id_ex_jalr),
        .funct3(id_ex_funct3),
        .pc(id_ex_pc),
        .imm(id_ex_imm),
        .rs1_value(ex_rs1_forwarded),
        .rs2_value(ex_rs2_forwarded),
        .redirect(redirect_ex),
        .target_pc(redirect_pc_ex)
    );

    ex_mem_reg u_ex_mem (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(id_ex_valid),
        .pc4_i(id_ex_pc4),
        .instr_i(id_ex_instr),
        .alu_result_i(alu_result),
        .store_data_i(ex_rs2_forwarded),
        .rd_i(id_ex_rd),
        .reg_write_i(id_ex_reg_write && id_ex_valid),
        .mem_read_i(id_ex_mem_read && id_ex_valid),
        .mem_write_i(id_ex_mem_write && id_ex_valid),
        .wb_sel_i(id_ex_wb_sel),
        .mem_size_i(id_ex_mem_size),
        .load_unsigned_i(id_ex_load_unsigned),
        .valid_o(ex_mem_valid),
        .pc4_o(ex_mem_pc4),
        .instr_o(ex_mem_instr),
        .alu_result_o(ex_mem_alu_result),
        .store_data_o(ex_mem_store_data),
        .rd_o(ex_mem_rd),
        .reg_write_o(ex_mem_reg_write),
        .mem_read_o(ex_mem_mem_read),
        .mem_write_o(ex_mem_mem_write),
        .wb_sel_o(ex_mem_wb_sel),
        .mem_size_o(ex_mem_mem_size),
        .load_unsigned_o(ex_mem_load_unsigned)
    );

    wire [31:0] mem_read_data;

    data_mem #(
        .MEM_BYTES(DMEM_BYTES),
        .ADDR_BITS(DMEM_ADDR_BITS)
    ) u_data_mem (
        .clk(clk),
        .rst_n(rst_n),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .mem_size(ex_mem_mem_size),
        .load_unsigned(ex_mem_load_unsigned),
        .addr(ex_mem_alu_result),
        .write_data(ex_mem_store_data),
        .read_data(mem_read_data)
    );

    wire        mem_wb_valid;
    wire [31:0] mem_wb_pc4;
    wire [31:0] mem_wb_instr;
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_mem_data;
    wire        mem_wb_reg_write;
    wire [1:0]  mem_wb_wb_sel;

    mem_wb_reg u_mem_wb (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(ex_mem_valid),
        .pc4_i(ex_mem_pc4),
        .instr_i(ex_mem_instr),
        .alu_result_i(ex_mem_alu_result),
        .mem_data_i(mem_read_data),
        .rd_i(ex_mem_rd),
        .reg_write_i(ex_mem_reg_write),
        .wb_sel_i(ex_mem_wb_sel),
        .valid_o(mem_wb_valid),
        .pc4_o(mem_wb_pc4),
        .instr_o(mem_wb_instr),
        .alu_result_o(mem_wb_alu_result),
        .mem_data_o(mem_wb_mem_data),
        .rd_o(mem_wb_rd),
        .reg_write_o(mem_wb_reg_write),
        .wb_sel_o(mem_wb_wb_sel)
    );

    assign wb_data = (mem_wb_wb_sel == `WB_MEM) ? mem_wb_mem_data :
                     (mem_wb_wb_sel == `WB_PC4) ? mem_wb_pc4 :
                     mem_wb_alu_result;
    assign wb_commit_reg_write = mem_wb_valid && mem_wb_reg_write;

    assign halted = mem_wb_valid && (mem_wb_instr == `ECALL_INSTR);
    assign debug_wb_valid = mem_wb_valid;
    assign debug_wb_pc = mem_wb_pc4 - 32'd4;
    assign debug_wb_reg_write = wb_commit_reg_write;
    assign debug_wb_rd = mem_wb_rd;
    assign debug_wb_data = wb_data;

endmodule
