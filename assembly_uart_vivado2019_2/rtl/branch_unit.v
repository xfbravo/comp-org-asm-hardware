`timescale 1ns / 1ps
`include "cpu_defs.vh"

module branch_unit(
    input  wire        branch,
    input  wire        jump,
    input  wire        jalr,
    input  wire [2:0]  funct3,
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    input  wire [31:0] rs1_value,
    input  wire [31:0] rs2_value,
    output reg         redirect,
    output reg  [31:0] target_pc
);
    reg branch_taken;

    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rs1_value == rs2_value);
            3'b001: branch_taken = (rs1_value != rs2_value);
            3'b100: branch_taken = ($signed(rs1_value) < $signed(rs2_value));
            3'b101: branch_taken = ($signed(rs1_value) >= $signed(rs2_value));
            3'b110: branch_taken = (rs1_value < rs2_value);
            3'b111: branch_taken = (rs1_value >= rs2_value);
            default: branch_taken = 1'b0;
        endcase

        if (jalr) begin
            redirect = 1'b1;
            target_pc = (rs1_value + imm) & 32'hffff_fffe;
        end else if (jump) begin
            redirect = 1'b1;
            target_pc = pc + imm;
        end else if (branch && branch_taken) begin
            redirect = 1'b1;
            target_pc = pc + imm;
        end else begin
            redirect = 1'b0;
            target_pc = pc + 32'd4;
        end
    end
endmodule
