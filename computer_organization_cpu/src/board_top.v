`timescale 1ns / 1ps

module board_top #(
    parameter PROGRAM_FILE = "program.mem",
    parameter REFRESH_BITS = 15
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] switches,
    output wire [15:0] leds,
    output wire [7:0]  seg_an,
    output wire [7:0]  seg,
    output wire        halted
);
    wire [31:0] pc_current;
    wire        debug_wb_valid;
    wire [31:0] debug_wb_pc;
    wire        debug_wb_reg_write;
    wire [4:0]  debug_wb_rd;
    wire [31:0] debug_wb_data;

    reg [31:0] display_value;

    cpu_core #(
        .PROGRAM_FILE(PROGRAM_FILE)
    ) u_cpu_core (
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

    always @(*) begin
        case (switches[2:0])
            3'd0: display_value = pc_current;
            3'd1: display_value = debug_wb_pc;
            3'd2: display_value = {26'd0, debug_wb_reg_write, debug_wb_rd};
            3'd3: display_value = debug_wb_data;
            3'd4: display_value = {31'd0, halted};
            default: display_value = 32'hdead_beef;
        endcase
    end

    assign leds = {halted, debug_wb_valid, debug_wb_reg_write, debug_wb_rd, pc_current[7:0]};

    seven_seg_hex #(
        .REFRESH_BITS(REFRESH_BITS)
    ) u_seven_seg_hex (
        .clk(clk),
        .rst_n(rst_n),
        .value(display_value),
        .an(seg_an),
        .seg(seg)
    );
endmodule
