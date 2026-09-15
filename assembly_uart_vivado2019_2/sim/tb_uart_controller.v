`timescale 1ns/1ps

module tb_uart_controller;
 reg clk=0,rst_n=0,rx=1,ack=0,start=0;
 reg [7:0] tx_data=0, sent=0;
 wire tx,busy,ready,fe,ov; wire [7:0] data; wire [3:0] level;
 uart_controller #(.CLOCK_HZ(1600),.BAUD_HZ(100)) dut(
 .clk(clk),.rst_n(rst_n),.rx(rx),.rx_ack(ack),.rx_data(data),.rx_ready(ready),
 .frame_error(fe),.rx_overrun(ov),.rx_level(level),
 .tx_data(tx_data),.tx_start(start),.tx_busy(busy),.tx(tx));
 always #5 clk=~clk;
 initial begin #2000000; $fatal(1,"UART_TIMEOUT"); end
 reg [7:0] model[0:1023]; integer head=0,tail=0,n=0,k,j; reg push,pop;
 // Unbounded reference queue, independent pointers and count from the DUT.
 // 'arrival' aligns simultaneous transactions; sent is the external stimulus.
 always @(posedge clk) if(rst_n) begin
   if(data !== (n==0 ? 8'd0 : model[head])) $fatal(1,"HEAD_UNSTABLE n=%0d",n);
   pop=ack && n>0;
   push=dut.arrival && (n<8 || pop);
   if(dut.arrival && dut.rx_shift!==sent) $fatal(1,"RX_BITS_FAIL");
   if(pop) begin head=head+1; n=n-1; end
   if(push) begin model[tail]=sent; tail=tail+1; n=n+1; end
   #1;
   if(level!==n || ready!==(n!=0)) $fatal(1,"FIFO_COUNT_FAIL n=%0d level=%0d",n,level);
   if(data !== (n==0 ? 8'd0 : model[head])) $fatal(1,"FIFO_DATA_FAIL");
 end
 task send;
 input [7:0] b; input good_stop;
 integer i;
 begin
  sent=b; @(negedge clk);rx=0; repeat(16) @(negedge clk);
  for(i=0;i<8;i=i+1) begin rx=b[i]; repeat(16) @(negedge clk); end
  rx=good_stop; repeat(16) @(negedge clk);
  rx=1; repeat(4) @(negedge clk);
 end endtask
 task take; begin @(negedge clk);ack=1; @(negedge clk);ack=0; end endtask
 task simultaneous;
 input [7:0] b;
 begin fork
  send(b,1);
  begin wait(dut.arrival); @(negedge clk);ack=1; @(negedge clk);ack=0; end
 join end endtask
 task check_tx;
 input [7:0] b;
 integer i;
 begin
  fork
   begin @(negedge clk);tx_data=b;start=1;@(negedge clk);start=0; end
   begin
    @(negedge tx); #80; if(tx!==0) $fatal(1,"TX_START_FAIL");
    for(i=0;i<8;i=i+1) begin #160; if(tx!==b[i]) $fatal(1,"TX_BIT_FAIL"); end
    #160; if(tx!==1) $fatal(1,"TX_STOP_FAIL");
   end
  join
  wait(!busy);
 end endtask
 initial begin
  repeat(4) @(negedge clk);rst_n=1;
  check_tx(8'h00);check_tx(8'ha5);check_tx(8'hff);
  $display("UART_TX_PASS");
  take(); if(level!=0 || data!=0) $fatal(1,"EMPTY_READ_FAIL");
  // Reject a low pulse shorter than half a bit.
  @(negedge clk);rx=0;repeat(3) @(negedge clk);rx=1;
  repeat(180) @(negedge clk);
  if(level!=0 || fe) $fatal(1,"GLITCH_FAIL");
  send(8'h5a,1); if(level!=1) $fatal(1,"RX_MISSING");take();
  $display("UART_RX_PASS");
  // Last-item pop, empty refill and many pointer wraps.
  for(k=0;k<24;k=k+1) begin send(k,1);take(); end
  for(k=0;k<8;k=k+1) send(8'h80+k,1);
  if(level!=8) $fatal(1,"FULL_FAIL");
  send(8'hee,1);if(!ov || level!=8) $fatal(1,"OVERRUN_FAIL");
  simultaneous(8'hf1); if(level!=8 || ov) $fatal(1,"FULL_SIMULTANEOUS_FAIL");
  repeat(8) take();
  simultaneous(8'hf2);if(level!=1) $fatal(1,"EMPTY_SIMULTANEOUS_FAIL");
  simultaneous(8'hf3);if(level!=1) $fatal(1,"SIMULTANEOUS_FAIL");
  take();
  send(8'h33,0);if(!fe || level!=0) $fatal(1,"FRAME_ERROR_FAIL");
  repeat(20) @(negedge clk);if(!fe) $fatal(1,"ERROR_NOT_STICKY");
  take();if(fe || ov) $fatal(1,"ERROR_CLEAR_FAIL");
  // Persistent break is one bad frame and cannot fabricate bytes.
  @(negedge clk);rx=0;repeat(500) @(negedge clk);
  if(!fe || level!=0) $fatal(1,"BREAK_FAIL");
  rx=1;repeat(20) @(negedge clk); take();
  send(8'hc3,1);take();
  // Clearing on the error edge must retain the new error.
  fork
   send(8'h00,0);
   begin wait(dut.bad_frame);@(negedge clk);ack=1;@(negedge clk);ack=0;end
  join
  if(!fe) $fatal(1,"NEW_ERROR_PRIORITY_FAIL");
  take();
  send(8'h99,1);
  @(negedge clk);rst_n=0;head=0;tail=0;n=0;
  repeat(3) @(negedge clk);
  if(level!=0 || fe || ov || data!=0 || busy) $fatal(1,"RESET_FAIL");
  rst_n=1;
  $display("UART_FIFO_PASS");$finish;
 end
endmodule
