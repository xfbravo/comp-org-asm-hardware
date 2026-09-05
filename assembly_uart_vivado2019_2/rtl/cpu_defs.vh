`ifndef CPU_DEFS_VH
`define CPU_DEFS_VH

`define XLEN 32
`define REG_ADDR_WIDTH 5
`define NOP_INSTR 32'h00000013
`define ECALL_INSTR 32'h00000073

`define OPCODE_LOAD   7'b0000011
`define OPCODE_OP_IMM 7'b0010011
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_STORE  7'b0100011
`define OPCODE_OP     7'b0110011
`define OPCODE_LUI    7'b0110111
`define OPCODE_BRANCH 7'b1100011
`define OPCODE_JALR   7'b1100111
`define OPCODE_JAL    7'b1101111
`define OPCODE_SYSTEM 7'b1110011

`define IMM_I 3'd0
`define IMM_S 3'd1
`define IMM_B 3'd2
`define IMM_U 3'd3
`define IMM_J 3'd4

`define ALU_ADD  4'd0
`define ALU_SUB  4'd1
`define ALU_AND  4'd2
`define ALU_OR   4'd3
`define ALU_XOR  4'd4
`define ALU_SLL  4'd5
`define ALU_SRL  4'd6
`define ALU_SRA  4'd7
`define ALU_SLT  4'd8
`define ALU_SLTU 4'd9
`define ALU_COPY_B 4'd10

`define ASEL_RS1  2'd0
`define ASEL_PC   2'd1
`define ASEL_ZERO 2'd2

`define BSEL_RS2 2'd0
`define BSEL_IMM 2'd1

`define WB_ALU 2'd0
`define WB_MEM 2'd1
`define WB_PC4 2'd2

`define MEM_BYTE 2'd0
`define MEM_HALF 2'd1
`define MEM_WORD 2'd2

`endif
