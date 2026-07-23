module adres_tile_array #(
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
  input  logic [3:0]                        cfg_tile_i,
  input  logic [pkg::CTX_ADDR_W-1:0]        cfg_write_addr_i,
  input  logic [pkg::TILE_CFG_W-1:0]        cfg_write_data_i,
  input  logic [ROWS-1:0]                   row_in_valid_i,
  input  logic [ROWS-1:0][pkg::DATA_W-1:0] row_in_data_i,
  input  logic [pkg::TOKEN_W-1:0]           mem_response_i [0:ROWS*COLS-1],
  output logic [pkg::TOKEN_W-1:0]           tile_result_o [0:ROWS*COLS-1],
  output logic [pkg::NUM_PORTS-1:0]         tile_route_mask_o [0:ROWS*COLS-1]
);

  localparam int TILE_ID_W = 4;

  logic [ROWS-1:0][COLS-1:0][pkg::TOKEN_W-1:0]
      tile_result_by_coord;
  logic [ROWS-1:0][COLS-1:0][pkg::NUM_PORTS-1:0]
      tile_route_mask_by_coord;

  // Transposed views provide each tile with the registered outputs and route
  // masks of all sources in its column. The row view is already contiguous.
  logic [COLS-1:0][ROWS-1:0][pkg::TOKEN_W-1:0]
      col_result_bus;
  logic [COLS-1:0][ROWS-1:0][pkg::NUM_PORTS-1:0]
      col_route_mask_bus;

  generate
    for (genvar row = 0; row < ROWS; row = row + 1) begin : g_row
      for (genvar col = 0; col < COLS; col = col + 1) begin : g_col
        localparam int TILE_ID = row * COLS + col;
        localparam logic [TILE_ID_W-1:0] TILE_ID_VALUE = TILE_ID;

        assign col_result_bus[col][row] = tile_result_by_coord[row][col];
        assign col_route_mask_bus[col][row] =
            tile_route_mask_by_coord[row][col];

        assign tile_result_o[TILE_ID] = tile_result_by_coord[row][col];
        assign tile_route_mask_o[TILE_ID] =
            tile_route_mask_by_coord[row][col];

        adres_tile #(
          .ROW              (row),
          .COL              (col),
          .ROWS             (ROWS),
          .COLS             (COLS),
          .FORCE_LINK_VALID (FORCE_LINK_VALID)
        ) u_adres_tile (
          .clk_i              (clk_i),
          .rst_ni             (rst_ni),
          .context_addr_i     (context_addr_i),
          .execute_enable_i   (execute_enable_i),
          .clear_outputs_i    (clear_outputs_i),
          .cfg_write_enable_i (cfg_write_enable_i &&
                               (cfg_tile_i == TILE_ID_VALUE)),
          .cfg_write_addr_i   (cfg_write_addr_i),
          .cfg_write_data_i   (cfg_write_data_i),
          .row_in_valid_i     (row_in_valid_i[row]),
          .row_in_data_i      (row_in_data_i[row]),
          .row_result_i       (tile_result_by_coord[row]),
          .row_route_mask_i   (tile_route_mask_by_coord[row]),
          .col_result_i       (col_result_bus[col]),
          .col_route_mask_i   (col_route_mask_bus[col]),
          .mem_response_i     (mem_response_i[TILE_ID]),
          .result_o           (tile_result_by_coord[row][col]),
          .route_mask_o       (tile_route_mask_by_coord[row][col])
        );
      end
    end
  endgenerate

endmodule
