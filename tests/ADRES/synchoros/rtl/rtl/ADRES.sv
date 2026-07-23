module ADRES #(
  parameter int DMEM_WORDS_PER_BANK = 256,
  parameter int DMEM_ADDR_W =
      (DMEM_WORDS_PER_BANK <= 1) ? 1 : $clog2(DMEM_WORDS_PER_BANK),
  parameter bit FORCE_LINK_VALID = 1'b1
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  input  logic                        run_i,
  input  logic                        set_context_i,
  input  logic [pkg::CTX_ADDR_W-1:0] set_context_addr_i,
  input  logic                        clear_outputs_i,
  output logic                        execute_enable_o,
  output logic [pkg::CTX_ADDR_W-1:0] context_addr_o,
  output logic                        stall_o,
  output logic                        array_idle_o,

  input  logic                        cfg_write_enable_i,
  input  logic [3:0]                  cfg_tile_i,
  input  logic [pkg::CTX_ADDR_W-1:0] cfg_write_addr_i,
  input  logic [pkg::TILE_CFG_W-1:0] cfg_write_data_i,

  input  logic [3:0]                  row_in_valid_i,
  input  logic [3:0][31:0]            row_in_data_i,
  output logic [3:0]                  row_in_ready_o,

  output logic [3:0]                  row_out_valid_o,
  output logic [3:0][31:0]            row_out_data_o,
  output logic [3:0][1:0]             row_out_source_o,
  input  logic [3:0]                  row_out_ready_i,

  input  logic                        dmem_host_valid_i,
  input  logic                        dmem_host_write_i,
  input  logic [1:0]                  dmem_host_bank_i,
  input  logic [DMEM_ADDR_W-1:0]      dmem_host_addr_i,
  input  logic [31:0]                 dmem_host_wdata_i,
  output logic                        dmem_host_ready_o,
  output logic                        dmem_host_rvalid_o,
  output logic [31:0]                 dmem_host_rdata_o
);

  logic [pkg::TOKEN_W-1:0]   tile_result [0:15];
  logic [pkg::NUM_PORTS-1:0] tile_route_mask [0:15];
  logic [pkg::TOKEN_W-1:0]   mem_response [0:15];

  logic endpoint_stall;
  logic row_activity;
  logic mem_activity;
  logic store_pending_any;

  logic [3:0]                   mem_request_valid;
  logic [3:0][3:0]              mem_request_tile;
  logic [3:0][pkg::TOKEN_W-1:0] mem_request_data;

  adres_control_status #(
    .ROWS (4)
  ) u_control_status (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .run_i                (run_i),
    .set_context_i        (set_context_i),
    .set_context_addr_i   (set_context_addr_i),
    .endpoint_stall_i     (endpoint_stall),
    .row_activity_i       (row_activity),
    .mem_activity_i       (mem_activity),
    .store_pending_any_i  (store_pending_any),
    .execute_enable_o     (execute_enable_o),
    .context_addr_o       (context_addr_o),
    .stall_o              (stall_o),
    .array_idle_o         (array_idle_o),
    .row_in_ready_o       (row_in_ready_o)
  );

  adres_tile_array #(
    .ROWS             (4),
    .COLS             (4),
    .FORCE_LINK_VALID (FORCE_LINK_VALID)
  ) u_tile_array (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .context_addr_i      (context_addr_o),
    .execute_enable_i    (execute_enable_o),
    .clear_outputs_i     (clear_outputs_i),
    .cfg_write_enable_i  (cfg_write_enable_i),
    .cfg_tile_i          (cfg_tile_i),
    .cfg_write_addr_i    (cfg_write_addr_i),
    .cfg_write_data_i    (cfg_write_data_i),
    .row_in_valid_i      (row_in_valid_i),
    .row_in_data_i       (row_in_data_i),
    .mem_response_i      (mem_response),
    .tile_result_o       (tile_result),
    .tile_route_mask_o   (tile_route_mask)
  );


  adres_endpoints #(
    .ROWS (4),
    .COLS (4)
  ) u_endpoints (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .execute_enable_i     (execute_enable_o),
    .clear_outputs_i      (clear_outputs_i),
    .tile_result_i        (tile_result),
    .tile_route_mask_i    (tile_route_mask),
    .row_out_ready_i      (row_out_ready_i),
    .row_out_valid_o      (row_out_valid_o),
    .row_out_data_o       (row_out_data_o),
    .row_out_source_o     (row_out_source_o),
    .endpoint_stall_o     (endpoint_stall),
    .row_activity_o       (row_activity),
    .mem_activity_o       (mem_activity),
    .mem_request_valid_o  (mem_request_valid),
    .mem_request_tile_o   (mem_request_tile),
    .mem_request_data_o   (mem_request_data)
  );

  adres_memory_subsystem #(
    .ROWS                (4),
    .COLS                (4),
    .DMEM_WORDS_PER_BANK (DMEM_WORDS_PER_BANK),
    .DMEM_ADDR_W         (DMEM_ADDR_W)
  ) u_memory_subsystem (
    .clk_i                 (clk_i),
    .rst_ni                (rst_ni),
    .run_i                 (run_i),
    .execute_enable_i      (execute_enable_o),
    .mem_activity_i        (mem_activity),
    .mem_request_valid_i   (mem_request_valid),
    .mem_request_tile_i    (mem_request_tile),
    .mem_request_data_i    (mem_request_data),
    .mem_response_o        (mem_response),
    .store_pending_any_o   (store_pending_any),
    .dmem_host_valid_i     (dmem_host_valid_i),
    .dmem_host_write_i     (dmem_host_write_i),
    .dmem_host_bank_i      (dmem_host_bank_i),
    .dmem_host_addr_i      (dmem_host_addr_i),
    .dmem_host_wdata_i     (dmem_host_wdata_i),
    .dmem_host_ready_o     (dmem_host_ready_o),
    .dmem_host_rvalid_o    (dmem_host_rvalid_o),
    .dmem_host_rdata_o     (dmem_host_rdata_o)
  );

  adres_checks #(
    .DMEM_WORDS_PER_BANK (DMEM_WORDS_PER_BANK),
    .DMEM_ADDR_W         (DMEM_ADDR_W)
  ) u_checks (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .run_i                (run_i),
    .cfg_write_enable_i   (cfg_write_enable_i),
    .cfg_tile_i           (cfg_tile_i),
    .dmem_host_valid_i    (dmem_host_valid_i),
    .dmem_host_ready_i    (dmem_host_ready_o)
  );

endmodule

`default_nettype wire
