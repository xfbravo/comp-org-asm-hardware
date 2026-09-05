`timescale 1ns / 1ps
module key_debounce #(parameter integer COUNT_MAX=500000) (
    input wire clk, input wire rst_n, input wire key_in, output reg key_pulse
);
    reg sync0, sync1, stable;
    integer count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sync0<=0; sync1<=0; stable<=0; count<=0; key_pulse<=0; end
        else begin
            sync0 <= key_in; sync1 <= sync0; key_pulse <= 0;
            if (sync1 == stable) count <= 0;
            else if (count == COUNT_MAX-1) begin stable <= sync1; count <= 0; if (sync1) key_pulse <= 1; end
            else count <= count + 1;
        end
    end
endmodule
