`timescale 1ns/1ps
// Assert asynchronously; release only after two clean edges in the target domain.
module reset_sync(input wire clk, input wire async_rst_n, output wire rst_n);
    (* ASYNC_REG="TRUE" *) reg [1:0] stages;
    always @(posedge clk or negedge async_rst_n)
        if (!async_rst_n) stages <= 2'b00;
        else stages <= {stages[0],1'b1};
    assign rst_n=stages[1];
endmodule
