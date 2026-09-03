`timescale 1ns / 1ps
`include "cpu_defs.vh"

module controller(
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  a_sel,
    output reg         b_sel,
    output reg  [1:0]  wb_sel,
    output reg  [3:0]  alu_op,
    output reg         branch,
    output reg         jump,
    output reg         jalr,
    output reg  [2:0]  imm_type,
    output reg  [1:0]  mem_size,
    output reg         load_unsigned,
    output reg         uses_rs1,
    output reg         uses_rs2,
    output reg         illegal_instr
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire       funct7_base = (funct7 == 7'b0000000);
    wire       funct7_sub  = (funct7 == 7'b0100000);

    always @(*) begin
        reg_write     = 1'b0;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        a_sel         = `ASEL_RS1;
        b_sel         = `BSEL_RS2;
        wb_sel        = `WB_ALU;
        alu_op        = `ALU_ADD;
        branch        = 1'b0;
        jump          = 1'b0;
        jalr          = 1'b0;
        imm_type      = `IMM_I;
        mem_size      = `MEM_WORD;
        load_unsigned = 1'b0;
        uses_rs1      = 1'b0;
        uses_rs2      = 1'b0;
        illegal_instr = 1'b0;

        case (opcode)
            `OPCODE_OP: begin
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7_base) alu_op = `ALU_ADD;
                        else if (funct7_sub) alu_op = `ALU_SUB;
                        else illegal_instr = 1'b1;
                    end
                    3'b001: begin
                        alu_op = `ALU_SLL;
                        illegal_instr = !funct7_base;
                    end
                    3'b010: begin
                        alu_op = `ALU_SLT;
                        illegal_instr = !funct7_base;
                    end
                    3'b011: begin
                        alu_op = `ALU_SLTU;
                        illegal_instr = !funct7_base;
                    end
                    3'b100: begin
                        alu_op = `ALU_XOR;
                        illegal_instr = !funct7_base;
                    end
                    3'b101: begin
                        if (funct7_base) alu_op = `ALU_SRL;
                        else if (funct7_sub) alu_op = `ALU_SRA;
                        else illegal_instr = 1'b1;
                    end
                    3'b110: begin
                        alu_op = `ALU_OR;
                        illegal_instr = !funct7_base;
                    end
                    3'b111: begin
                        alu_op = `ALU_AND;
                        illegal_instr = !funct7_base;
                    end
                endcase
            end

            `OPCODE_OP_IMM: begin
                reg_write = 1'b1;
                uses_rs1  = 1'b1;
                b_sel     = `BSEL_IMM;
                imm_type  = `IMM_I;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    3'b001: begin
                        alu_op = `ALU_SLL;
                        illegal_instr = !funct7_base;
                    end
                    3'b101: begin
                        if (funct7_base) alu_op = `ALU_SRL;
                        else if (funct7_sub) alu_op = `ALU_SRA;
                        else illegal_instr = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            `OPCODE_LOAD: begin
                reg_write     = 1'b1;
                mem_read      = 1'b1;
                uses_rs1      = 1'b1;
                b_sel         = `BSEL_IMM;
                wb_sel        = `WB_MEM;
                imm_type      = `IMM_I;
                load_unsigned = funct3[2];
                case (funct3[1:0])
                    2'b00: mem_size = `MEM_BYTE;
                    2'b01: mem_size = `MEM_HALF;
                    2'b10: mem_size = `MEM_WORD;
                    default: illegal_instr = 1'b1;
                endcase
            end

            `OPCODE_STORE: begin
                mem_write = 1'b1;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
                b_sel     = `BSEL_IMM;
                imm_type  = `IMM_S;
                case (funct3)
                    3'b000: mem_size = `MEM_BYTE;
                    3'b001: mem_size = `MEM_HALF;
                    3'b010: mem_size = `MEM_WORD;
                    default: illegal_instr = 1'b1;
                endcase
            end

            `OPCODE_BRANCH: begin
                branch   = 1'b1;
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                imm_type = `IMM_B;
                alu_op   = `ALU_SUB;
                if (funct3 == 3'b010 || funct3 == 3'b011) begin
                    illegal_instr = 1'b1;
                end
            end

            `OPCODE_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                wb_sel    = `WB_PC4;
                imm_type  = `IMM_J;
            end

            `OPCODE_JALR: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                uses_rs1  = 1'b1;
                wb_sel    = `WB_PC4;
                imm_type  = `IMM_I;
                illegal_instr = (funct3 != 3'b000);
            end

            `OPCODE_LUI: begin
                reg_write = 1'b1;
                a_sel     = `ASEL_ZERO;
                b_sel     = `BSEL_IMM;
                imm_type  = `IMM_U;
                alu_op    = `ALU_ADD;
            end

            `OPCODE_AUIPC: begin
                reg_write = 1'b1;
                a_sel     = `ASEL_PC;
                b_sel     = `BSEL_IMM;
                imm_type  = `IMM_U;
                alu_op    = `ALU_ADD;
            end

            `OPCODE_SYSTEM: begin
                illegal_instr = (instr != `ECALL_INSTR);
            end

            default: begin
                if (instr != `NOP_INSTR) begin
                    illegal_instr = 1'b1;
                end
            end
        endcase
    end
endmodule
