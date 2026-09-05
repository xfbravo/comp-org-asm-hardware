`timescale 1ns / 1ps

// EES-338 eight-digit common-cathode display.
// segment[7:0] = {dp, g, f, e, d, c, b, a}; both buses are active high.
module seven_seg_scan #(
    parameter integer SCAN_TICKS = 12500
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] value,
    output reg  [7:0]  anode,
    output reg  [7:0]  segment
);
    reg [13:0] scan_count;
    reg [2:0] digit;
    reg [3:0] nibble;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_count <= 14'd0;
            digit <= 3'd0;
        end else if (scan_count == SCAN_TICKS - 1) begin
            scan_count <= 14'd0;
            digit <= digit + 1'b1;
        end else begin
            scan_count <= scan_count + 1'b1;
        end
    end

    always @(*) begin
        anode = 8'b0000_0001 << digit;
        case (digit)
            3'd0: nibble = value[3:0];
            3'd1: nibble = value[7:4];
            3'd2: nibble = value[11:8];
            3'd3: nibble = value[15:12];
            3'd4: nibble = value[19:16];
            3'd5: nibble = value[23:20];
            3'd6: nibble = value[27:24];
            default: nibble = value[31:28];
        endcase

        case (nibble)
            4'h0: segment = 8'h3f;
            4'h1: segment = 8'h06;
            4'h2: segment = 8'h5b;
            4'h3: segment = 8'h4f;
            4'h4: segment = 8'h66;
            4'h5: segment = 8'h6d;
            4'h6: segment = 8'h7d;
            4'h7: segment = 8'h07;
            4'h8: segment = 8'h7f;
            4'h9: segment = 8'h6f;
            4'ha: segment = 8'h77;
            4'hb: segment = 8'h7c;
            4'hc: segment = 8'h39;
            4'hd: segment = 8'h5e;
            4'he: segment = 8'h79;
            default: segment = 8'h71;
        endcase
    end
endmodule
