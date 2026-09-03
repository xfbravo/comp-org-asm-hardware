`timescale 1ns / 1ps
`include "cpu_defs.vh"

module data_mem #(
    parameter MEM_BYTES = 4096,
    parameter ADDR_BITS = 12
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [1:0]  mem_size,
    input  wire        load_unsigned,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data
);
    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;

    wire [ADDR_BITS-1:0] byte_addr = addr[ADDR_BITS-1:0];
    wire [31:0] load_word = {mem[byte_addr + {{(ADDR_BITS-2){1'b0}}, 2'd3}],
                             mem[byte_addr + {{(ADDR_BITS-2){1'b0}}, 2'd2}],
                             mem[byte_addr + {{(ADDR_BITS-1){1'b0}}, 1'b1}],
                             mem[byte_addr]};

    always @(*) begin
        if (mem_read) begin
            case (mem_size)
                `MEM_BYTE: read_data = load_unsigned ? {24'd0, load_word[7:0]}
                                                     : {{24{load_word[7]}}, load_word[7:0]};
                `MEM_HALF: read_data = load_unsigned ? {16'd0, load_word[15:0]}
                                                     : {{16{load_word[15]}}, load_word[15:0]};
                default:   read_data = load_word;
            endcase
        end else begin
            read_data = 32'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MEM_BYTES; i = i + 1) begin
                mem[i] <= 8'd0;
            end
        end else if (mem_write) begin
            case (mem_size)
                `MEM_BYTE: begin
                    mem[byte_addr] <= write_data[7:0];
                end
                `MEM_HALF: begin
                    mem[byte_addr]      <= write_data[7:0];
                    mem[byte_addr + {{(ADDR_BITS-1){1'b0}}, 1'b1}] <= write_data[15:8];
                end
                default: begin
                    mem[byte_addr]      <= write_data[7:0];
                    mem[byte_addr + {{(ADDR_BITS-1){1'b0}}, 1'b1}] <= write_data[15:8];
                    mem[byte_addr + {{(ADDR_BITS-2){1'b0}}, 2'd2}] <= write_data[23:16];
                    mem[byte_addr + {{(ADDR_BITS-2){1'b0}}, 2'd3}] <= write_data[31:24];
                end
            endcase
        end
    end
endmodule
