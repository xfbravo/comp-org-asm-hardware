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
    output reg  [31:0] read_data,
    output wire [31:0] debug_word0
);
    localparam WORD_COUNT = MEM_BYTES / 4;
    localparam WORD_ADDR_BITS = ADDR_BITS - 2;

    // Separate byte lanes match Vivado's asynchronous distributed-RAM
    // inference template while retaining byte and half-word write enables.
    (* ram_style = "distributed" *) reg [7:0] lane0 [0:WORD_COUNT-1];
    (* ram_style = "distributed" *) reg [7:0] lane1 [0:WORD_COUNT-1];
    (* ram_style = "distributed" *) reg [7:0] lane2 [0:WORD_COUNT-1];
    (* ram_style = "distributed" *) reg [7:0] lane3 [0:WORD_COUNT-1];
    integer i;
    initial begin
        for (i = 0; i < WORD_COUNT; i = i + 1) begin
            lane0[i] = 8'd0;
            lane1[i] = 8'd0;
            lane2[i] = 8'd0;
            lane3[i] = 8'd0;
        end
    end

    wire [WORD_ADDR_BITS-1:0] word_addr = addr[ADDR_BITS-1:2];
    wire [31:0] raw_word = {lane3[word_addr], lane2[word_addr],
                            lane1[word_addr], lane0[word_addr]};
    reg [7:0] selected_byte;
    reg [15:0] selected_half;
    reg [31:0] debug_word0_reg;
    assign debug_word0 = debug_word0_reg;

    always @(*) begin
        case (addr[1:0])
            2'd0: selected_byte = raw_word[7:0];
            2'd1: selected_byte = raw_word[15:8];
            2'd2: selected_byte = raw_word[23:16];
            default: selected_byte = raw_word[31:24];
        endcase
        selected_half = addr[1] ? raw_word[31:16] : raw_word[15:0];

        if (mem_read) begin
            case (mem_size)
                `MEM_BYTE: read_data = load_unsigned ? {24'd0, selected_byte}
                                                     : {{24{selected_byte[7]}}, selected_byte};
                `MEM_HALF: read_data = load_unsigned ? {16'd0, selected_half}
                                                     : {{16{selected_half[15]}}, selected_half};
                default:   read_data = raw_word;
            endcase
        end else begin
            read_data = 32'd0;
        end
    end

    always @(posedge clk) begin
        if (rst_n && mem_write) begin
            case (mem_size)
                `MEM_BYTE:
                    case (addr[1:0])
                        2'd0: lane0[word_addr] <= write_data[7:0];
                        2'd1: lane1[word_addr] <= write_data[7:0];
                        2'd2: lane2[word_addr] <= write_data[7:0];
                        2'd3: lane3[word_addr] <= write_data[7:0];
                    endcase
                `MEM_HALF: begin
                    if (addr[1]) begin
                        lane2[word_addr] <= write_data[7:0];
                        lane3[word_addr] <= write_data[15:8];
                    end else begin
                        lane0[word_addr] <= write_data[7:0];
                        lane1[word_addr] <= write_data[15:8];
                    end
                end
                default: begin
                    lane0[word_addr] <= write_data[7:0];
                    lane1[word_addr] <= write_data[15:8];
                    lane2[word_addr] <= write_data[23:16];
                    lane3[word_addr] <= write_data[31:24];
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debug_word0_reg <= 32'd0;
        end else if (mem_write && word_addr == {WORD_ADDR_BITS{1'b0}}) begin
            case (mem_size)
                `MEM_BYTE:
                    case (addr[1:0])
                        2'd0: debug_word0_reg[7:0]   <= write_data[7:0];
                        2'd1: debug_word0_reg[15:8]  <= write_data[7:0];
                        2'd2: debug_word0_reg[23:16] <= write_data[7:0];
                        2'd3: debug_word0_reg[31:24] <= write_data[7:0];
                    endcase
                `MEM_HALF: begin
                    if (addr[1]) debug_word0_reg[31:16] <= write_data[15:0];
                    else         debug_word0_reg[15:0]  <= write_data[15:0];
                end
                default: debug_word0_reg <= write_data;
            endcase
        end
    end
endmodule
