`timescale 1ns/1ps
module tb_board_uart_command;
localparam ROM="hello_uart.mem";

 reg clk=0,rst_n=0,rx=1;wire tx;wire[31:0]seg,pc,x10,mem0,status;
 reg key=0;wire [7:0] anode,segment;
 asm_board_top #(.UART_CLOCK_HZ(1600),.UART_BAUD_HZ(100),.KEY_DEBOUNCE_TICKS(3)) dut(
 .clk(clk),.rst_n(rst_n),.uart_rxd(rx),.uart_txd(tx),.key_next(key),.anode(anode),.segment(segment));
 assign seg=dut.seg7;assign pc=dut.pc;assign status=dut.uart_status;
 assign x10=dut.x10;assign mem0=dut.mem0;
 always #5 clk=~clk;
 reg [7:0] captured[0:4095], ch;integer got=0,used=0,bit_i;
 initial begin #20000000;$fatal(1,"CPU_UART_TIMEOUT pc=%h status=%h got=%0d used=%0d",pc,status,got,used);end
 initial forever begin
   @(negedge tx);#160;if(tx!==0)$fatal(1,"CPU_TX_START_FAIL");
   for(bit_i=0;bit_i<8;bit_i=bit_i+1)begin #320;ch[bit_i]=tx;end
   #320;if(tx!==1)$fatal(1,"CPU_TX_STOP_FAIL");
   if(got>=4096)$fatal(1,"OUTPUT_OVERFLOW");
   captured[got]=ch;got=got+1;
 end
 task send_byte;input[7:0]b;input stop;integer i;
 begin
  @(negedge clk);rx=0;repeat(32)@(negedge clk);
  for(i=0;i<8;i=i+1)begin rx=b[i];repeat(32)@(negedge clk);end
  rx=stop;repeat(32)@(negedge clk);rx=1;
 end endtask
 task send_text;input[2047:0]s;input integer len;integer i;
 begin for(i=0;i<len;i=i+1)send_byte(s[8*(len-i)-1 -:8],1);end endtask
 task expect_text;input[2047:0]s;input integer len;integer i;
 begin
  wait(got>=used+len);
  for(i=0;i<len;i=i+1)
    if(captured[used+i]!==s[8*(len-i)-1 -:8])
      $fatal(1,"REPLY_FAIL byte=%0d got=%h exp=%h pc=%h",used+i,captured[used+i],s[8*(len-i)-1 -:8],pc);
  used=used+len;
 end endtask
 task transact;input[2047:0]cmd;input integer clen;input[2047:0]reply;input integer rlen;input[31:0]value;
 begin
  send_text(cmd,clen);expect_text(reply,rlen);
  repeat(500)@(negedge clk);
  if(seg!==value)$fatal(1,"COMMAND_DISPLAY_FAIL got=%h exp=%h",seg,value);
  if(got!=used)$fatal(1,"UNEXPECTED_REPLY");
 end endtask
 integer page_i;
 initial begin
 repeat(4)@(negedge clk);rst_n=1;
 expect_text("Hi.\015\n",5);
 transact("HELP\015\n",6,"HELP ADD SORT\015\n",15,32'h2026);
 transact("ADD 12 34\015\n",11,"46\015\n",4,32'd46);
 transact("SORT 5 8 2 7 3\015\n",16,"2 3 5 7 8\015\n",11,32'd2);
 if(dut.page!==4 || dut.display_value!==2)$fatal(1,"BOARD_DEFAULT_PAGE_FAIL");
 for(page_i=5;page_i<13;page_i=page_i+1)begin
  @(negedge clk);key=1;repeat(12)@(negedge clk);
  key=0;repeat(12)@(negedge clk);
  if(dut.page!==(page_i%8))$fatal(1,"BOARD_PAGE_FAIL");
  if(dut.page==6 && dut.display_value!==status[8:5])$fatal(1,"BOARD_FIFO_PAGE_FAIL");
  if(dut.page==7 && dut.display_value!==2)$fatal(1,"BOARD_RESULT_PAGE_FAIL");
 end
 if(^anode===1'bx || ^segment===1'bx)$fatal(1,"BOARD_SCAN_UNKNOWN");
 $display("BOARD_COMMAND_PASS");$finish;
 end
endmodule
