`timescale 1ns / 1ps
module asm_board_top #(
    parameter PROGRAM_FILE = "hello_uart.mem",
    parameter integer UART_CLOCK_HZ = 50_000_000,
    parameter integer UART_BAUD_HZ = 115200,
    parameter integer KEY_DEBOUNCE_TICKS = 500000
) (
    input wire clk, input wire rst_n, input wire uart_rxd, input wire key_next,
    output wire uart_txd, output wire [7:0] anode, output wire [7:0] segment
);
    wire cpu_clk, board_reset_n, cpu_reset_n;
    reset_sync u_board_reset(.clk(clk),.async_rst_n(rst_n),.rst_n(board_reset_n));
    reset_sync u_cpu_reset(.clk(cpu_clk),.async_rst_n(rst_n),.rst_n(cpu_reset_n));
    wire key_pulse;
    wire [31:0] pc, instr, x10, mem0, seg7, uart_status;
    reg [2:0] page;
    wire halted, wb_valid, wb_we; wire [4:0] wb_rd; wire [31:0] wb_data;
    clock_divider #(.DIVIDE_BY(2)) u_clk(.clk_in(clk),.rst_n(board_reset_n),.clk_out(cpu_clk));
    key_debounce #(.COUNT_MAX(KEY_DEBOUNCE_TICKS)) u_key(.clk(clk),.rst_n(board_reset_n),.key_in(key_next),.key_pulse(key_pulse));
    always @(posedge clk or negedge board_reset_n) begin
        // Start on the program-controlled page so reset visibly confirms 0x2026.
        if (!board_reset_n) page <= 3'd4;
        else if (key_pulse) page <= (page == 3'd7) ? 0 : page + 1'b1;
    end
    asm_cpu_core #(
        .PROGRAM_FILE(PROGRAM_FILE),
        .UART_CLOCK_HZ(UART_CLOCK_HZ),
        .UART_BAUD_HZ(UART_BAUD_HZ)
    ) u_cpu (
        .clk(cpu_clk), .rst_n(cpu_reset_n), .uart_rxd(uart_rxd), .uart_txd(uart_txd), .seg7_value(seg7),
        .halted(halted), .pc_current(pc), .debug_wb_valid(wb_valid), .debug_wb_pc(),
        .debug_wb_reg_write(wb_we), .debug_wb_rd(wb_rd), .debug_wb_data(wb_data),
        .debug_instr(instr), .debug_x10(x10), .debug_mem0(mem0), .debug_uart_status(uart_status)
    );
    reg [31:0] display_value;
    always @(*) begin
        case(page)
            3'd0: display_value=pc; 3'd1: display_value=instr;
            3'd2: display_value=x10; 3'd3: display_value=mem0;
            3'd4: display_value=seg7;
            3'd5: display_value=uart_status;
            3'd6: display_value={28'd0,uart_status[8:5]};
            default: display_value=seg7; // Last successful command result.
        endcase
    end
    seven_seg_scan u_seg(.clk(clk),.rst_n(board_reset_n),.value(display_value),.anode(anode),.segment(segment));
endmodule
