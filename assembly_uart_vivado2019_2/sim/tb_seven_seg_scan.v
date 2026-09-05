`timescale 1ns / 1ps

module tb_seven_seg_scan;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [31:0] value = 32'h0000_2026;
    wire [7:0] anode;
    wire [7:0] segment;
    reg [7:0] seen;
    integer failures;
    integer sample;

    seven_seg_scan #(.SCAN_TICKS(2)) dut (
        .clk(clk), .rst_n(rst_n), .value(value),
        .anode(anode), .segment(segment)
    );

    always #5 clk = ~clk;

    function [7:0] expected_segment;
        input [3:0] digit_value;
        begin
            case (digit_value)
                4'h0: expected_segment = 8'h3f;
                4'h2: expected_segment = 8'h5b;
                4'h5: expected_segment = 8'h6d;
                4'h6: expected_segment = 8'h7d;
                default: expected_segment = 8'h00;
            endcase
        end
    endfunction

    function [3:0] selected_nibble;
        input [7:0] select_value;
        begin
            case (select_value)
                8'h01: selected_nibble = value[3:0];
                8'h02: selected_nibble = value[7:4];
                8'h04: selected_nibble = value[11:8];
                8'h08: selected_nibble = value[15:12];
                8'h10: selected_nibble = value[19:16];
                8'h20: selected_nibble = value[23:20];
                8'h40: selected_nibble = value[27:24];
                8'h80: selected_nibble = value[31:28];
                default: selected_nibble = 4'hf;
            endcase
        end
    endfunction

    initial begin
        failures = 0;
        seen = 8'h00;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        for (sample = 0; sample < 24; sample = sample + 1) begin
            @(negedge clk);
            if (anode == 8'h00 || (anode & (anode - 1'b1)) != 8'h00) begin
                $display("SEG_SELECT_NOT_ONE_HOT anode=%02x", anode);
                failures = failures + 1;
            end
            if (segment !== expected_segment(selected_nibble(anode))) begin
                $display("SEG_CODE_FAIL anode=%02x segment=%02x", anode, segment);
                failures = failures + 1;
            end
            seen = seen | anode;
        end

        if (seen !== 8'hff) begin
            $display("SEG_SCAN_INCOMPLETE seen=%02x", seen);
            failures = failures + 1;
        end

        if (failures == 0)
            $display("SEVEN_SEG_2026_TEST_PASSED");
        else
            $display("SEVEN_SEG_2026_TEST_FAILED count=%0d", failures);
        // Vivado launches behavioral simulations with an initial 1000 ns run.
        // Finish later so the batch script can safely continue with "run all".
        #2000;
        $finish;
    end
endmodule
