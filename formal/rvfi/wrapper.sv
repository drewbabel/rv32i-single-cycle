module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);

  // Free solver inputs
  (* keep *)`rvformal_rand_reg [31:0] instr;
  (* keep *)`rvformal_rand_reg [31:0] read_data;

  (* keep *)logic              [31:0] pc;
  (* keep *)logic              [31:0] alu_result;
  (* keep *)logic              [31:0] write_data;
  (* keep *)logic              [ 3:0] store_wstrb;
  (* keep *)logic              [31:0] store_data;
  (* keep *)logic                     mem_write;

  // Formal-only taps
  (* keep *)logic              [31:0] dbg_rs1_data;
  (* keep *)logic              [31:0] dbg_rd_wdata;
  (* keep *)logic                     dbg_reg_write;

  logic              [31:0] ret_instr;
  logic              [31:0] ret_pc;
  logic              [31:0] ret_rs1_data;
  logic              [31:0] ret_rs2_data;
  logic              [31:0] ret_rd_wdata;
  logic                     ret_reg_write;
  logic              [31:0] ret_alu_result;
  logic              [31:0] ret_read_data;
  logic              [ 3:0] ret_store_wstrb;
  logic              [31:0] ret_store_data;
  logic                     valid_q;
  logic              [63:0] order_q;
  logic              [ 3:0] rmask_c;
  logic                     rd_nonzero;

  riscv_single uut (
      .clk          (clock),
      .rst_n        (!reset),
      .instr        (instr),
      .read_data    (read_data),
      .pc           (pc),
      .mem_write    (mem_write),
      .alu_result   (alu_result),
      .write_data   (write_data),
      .store_wstrb  (store_wstrb),
      .store_data   (store_data),
      .dbg_rs1_data (dbg_rs1_data),
      .dbg_rd_wdata (dbg_rd_wdata),
      .dbg_reg_write(dbg_reg_write)
  );

  // Retirement register
  always_ff @(posedge clock) begin
    ret_instr       <= instr;
    ret_pc          <= pc;
    ret_rs1_data    <= dbg_rs1_data;
    ret_rs2_data    <= write_data;
    ret_rd_wdata    <= dbg_rd_wdata;
    ret_reg_write   <= dbg_reg_write;
    ret_alu_result  <= alu_result;
    ret_read_data   <= read_data;
    ret_store_wstrb <= store_wstrb;
    ret_store_data  <= store_data;
  end

  always_ff @(posedge clock) begin
    valid_q <= !reset;
    if (reset) order_q <= 64'd0;
    else if (valid_q) order_q <= order_q + 64'd1;
  end

  assign rvfi_valid     = valid_q;
  assign rvfi_order     = order_q;

  assign rd_nonzero     = ret_reg_write && (ret_instr[11:7] != 5'd0);
  assign rvfi_insn      = ret_instr;
  assign rvfi_rs1_addr  = ret_instr[19:15];
  assign rvfi_rs2_addr  = ret_instr[24:20];
  assign rvfi_rs1_rdata = ret_rs1_data;
  assign rvfi_rs2_rdata = ret_rs2_data;
  assign rvfi_rd_addr   = rd_nonzero ? ret_instr[11:7] : 5'd0;
  assign rvfi_rd_wdata  = rd_nonzero ? ret_rd_wdata : 32'd0;

  assign rvfi_mem_addr  = {ret_alu_result[31:2], 2'b00};
  assign rvfi_mem_wmask = ret_store_wstrb;
  assign rvfi_mem_rmask = rmask_c;
  assign rvfi_mem_rdata = ret_read_data;
  assign rvfi_mem_wdata = ret_store_data;

  always_comb begin
    rmask_c = 4'b0000;
    if (ret_instr[6:0] == 7'b0000011) begin
      case (ret_instr[14:12])
        3'b000, 3'b100: rmask_c = 4'b0001 << ret_alu_result[1:0];
        3'b001, 3'b101: rmask_c = 4'b0011 << ret_alu_result[1:0];
        3'b010:         rmask_c = 4'b1111;
        default:        rmask_c = 4'b0000;
      endcase
    end
  end

  assign rvfi_trap     = 1'b0;
  assign rvfi_halt     = 1'b0;
  assign rvfi_intr     = 1'b0;
  assign rvfi_mode     = 2'd3;
  assign rvfi_ixl      = 2'd1;
  assign rvfi_pc_rdata = ret_pc;
  assign rvfi_pc_wdata = pc;

  // Aligned fetch only, misaligned trap is 5.8
  always_comb if (!reset) assume (pc[1:0] == 2'b00);

  // Aligned data only, misaligned trap is 5.8
  always_comb begin
    if (!reset && (instr[6:0] == 7'b0000011 || instr[6:0] == 7'b0100011)) begin
      case (instr[14:12])
        3'b001, 3'b101: assume (alu_result[0] == 1'b0);
        3'b010:         assume (alu_result[1:0] == 2'b00);
        default:        ;
      endcase
    end
  end

endmodule
