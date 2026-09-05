`timescale 1ns / 1ps
module tb_uart_controller;
    reg clk=0, rst_n=0, rx=1, tx_start=0; reg [7:0] tx_data=0; reg rx_ack=0;
    wire tx, tx_busy; wire [7:0] rx_data; wire rx_ready;
    uart_controller #(.CLOCK_HZ(1600),.BAUD_HZ(100)) dut(
      .clk(clk),.rst_n(rst_n),.tx_data(tx_data),.tx_start(tx_start),.tx_busy(tx_busy),.tx(tx),
      .rx(rx),.rx_data(rx_data),.rx_ready(rx_ready),.rx_ack(rx_ack));
    always #5 clk=~clk;
    integer i;
    initial begin
      repeat(2) @(posedge clk); rst_n=1; tx_data=8'h41; tx_start=1; @(posedge clk); tx_start=0;
      wait(!tx_busy); $display("UART_TX_PASS");
      rx=0; #(16*10); for(i=0;i<8;i=i+1) begin rx=(8'h5a>>i)&1; #(16*10); end rx=1; #(16*10);
      if(rx_ready && rx_data==8'h5a) $display("UART_RX_PASS"); else $display("UART_RX_FAIL data=%02x",rx_data);
      $finish;
    end
endmodule
