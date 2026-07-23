module local_noc_adapter #(
  parameter int ROW = 0,
  parameter int COL = 0,
  parameter int ROWS = 4,
  parameter int COLS = 4,
  parameter bit FORCE_LINK_VALID = 1'b1
) (
  input  logic                              row_in_valid_i,
  input  logic [pkg::DATA_W-1:0]            row_in_data_i,
  input  logic [COLS-1:0][pkg::TOKEN_W-1:0] row_result_i,
  input  logic [COLS-1:0][pkg::NUM_PORTS-1:0] row_route_mask_i,
  input  logic [ROWS-1:0][pkg::TOKEN_W-1:0] col_result_i,
  input  logic [ROWS-1:0][pkg::NUM_PORTS-1:0] col_route_mask_i,
  input  logic [pkg::TOKEN_W-1:0]           mem_response_i,
  output logic [pkg::NUM_PORTS-1:0]
               [pkg::TOKEN_W-1:0]           port_in_o
);

  import pkg::*;

  localparam int PORT_ROW_EP = 4;
  localparam int PORT_COL_R0 = 5;
  localparam int PORT_MEM_EP = 9;

  function automatic token_t make_link_token(input token_t value);
    begin
      make_link_token = value;
      if (FORCE_LINK_VALID) begin
        make_link_token[TOKEN_W-1] = 1'b1;
      end
    end
  endfunction

  integer src_col;
  integer src_row;

  always_comb begin
    port_in_o = '0;

    for (src_col = 0; src_col < COLS; src_col = src_col + 1) begin
      if (row_route_mask_i[src_col][COL]) begin
        port_in_o[src_col] = make_link_token(row_result_i[src_col]);
      end
    end

    if (row_in_valid_i) begin
      port_in_o[PORT_ROW_EP] = {1'b1, row_in_data_i};
    end

    for (src_row = 0; src_row < ROWS; src_row = src_row + 1) begin
      if (col_route_mask_i[src_row][PORT_COL_R0 + ROW]) begin
        port_in_o[PORT_COL_R0 + src_row] =
            make_link_token(col_result_i[src_row]);
      end
    end

    port_in_o[PORT_MEM_EP] = mem_response_i;
  end

`ifndef SYNTHESIS
  initial begin
    assert (ROWS == 4 && COLS == 4)
      else $error("local_noc_adapter requires the existing 4x4 port map");
    assert (ROW >= 0 && ROW < ROWS)
      else $error("local_noc_adapter ROW parameter is out of range");
    assert (COL >= 0 && COL < COLS)
      else $error("local_noc_adapter COL parameter is out of range");
  end
`endif

endmodule
