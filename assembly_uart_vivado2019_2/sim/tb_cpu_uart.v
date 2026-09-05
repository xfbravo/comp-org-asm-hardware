`timescale 1ns / 1ps
module tb_cpu_uart;
  localparam integer CLOCK_HZ = 1600;
  localparam integer BAUD_HZ = 100;
  localparam integer BIT_TIME_NS = 160;
  reg clk=0, rst_n=0, rx=1; wire tx; wire [31:0] seg7;
  wire halted, wb_valid, wb_we; wire [31:0] pc, wb_pc, wb_data, instr, x10, mem0, status; wire [4:0] wb_rd;
  asm_cpu_core #(.PROGRAM_FILE("hello_uart.mem"), .UART_CLOCK_HZ(CLOCK_HZ), .UART_BAUD_HZ(BAUD_HZ)) dut(
    .clk(clk),.rst_n(rst_n),.uart_rxd(rx),.uart_txd(tx),.seg7_value(seg7),.halted(halted),.pc_current(pc),
    .debug_wb_valid(wb_valid),.debug_wb_pc(wb_pc),.debug_wb_reg_write(wb_we),.debug_wb_rd(wb_rd),.debug_wb_data(wb_data),
    .debug_instr(instr),.debug_x10(x10),.debug_mem0(mem0),.debug_uart_status(status));
  always #5 clk=~clk;
  integer cycles, failures, i;
  reg [7:0] received;
  task receive_uart_byte;
    output [7:0] data;
    integer bit_index;
    begin
      @(negedge tx);
      #(BIT_TIME_NS + BIT_TIME_NS/2);
      for(bit_index=0; bit_index<8; bit_index=bit_index+1) begin
        data[bit_index]=tx;
        #(BIT_TIME_NS);
      end
      if(tx!==1'b1) begin $display("UART_STOP_BIT_FAIL"); failures=failures+1; end
    end
  endtask
  task expect_byte;
    input [7:0] expected;
    begin
      receive_uart_byte(received);
      if(received!==expected) begin
        $display("UART_BYTE_FAIL expected=%02x got=%02x",expected,received); failures=failures+1;
      end else $display("UART_BYTE_PASS %02x",received);
    end
  endtask
  initial begin
    failures=0; repeat(4) @(posedge clk); rst_n=1;
    expect_byte(8'h48); expect_byte(8'h69); expect_byte(8'h2e); expect_byte(8'h0d); expect_byte(8'h0a);
    cycles=0;
    while(cycles<500 && seg7!==32'h00002026) begin @(posedge clk); cycles=cycles+1; end
    if(seg7===32'h00002026) $display("CPU_MMIO_SEG7_PASS");
    else begin $display("CPU_MMIO_SEG7_FAIL seg7=%08x",seg7); failures=failures+1; end
    if(failures==0) $display("CPU_UART_TEST_PASSED"); else $display("CPU_UART_TEST_FAILED count=%0d",failures);
    $finish;
  end
endmodule
