module adres_control_status #(
  parameter int ROWS = 4
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        run_i,
  input  logic                        set_context_i,
  input  logic [pkg::CTX_ADDR_W-1:0] set_context_addr_i,
  input  logic                        endpoint_stall_i,
  input  logic                        row_activity_i,
  input  logic                        mem_activity_i,
  input  logic                        store_pending_any_i,
  output logic                        execute_enable_o,
  output logic [pkg::CTX_ADDR_W-1:0] context_addr_o,
  output logic                        stall_o,
  output logic                        array_idle_o,
  output logic [ROWS-1:0]             row_in_ready_o
);

  import pkg::*;

  global_controller #(
    .DEPTH  (CONTEXT_DEPTH),
    .ADDR_W (CTX_ADDR_W)
  ) u_context_controller (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .run_i              (run_i),
    .stall_i            (endpoint_stall_i),
    .set_context_i      (set_context_i),
    .set_context_addr_i (set_context_addr_i),
    .execute_enable_o   (execute_enable_o),
    .context_addr_o     (context_addr_o)
  );

  assign stall_o        = endpoint_stall_i;
  assign row_in_ready_o = {ROWS{execute_enable_o}};

  assign array_idle_o = !run_i && !execute_enable_o &&
                        !row_activity_i && !mem_activity_i &&
                        !store_pending_any_i;

endmodule
