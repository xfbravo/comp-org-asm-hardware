`timescale 1ns / 1ps
`include "cpu_defs.vh"

module if_id_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        flush,
    input  wire [31:0] pc_i,
    input  wire [31:0] instr_i,
    input  wire        valid_i,
    output reg  [31:0] pc_o,
    output reg  [31:0] instr_o,
    output reg         valid_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            pc_o    <= 32'd0;
            instr_o <= `NOP_INSTR;
            valid_o <= 1'b0;
        end else if (enable) begin
            pc_o    <= pc_i;
            instr_o <= instr_i;
            valid_o <= valid_i;
        end
    end
endmodule

module id_ex_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,
    input  wire        valid_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] pc4_i,
    input  wire [31:0] instr_i,
    input  wire [31:0] rs1_value_i,
    input  wire [31:0] rs2_value_i,
    input  wire [31:0] imm_i,
    input  wire [4:0]  rs1_i,
    input  wire [4:0]  rs2_i,
    input  wire [4:0]  rd_i,
    input  wire [2:0]  funct3_i,
    input  wire        reg_write_i,
    input  wire        mem_read_i,
    input  wire        mem_write_i,
    input  wire [1:0]  a_sel_i,
    input  wire        b_sel_i,
    input  wire [1:0]  wb_sel_i,
    input  wire [3:0]  alu_op_i,
    input  wire        branch_i,
    input  wire        jump_i,
    input  wire        jalr_i,
    input  wire [1:0]  mem_size_i,
    input  wire        load_unsigned_i,
    output reg         valid_o,
    output reg  [31:0] pc_o,
    output reg  [31:0] pc4_o,
    output reg  [31:0] instr_o,
    output reg  [31:0] rs1_value_o,
    output reg  [31:0] rs2_value_o,
    output reg  [31:0] imm_o,
    output reg  [4:0]  rs1_o,
    output reg  [4:0]  rs2_o,
    output reg  [4:0]  rd_o,
    output reg  [2:0]  funct3_o,
    output reg         reg_write_o,
    output reg         mem_read_o,
    output reg         mem_write_o,
    output reg  [1:0]  a_sel_o,
    output reg         b_sel_o,
    output reg  [1:0]  wb_sel_o,
    output reg  [3:0]  alu_op_o,
    output reg         branch_o,
    output reg         jump_o,
    output reg         jalr_o,
    output reg  [1:0]  mem_size_o,
    output reg         load_unsigned_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            valid_o         <= 1'b0;
            pc_o            <= 32'd0;
            pc4_o           <= 32'd0;
            instr_o         <= `NOP_INSTR;
            rs1_value_o     <= 32'd0;
            rs2_value_o     <= 32'd0;
            imm_o           <= 32'd0;
            rs1_o           <= 5'd0;
            rs2_o           <= 5'd0;
            rd_o            <= 5'd0;
            funct3_o        <= 3'd0;
            reg_write_o     <= 1'b0;
            mem_read_o      <= 1'b0;
            mem_write_o     <= 1'b0;
            a_sel_o         <= `ASEL_RS1;
            b_sel_o         <= `BSEL_RS2;
            wb_sel_o        <= `WB_ALU;
            alu_op_o        <= `ALU_ADD;
            branch_o        <= 1'b0;
            jump_o          <= 1'b0;
            jalr_o          <= 1'b0;
            mem_size_o      <= `MEM_WORD;
            load_unsigned_o <= 1'b0;
        end else begin
            valid_o         <= valid_i;
            pc_o            <= pc_i;
            pc4_o           <= pc4_i;
            instr_o         <= instr_i;
            rs1_value_o     <= rs1_value_i;
            rs2_value_o     <= rs2_value_i;
            imm_o           <= imm_i;
            rs1_o           <= rs1_i;
            rs2_o           <= rs2_i;
            rd_o            <= rd_i;
            funct3_o        <= funct3_i;
            reg_write_o     <= reg_write_i;
            mem_read_o      <= mem_read_i;
            mem_write_o     <= mem_write_i;
            a_sel_o         <= a_sel_i;
            b_sel_o         <= b_sel_i;
            wb_sel_o        <= wb_sel_i;
            alu_op_o        <= alu_op_i;
            branch_o        <= branch_i;
            jump_o          <= jump_i;
            jalr_o          <= jalr_i;
            mem_size_o      <= mem_size_i;
            load_unsigned_o <= load_unsigned_i;
        end
    end
endmodule

module ex_mem_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_i,
    input  wire [31:0] pc4_i,
    input  wire [31:0] instr_i,
    input  wire [31:0] alu_result_i,
    input  wire [31:0] store_data_i,
    input  wire [4:0]  rd_i,
    input  wire        reg_write_i,
    input  wire        mem_read_i,
    input  wire        mem_write_i,
    input  wire [1:0]  wb_sel_i,
    input  wire [1:0]  mem_size_i,
    input  wire        load_unsigned_i,
    output reg         valid_o,
    output reg  [31:0] pc4_o,
    output reg  [31:0] instr_o,
    output reg  [31:0] alu_result_o,
    output reg  [31:0] store_data_o,
    output reg  [4:0]  rd_o,
    output reg         reg_write_o,
    output reg         mem_read_o,
    output reg         mem_write_o,
    output reg  [1:0]  wb_sel_o,
    output reg  [1:0]  mem_size_o,
    output reg         load_unsigned_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_o         <= 1'b0;
            pc4_o           <= 32'd0;
            instr_o         <= `NOP_INSTR;
            alu_result_o    <= 32'd0;
            store_data_o    <= 32'd0;
            rd_o            <= 5'd0;
            reg_write_o     <= 1'b0;
            mem_read_o      <= 1'b0;
            mem_write_o     <= 1'b0;
            wb_sel_o        <= `WB_ALU;
            mem_size_o      <= `MEM_WORD;
            load_unsigned_o <= 1'b0;
        end else begin
            valid_o         <= valid_i;
            pc4_o           <= pc4_i;
            instr_o         <= instr_i;
            alu_result_o    <= alu_result_i;
            store_data_o    <= store_data_i;
            rd_o            <= rd_i;
            reg_write_o     <= reg_write_i;
            mem_read_o      <= mem_read_i;
            mem_write_o     <= mem_write_i;
            wb_sel_o        <= wb_sel_i;
            mem_size_o      <= mem_size_i;
            load_unsigned_o <= load_unsigned_i;
        end
    end
endmodule

module mem_wb_reg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_i,
    input  wire [31:0] pc4_i,
    input  wire [31:0] instr_i,
    input  wire [31:0] alu_result_i,
    input  wire [31:0] mem_data_i,
    input  wire [4:0]  rd_i,
    input  wire        reg_write_i,
    input  wire [1:0]  wb_sel_i,
    output reg         valid_o,
    output reg  [31:0] pc4_o,
    output reg  [31:0] instr_o,
    output reg  [31:0] alu_result_o,
    output reg  [31:0] mem_data_o,
    output reg  [4:0]  rd_o,
    output reg         reg_write_o,
    output reg  [1:0]  wb_sel_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_o      <= 1'b0;
            pc4_o        <= 32'd0;
            instr_o      <= `NOP_INSTR;
            alu_result_o <= 32'd0;
            mem_data_o   <= 32'd0;
            rd_o         <= 5'd0;
            reg_write_o  <= 1'b0;
            wb_sel_o     <= `WB_ALU;
        end else begin
            valid_o      <= valid_i;
            pc4_o        <= pc4_i;
            instr_o      <= instr_i;
            alu_result_o <= alu_result_i;
            mem_data_o   <= mem_data_i;
            rd_o         <= rd_i;
            reg_write_o  <= reg_write_i;
            wb_sel_o     <= wb_sel_i;
        end
    end
endmodule
