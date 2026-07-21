module reg_file #(
  parameter int DATA_W = 33,
  parameter int DEPTH  = 16,
  parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  write_enable_i,
  input  logic [ADDR_W-1:0]     write_addr_i,
  input  logic [DATA_W-1:0]     write_data_i,

  input  logic [ADDR_W-1:0]     predicate_read_addr_i,
  input  logic [ADDR_W-1:0]     lhs_read_addr_i,
  input  logic [ADDR_W-1:0]     rhs_read_addr_i,

  output logic [DATA_W-1:0]     predicate_read_data_o,
  output logic [DATA_W-1:0]     lhs_read_data_o,
  output logic [DATA_W-1:0]     rhs_read_data_o
);

  logic [DATA_W-1:0] mem [0:DEPTH-1];
  integer index;

  // Three asynchronous read ports correspond to P, I1/LHS, and I2/RHS.
  // Read-during-write uses the old value for the calculation ending at the
  // active edge; the new value is visible after that edge.
  always_comb begin
    predicate_read_data_o = (int'(predicate_read_addr_i) < DEPTH) ?
                            mem[predicate_read_addr_i] : '0;
    lhs_read_data_o       = (int'(lhs_read_addr_i) < DEPTH) ?
                            mem[lhs_read_addr_i] : '0;
    rhs_read_data_o       = (int'(rhs_read_addr_i) < DEPTH) ?
                            mem[rhs_read_addr_i] : '0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (index = 0; index < DEPTH; index = index + 1) begin
        mem[index] <= '0;
      end
    end else if (write_enable_i && (int'(write_addr_i) < DEPTH)) begin
      mem[write_addr_i] <= write_data_i;
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni && write_enable_i) begin
      assert (int'(write_addr_i) < DEPTH)
        else $error("Register-file address %0d is outside depth %0d",
                    write_addr_i, DEPTH);
    end
  end
`endif

endmodule
