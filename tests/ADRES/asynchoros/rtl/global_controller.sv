// Global controller 
module global_controller #(
  parameter int DEPTH  = 16,
  parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              run_i,
  input  logic              stall_i,
  input  logic              set_context_i,
  input  logic [ADDR_W-1:0] set_context_addr_i,

  output logic              execute_enable_o,
  output logic [ADDR_W-1:0] context_addr_o
);

  assign execute_enable_o = run_i && !stall_i && !set_context_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      context_addr_o <= '0;
    end else if (set_context_i) begin
      if (int'(set_context_addr_i) < DEPTH) begin
        context_addr_o <= set_context_addr_i;
      end else begin
        context_addr_o <= '0;
      end
    end else if (execute_enable_o) begin
      if (int'(context_addr_o) == DEPTH-1) begin
        context_addr_o <= '0;
      end else begin
        context_addr_o <= context_addr_o + 1'b1;
      end
    end
  end

endmodule
