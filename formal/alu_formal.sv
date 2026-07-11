module alu_formal
  import alu_pkg::*;
();

  localparam int XLEN = 32;
  localparam int SHAMT = $clog2(XLEN);  // Shift-amount width

  logic [XLEN-1:0] a;
  logic [XLEN-1:0] b;
  alu_pkg::alu_op_e alu_op;
  logic [XLEN-1:0] result;
  logic [XLEN-1:0] ref_result;
  logic zero;
  logic lt;
  logic ltu;

  alu dut (
      .a(a),
      .b(b),
      .alu_op(alu_op),
      .result(result),
      .zero(zero),
      .lt(lt),
      .ltu(ltu)
  );

  // Assert against DUT
  always_comb begin
    case (alu_op)
      ALU_ADD:  ref_result = a + b;
      ALU_SUB:  ref_result = a - b;
      ALU_SLL:  ref_result = a << b[SHAMT-1:0];
      ALU_SLT:  ref_result = ($signed(a) < $signed(b)) ? 1 : 0;
      ALU_SLTU: ref_result = (a < b) ? 1 : 0;
      ALU_XOR:  ref_result = a ^ b;
      ALU_SRL:  ref_result = a >> b[SHAMT-1:0];
      ALU_SRA:  ref_result = $signed(a) >>> b[SHAMT-1:0];
      ALU_OR:   ref_result = a | b;
      ALU_AND:  ref_result = a & b;
      default: ref_result = '0;
    endcase

    assert (result == ref_result);
    assert (zero == (ref_result == '0));
    assert (lt == (($signed(a) < $signed(b)) ? 1'b1 : 1'b0));
    assert (ltu == ((a < b) ? 1'b1 : 1'b0));
  end

endmodule
