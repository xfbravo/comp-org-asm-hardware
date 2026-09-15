`timescale 1ns/1ps
module tb_cpu_mmio_hazards;
localparam ROM="mmio_hazards.mem";

 reg clk=0,rst_n=0,rx=1;wire tx;wire[31:0]seg,pc,x10,mem0,status;
 asm_cpu_core #(.PROGRAM_FILE(ROM),.UART_CLOCK_HZ(3200),.UART_BAUD_HZ(100)) dut(
 .clk(clk),.rst_n(rst_n),.uart_rxd(rx),.uart_txd(tx),.seg7_value(seg),
 .pc_current(pc),.debug_x10(x10),.debug_mem0(mem0),.debug_uart_status(status));
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

 integer tx_writes=0,rx_reads=0,seg_writes=0;
 always @(posedge clk) if(rst_n) begin
  if(dut.mmio_wr && dut.dmem_addr==32'h40000000)tx_writes=tx_writes+1;
  if(dut.mmio_rd && dut.dmem_addr==32'h40000004)rx_reads=rx_reads+1;
  if(dut.mmio_wr && dut.dmem_addr==32'h40000010)seg_writes=seg_writes+1;
  if(seg==32'hbad)$fatal(1,"HAZARD_SIGNATURE_FAIL");
 end
 initial begin
 repeat(4)@(negedge clk);rst_n=1;
 send_text("AB",2);expect_text("AB",2);
 wait(seg==32'h600d);repeat(500)@(negedge clk);
 if(mem0!==65 || x10!==0 || status[8:5]!==0 || tx_writes!=2 || rx_reads!=2 || seg_writes!=2 || got!=2)
 $fatal(1,"WRONG_PATH_SIDE_EFFECT tx=%0d rx=%0d seg=%0d",tx_writes,rx_reads,seg_writes);
 $display("CPU_MMIO_HAZARDS_PASS");$finish;end
endmodule
