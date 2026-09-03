`timescale 1ns / 1ps

module seven_seg_hex #(
    parameter REFRESH_BITS = 15
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] value,
    output reg  [7:0]  an,
    output reg  [7:0]  seg
);
    reg [REFRESH_BITS+2:0] refresh_counter;
    wire [2:0] digit_index = refresh_counter[REFRESH_BITS+2:REFRESH_BITS];
    reg [3:0] nibble;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= {REFRESH_BITS+3{1'b0}};
        end else begin
            refresh_counter <= refresh_counter + {{REFRESH_BITS+2{1'b0}}, 1'b1};
        end
    end

    always @(*) begin
        case (digit_index)
            3'd0: nibble = value[3:0];
            3'd1: nibble = value[7:4];
            3'd2: nibble = value[11:8];
            3'd3: nibble = value[15:12];
            3'd4: nibble = value[19:16];
            3'd5: nibble = value[23:20];
            3'd6: nibble = value[27:24];
            default: nibble = value[31:28];
        endcase

        an = ~(8'b0000_0001 << digit_index);

        case (nibble)
            4'h0: seg = 8'b1100_0000;
            4'h1: seg = 8'b1111_1001;
            4'h2: seg = 8'b1010_0100;
            4'h3: seg = 8'b1011_0000;
            4'h4: seg = 8'b1001_1001;
            4'h5: seg = 8'b1001_0010;
            4'h6: seg = 8'b1000_0010;
            4'h7: seg = 8'b1111_1000;
            4'h8: seg = 8'b1000_0000;
            4'h9: seg = 8'b1001_0000;
            4'ha: seg = 8'b1000_1000;
            4'hb: seg = 8'b1000_0011;
            4'hc: seg = 8'b1100_0110;
            4'hd: seg = 8'b1010_0001;
            4'he: seg = 8'b1000_0110;
            default: seg = 8'b1000_1110;
        endcase
    end
endmodule
