`timescale 1ns/1ps

`ifdef IP_CONSUMER
module tb_uart_mmio_bridge_ip;
`else
module tb_uart_mmio;
`endif
 reg clk=0,rst_n=0,rd=0,wr=0,rx=1;
 reg [31:0] addr=0,wdata=0;
 wire [31:0] rdata,seg;
 wire tx,busy,ready,fe,ov,start,ack,we;
 wire [7:0] data,txdata;wire [3:0] level;
`ifdef IP_CONSUMER
 uart_mmio_bridge_consumer dut(
`else
 uart_mmio_bridge #(.CLOCK_HZ(1600),.BAUD_HZ(100)) dut(
`endif
 .clk(clk),.rst_n(rst_n),.mmio_read(rd),.mmio_write(wr),.mmio_addr(addr),
 .mmio_wdata(wdata),.mmio_rdata(rdata),.uart_rxd(rx),.uart_txd(tx),
 .uart_tx_busy(busy),.uart_rx_ready(ready),.uart_rx_data(data),
 .uart_frame_error(fe),.uart_rx_overrun(ov),.uart_rx_level(level),
 .uart_tx_start(start),.uart_tx_data(txdata),.uart_rx_ack(ack),
 .seg7_we(we),.seg7_value(seg));
`ifdef IP_CONSUMER
 wire [31:0] ref_rdata,ref_seg;wire ref_tx,ref_busy,ref_ready,ref_fe,ref_ov,ref_start,ref_ack,ref_we;
 wire [7:0] ref_data,ref_txdata;wire [3:0] ref_level;
 reference_uart_mmio_bridge #(.CLOCK_HZ(1600),.BAUD_HZ(100)) reference_dut(
 .clk(clk),.rst_n(rst_n),.mmio_read(rd),.mmio_write(wr),.mmio_addr(addr),.mmio_wdata(wdata),
 .mmio_rdata(ref_rdata),.uart_rxd(rx),.uart_txd(ref_tx),.uart_tx_busy(ref_busy),
 .uart_rx_ready(ref_ready),.uart_rx_data(ref_data),.uart_frame_error(ref_fe),
 .uart_rx_overrun(ref_ov),.uart_rx_level(ref_level),.uart_tx_start(ref_start),
 .uart_tx_data(ref_txdata),.uart_rx_ack(ref_ack),.seg7_we(ref_we),.seg7_value(ref_seg));
 always @(negedge clk) if(rst_n)
 if({rdata,seg,tx,busy,ready,fe,ov,start,ack,we,data,txdata,level} !==
    {ref_rdata,ref_seg,ref_tx,ref_busy,ref_ready,ref_fe,ref_ov,ref_start,ref_ack,ref_we,ref_data,ref_txdata,ref_level})
 $fatal(1,"IP_DIRECT_EQUIVALENCE_FAIL");
`endif
 always #5 clk=~clk;
 initial begin #1000000;$fatal(1,"MMIO_TIMEOUT");end
 task send;input [7:0] b;input stop;integer i;
 begin @(negedge clk);rx=0;repeat(16)@(negedge clk);
 for(i=0;i<8;i=i+1)begin rx=b[i];repeat(16)@(negedge clk);end
 rx=stop;repeat(16)@(negedge clk);rx=1;repeat(4)@(negedge clk);
 end endtask
 task write_reg;input [31:0] a,v;
 begin @(negedge clk);addr=a;wdata=v;wr=1;@(negedge clk);wr=0;end endtask
 task read_reg;input [31:0] a,expected;
 begin @(negedge clk);addr=a;rd=1;#1;if(rdata!==expected)$fatal(1,"MMIO_READ_FAIL addr=%h got=%h exp=%h",a,rdata,expected);
 @(negedge clk);rd=0;end endtask
 integer i;reg[7:0] decoded;
 initial begin
 repeat(4)@(negedge clk);rst_n=1;
 read_reg(32'h40000008,1);
 write_reg(32'h40000010,32'h89abcdef);
 if(seg!==32'h89abcdef || !we)$fatal(1,"SEG_WRITE_FAIL");
 write_reg(32'h00000010,0);
 if(seg!==32'h89abcdef)$fatal(1,"RAM_MMIO_ALIAS_FAIL");
 fork
 begin
  @(negedge clk);addr=32'h40000000;wdata=8'ha5;wr=1;
  @(negedge clk);addr=32'h40000008;#1;
  if(rdata[0]!==0)$fatal(1,"TX_PENDING_WINDOW_FAIL");
  addr=32'h40000000;wdata=8'h33;
  @(negedge clk);wr=0;
 end
 begin
  @(negedge tx);#80;if(tx!==0)$fatal(1,"TX_START_FAIL");
  for(i=0;i<8;i=i+1)begin #160;decoded[i]=tx;end
  #160;if(tx!==1 || decoded!==8'ha5)$fatal(1,"TX_BUSY_OVERWRITE_FAIL");
 end
 join
 wait(!busy);repeat(20)@(negedge clk);if(start || busy)$fatal(1,"EXTRA_TX_FAIL");
 send(8'h11,1);send(8'h22,1);send(8'h33,1);
 read_reg(32'h40000008,32'h63);
 // Continuous read transactions: read old head on each active edge.
 @(negedge clk);addr=32'h40000004;rd=1;
 #1;if(rdata!==8'h11)$fatal(1,"HEAD1_FAIL");
 @(negedge clk);#1;if(rdata!==8'h22)$fatal(1,"HEAD2_FAIL");
 @(negedge clk);#1;if(rdata!==8'h33)$fatal(1,"HEAD3_FAIL");
 @(negedge clk);#1;if(rdata!==0)$fatal(1,"EMPTY_FAIL");
 @(negedge clk);rd=0;
 send(8'h44,0);read_reg(32'h40000008,5);read_reg(32'h40000008,5);
 read_reg(32'h40000004,0);read_reg(32'h40000008,1);
 for(i=0;i<8;i=i+1)send(i,1);
 read_reg(32'h40000008,32'h113);
 send(8'hff,1);read_reg(32'h40000008,32'h11b);
 read_reg(32'h40000004,0);read_reg(32'h40000008,32'hf3);
 for(i=1;i<8;i=i+1)read_reg(32'h40000004,i);
 read_reg(32'h40000008,1);
 if(seg!==32'h89abcdef)$fatal(1,"SEG_CORRUPTED");
 $display("UART_MMIO_PASS");
`ifdef IP_CONSUMER
 $display("UART_IP_SMOKE_PASS");
`endif
 $finish;
 end
endmodule
