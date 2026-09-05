`timescale 1ns / 1ps
`include "cpu_defs.vh"

module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] y,
    output wire        zero
);
    always @(*) begin
        case (alu_op)
            `ALU_ADD:    y = a + b;
            `ALU_SUB:    y = a - b;
            `ALU_AND:    y = a & b;
            `ALU_OR:     y = a | b;
            `ALU_XOR:    y = a ^ b;
            `ALU_SLL:    y = a << b[4:0];
            `ALU_SRL:    y = a >> b[4:0];
            `ALU_SRA:    y = $signed(a) >>> b[4:0];
            `ALU_SLT:    y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU:   y = (a < b) ? 32'd1 : 32'd0;
            `ALU_COPY_B: y = b;
            default:     y = 32'd0;
        endcase
    end

    assign zero = (y == 32'd0);
endmodule
