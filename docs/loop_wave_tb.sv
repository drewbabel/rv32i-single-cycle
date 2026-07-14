`timescale 1ns / 1ps
// throwaway loop waveform tb
module loop_wave_tb;
  localparam int Xlen  = 32;
  localparam int Depth = 64;

  logic            clk = 1'b0;
  logic            rst_n;
  logic [Xlen-1:0] pc;
  logic [Xlen-1:0] alu_result;
  logic [Xlen-1:0] write_data;
  logic            mem_write;

  always #5 clk = ~clk;

  top #(.XLEN(Xlen), .DEPTH(Depth)) dut (
      .clk(clk), .rst_n(rst_n), .pc(pc),
      .alu_result(alu_result), .write_data(write_data), .mem_write(mem_write)
  );

  task automatic do_reset();
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask

  integer f;
  initial begin
    f = $fopen("loop_wave.csv", "w");
    $fwrite(f, "pc,instr,pc_src,x1,x2,mem_write\n");
    $readmemh("tests/loop.hex", dut.imem_inst.mem);
    do_reset();
    #1;
    repeat (26) begin
      $fwrite(f, "%0d,%0d,%0d,%0d,%0d,%0d\n",
              pc, dut.instr, dut.riscv_single_inst.pc_src,
              dut.riscv_single_inst.datapath_inst.regfile_inst.regfile_mem[1],
              dut.riscv_single_inst.datapath_inst.regfile_inst.regfile_mem[2],
              mem_write);
      @(posedge clk);
      #1;
    end
    $fclose(f);
    $finish;
  end
endmodule
