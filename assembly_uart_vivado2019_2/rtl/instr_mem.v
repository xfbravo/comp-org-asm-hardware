`timescale 1ns / 1ps
`include "cpu_defs.vh"

module instr_mem #(
    parameter MEM_WORDS = 1024,
    parameter ADDR_BITS = 10,
    parameter PROGRAM_FILE = "program.mem"
)(
    input  wire [31:0] pc,
    output wire [31:0] instr
);
    reg [31:0] mem [0:MEM_WORDS-1];
    integer i;
    wire [ADDR_BITS-1:0] word_addr = pc[ADDR_BITS+1:2];

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            mem[i] = `NOP_INSTR;
        end
        $readmemh(PROGRAM_FILE, mem);
    end

    assign instr = mem[word_addr];
endmodule
