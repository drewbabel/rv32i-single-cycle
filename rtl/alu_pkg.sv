// Shared types for the RV32I datapath.
// Will grow into the core-wide package (opcodes, funct3/funct7 decode,
// reg-file/CSR constants) once the modules that consume those exist

package alu_pkg;

  typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND
  } alu_op_e;

endpackage
