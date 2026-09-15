`timescale 1ns/1ps
module tb_cpu_uart_command;
localparam ROM="hello_uart.mem";

 reg clk=0,rst_n=0,rx=1;wire tx;wire[31:0]seg,pc,x10,mem0,status;
 asm_cpu_core #(.PROGRAM_FILE(ROM),.UART_CLOCK_HZ(3200),.UART_BAUD_HZ(100)) dut(
 .clk(clk),.rst_n(rst_n),.uart_rxd(rx),.uart_txd(tx),.seg7_value(seg),
 .pc_current(pc),.debug_x10(x10),.debug_mem0(mem0),.debug_uart_status(status));
 always #5 clk=~clk;
 reg seen_overrun=0;
 always @(posedge clk) if(rst_n && status[3]) seen_overrun=1;
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
 initial begin
 repeat(4)@(negedge clk);rst_n=1;
 expect_text("Hi.\015\n",5);
 if(seg!==32'h2026)$fatal(1,"STARTUP_DISPLAY_FAIL");
 transact("HELP\015\n",6,"HELP ADD SORT\015\n",15,32'h2026);
 $display("CPU_COMMAND_HELP_PASS");
 transact("ADD 12 34\015\n",11,"46\015\n",4,32'h2e);
 transact("ADD -5 8\n",9,"3\015\n",3,32'h3);
 transact("ADD 2147483647 0\015",17,"2147483647\015\n",12,32'h7fffffff);
 transact("ADD -2147483648 0\n",18,"-2147483648\015\n",13,32'h80000000);
 transact("ADD -2147483648 2147483647\n",27,"-1\015\n",4,32'hffffffff);
 transact("ADD -0 0\n",9,"0\015\n",3,32'h0);
 transact("ADD 2147483647 1\n",17,"ERR\015\n",5,32'h0);
 transact("ADD -2147483648 -1\n",19,"ERR\015\n",5,32'h0);
 transact("ADD 2147483648 0\n",17,"ERR\015\n",5,32'h0);
 transact("ADD -2147483649 0\n",18,"ERR\015\n",5,32'h0);
 transact("ADD 999999999999999 1\n",22,"ERR\015\n",5,32'h0);
 $display("CPU_COMMAND_ADD_PASS");
 transact("SORT 5 8 2 7 3\015\n",16,"2 3 5 7 8\015\n",11,32'h2);
 transact("SORT -3 2 -3 0 2\n",17,"-3 -3 0 2 2\015\n",13,32'hfffffffd);
 transact("SORT 2147483647 0 -2147483648 1 -1\n",35,"-2147483648 -1 0 1 2147483647\015\n",31,32'h80000000);
 $display("CPU_COMMAND_SORT_PASS");
 transact("BOGUS\n",6,"ERR\015\n",5,32'h80000000);
 transact("help\n",5,"ERR\015\n",5,32'h80000000);
 transact("HELP X\n",7,"ERR\015\n",5,32'h80000000);
 transact("ADD\n",4,"ERR\015\n",5,32'h80000000);
 transact("ADD 1\n",6,"ERR\015\n",5,32'h80000000);
 transact("ADD 1 2 3\n",10,"ERR\015\n",5,32'h80000000);
 transact("ADD - 2\n",8,"ERR\015\n",5,32'h80000000);
 transact("ADD 1-2 3\n",10,"ERR\015\n",5,32'h80000000);
 transact("ADD +1 2\n",9,"ERR\015\n",5,32'h80000000);
 transact("ADD 1\0112\n",8,"ERR\015\n",5,32'h80000000);
 transact("SORT 1 2 3 4\n",13,"ERR\015\n",5,32'h80000000);
 transact("SORT 1 2 3 4 5 6\n",17,"ERR\015\n",5,32'h80000000);
 transact("SORT 1 2 3 4 2147483648\n",24,"ERR\015\n",5,32'h80000000);
 transact("HELP                                                            \015\n",66,"HELP ADD SORT\015\n",15,32'h80000000);
 transact("HELP                                                             \015\n",67,"ERR\015\n",5,32'h80000000);
 transact("\015\n\n   \n",7,"",0,32'h80000000);
 send_text("AD",2);send_byte(0,1);transact("D 1 2\n",6,"ERR\015\n",5,32'h80000000);
 send_text("ADD 1 ",6);send_byte(8'h58,0);transact("2\015\n",3,"ERR\015\n",5,32'h80000000);
 transact("ADD 1 2\nADD 3 4\n",16,"3\015\n7\015\n",6,32'h7);
 // Overload while HELP is transmitting: detect, discard to next delimiter, recover.
 seen_overrun=0;
 send_text("HELP\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",45);
 expect_text("HELP ADD SORT\015\n",15);
 if(!seen_overrun)$fatal(1,"OVERLOAD_NOT_EXERCISED");
 repeat(500)@(negedge clk);
 transact("\015\n",2,"ERR\015\n",5,32'd7);
 transact("ADD 20 22\015\n",11,"42\015\n",4,32'h2a);
 $display("CPU_COMMAND_BOUNDARY_PASS");$finish;end
endmodule
