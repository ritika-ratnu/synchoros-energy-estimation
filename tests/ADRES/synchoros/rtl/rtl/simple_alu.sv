// 32-bit payload ALU with one extra token/guard bit on data operands/results.
// The payload behavior matches the supplied ALU; result[32] is intentionally
// zero for ALU-generated values.  The array wrapper can recreate token-valid on
// an enabled network route.
module simple_alu(op_predicate, op_LHS, op_RHS, op_SHIFT, operation, result);

  parameter width = 32;

  input  [32:0] op_RHS;
  input  [32:0] op_LHS;
  input  [32:0] op_SHIFT;
  input  [31:0] op_predicate;
  input  [5:0]  operation;

  output reg [32:0] result;

  wire [32:0] op_2;
  logic signed [63:0] multiply_result;

  assign op_2 = operation[5] ? op_SHIFT : op_LHS;

  always_comb begin : alu
    multiply_result = $signed(op_RHS[31:0]) * $signed(op_2[31:0]);

    case (operation[4:0])
      5'b00000: result = 33'b0; // nop
      5'b00001: result = {1'b0, (op_RHS[31:0] + op_2[31:0])}; // add
      5'b00010: result = {1'b0, (op_RHS[31:0] - op_2[31:0])}; // sub
      //5'b00011: result = {1'b0, multiply_result[31:0]}; // multiply, low word

      5'b01000: result = {1'b0, (op_RHS[31:0] << op_2[4:0])};
      5'b01001: result = {1'b0, (op_RHS[31:0] >> op_2[4:0])};
      5'b01010: result = {1'b0,
                          ($signed(op_RHS[31:0]) >>> op_2[4:0])};
      5'b01011: result = {1'b0, (op_RHS[31:0] & op_2[31:0])};
      5'b01100: result = {1'b0, (op_RHS[31:0] | op_2[31:0])};
      5'b01101: result = {1'b0, (op_RHS[31:0] ^ op_2[31:0])};

      5'b10000: begin
        if (operation[5] == 1'b0) begin
          if (op_LHS[32] == 1'b1)
            result = {1'b0, op_LHS[31:0]};
          else if (op_RHS[32] == 1'b1)
            result = {1'b0, op_RHS[31:0]};
          else
            result = 33'b0;
        end else begin
          result = {1'b0, op_SHIFT[31:0]};
        end
      end

      5'b10001: begin
        if (operation[5] == 1'b0)
          result = {1'b0, op_RHS[31:0]};
        else
          result = {1'b0, op_SHIFT[31:0]};
      end

      5'b10010: result = {32'b0, (op_RHS[31:0] == op_2[31:0])};
      5'b10011: result = {32'b0,
                          ($signed(op_RHS[31:0]) < $signed(op_2[31:0]))};
      5'b10100: result = {1'b0,
                          (op_predicate[31:0] | op_RHS[31:0] | op_2[31:0])};
      5'b10101: result = {32'b0,
                          ($signed(op_2[31:0]) < $signed(op_RHS[31:0]))};
      5'b11111: result = {1'b0, op_2[31:0]};
      default:  result = 33'b0;
    endcase
  end

endmodule
