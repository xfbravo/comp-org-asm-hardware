`timescale 1ns / 1ps
module clock_divider #(parameter DIVIDE_BY=2) (
    input wire clk_in, input wire rst_n, output reg clk_out
);
    integer count;
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin count <= 0; clk_out <= 1'b0; end
        else if (count == DIVIDE_BY/2-1) begin count <= 0; clk_out <= ~clk_out; end
        else count <= count + 1;
    end
endmodule
