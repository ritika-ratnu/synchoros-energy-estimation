module adres_tile #(
  parameter int ROW = 0,
  parameter int COL = 0,
  parameter int ROWS = 4,
  parameter int COLS = 4,
  parameter bit FORCE_LINK_VALID = 1'b1
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,
  input  logic [pkg::CTX_ADDR_W-1:0]        context_addr_i,
  input  logic                              execute_enable_i,
  input  logic                              clear_outputs_i,
  input  logic                              cfg_write_enable_i,
  input  logic [pkg::CTX_ADDR_W-1:0]        cfg_write_addr_i,
  input  logic [pkg::TILE_CFG_W-1:0]        cfg_write_data_i,
  input  logic                              row_in_valid_i,
  input  logic [pkg::DATA_W-1:0]            row_in_data_i,
  input  logic [COLS-1:0][pkg::TOKEN_W-1:0] row_result_i,
  input  logic [COLS-1:0][pkg::NUM_PORTS-1:0] row_route_mask_i,
  input  logic [ROWS-1:0][pkg::TOKEN_W-1:0] col_result_i,
  input  logic [ROWS-1:0][pkg::NUM_PORTS-1:0] col_route_mask_i,
  input  logic [pkg::TOKEN_W-1:0]           mem_response_i,
  output logic [pkg::TOKEN_W-1:0]           result_o,
  output logic [pkg::NUM_PORTS-1:0]         route_mask_o
);

  logic [pkg::NUM_PORTS-1:0][pkg::TOKEN_W-1:0] core_port_in;
  logic [pkg::NUM_PORTS-1:0][pkg::TOKEN_W-1:0] core_port_out_unused;
  logic [pkg::TOKEN_W-1:0] core_alu_result_unused;

  local_noc_adapter #(
    .ROW              (ROW),
    .COL              (COL),
    .ROWS             (ROWS),
    .COLS             (COLS),
    .FORCE_LINK_VALID (FORCE_LINK_VALID)
  ) u_local_noc_adapter (
    .row_in_valid_i   (row_in_valid_i),
    .row_in_data_i    (row_in_data_i),
    .row_result_i     (row_result_i),
    .row_route_mask_i (row_route_mask_i),
    .col_result_i     (col_result_i),
    .col_route_mask_i (col_route_mask_i),
    .mem_response_i   (mem_response_i),
    .port_in_o        (core_port_in)
  );

  tile_core u_tile_core (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .context_addr_i     (context_addr_i),
    .execute_enable_i   (execute_enable_i),
    .clear_outputs_i    (clear_outputs_i),
    .cfg_write_enable_i (cfg_write_enable_i),
    .cfg_write_addr_i   (cfg_write_addr_i),
    .cfg_write_data_i   (cfg_write_data_i),
    .port_in_i          (core_port_in),
    .port_out_o         (core_port_out_unused),
    .port_out_enable_o  (route_mask_o),
    .alu_result_o       (core_alu_result_unused),
    .output_register_o  (result_o)
  );

endmodule
