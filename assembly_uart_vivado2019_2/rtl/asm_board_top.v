`timescale 1ns / 1ps
module asm_board_top (
    input wire clk, input wire rst_n, input wire uart_rxd, input wire key_next,
    output wire uart_txd, output wire [7:0] anode, output wire [7:0] segment
);
    wire cpu_clk;
    wire key_pulse;
    wire [31:0] pc, instr, x10, mem0, seg7, uart_status;
    reg [2:0] page;
    wire halted, wb_valid, wb_we; wire [4:0] wb_rd; wire [31:0] wb_data;
    clock_divider #(.DIVIDE_BY(2)) u_clk(.clk_in(clk),.rst_n(rst_n),.clk_out(cpu_clk));
    key_debounce #(.COUNT_MAX(500000)) u_key(.clk(clk),.rst_n(rst_n),.key_in(key_next),.key_pulse(key_pulse));
    always @(posedge clk or negedge rst_n) begin
        // Start on the program-controlled page so reset visibly confirms 0x2026.
        if (!rst_n) page <= 3'd4;
        else if (key_pulse) page <= (page == 3'd5) ? 0 : page + 1'b1;
    end
    asm_cpu_core #(.PROGRAM_FILE("hello_uart.mem")) u_cpu (
        .clk(cpu_clk), .rst_n(rst_n), .uart_rxd(uart_rxd), .uart_txd(uart_txd), .seg7_value(seg7),
        .halted(halted), .pc_current(pc), .debug_wb_valid(wb_valid), .debug_wb_pc(),
        .debug_wb_reg_write(wb_we), .debug_wb_rd(wb_rd), .debug_wb_data(wb_data),
        .debug_instr(instr), .debug_x10(x10), .debug_mem0(mem0), .debug_uart_status(uart_status)
    );
    reg [31:0] display_value;
    always @(*) begin
        case(page)
            3'd0: display_value=pc; 3'd1: display_value=instr;
            3'd2: display_value=x10; 3'd3: display_value=mem0;
            3'd4: display_value=seg7; default: display_value=uart_status;
        endcase
    end
    seven_seg_scan u_seg(.clk(clk),.rst_n(rst_n),.value(display_value),.anode(anode),.segment(segment));
endmodule
