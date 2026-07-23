module adres_endpoints #(
  parameter int ROWS = 4,
  parameter int COLS = 4
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,
  input  logic                              execute_enable_i,
  input  logic                              clear_outputs_i,
  input  logic [pkg::TOKEN_W-1:0]           tile_result_i [0:ROWS*COLS-1],
  input  logic [pkg::NUM_PORTS-1:0]         tile_route_mask_i [0:ROWS*COLS-1],
  input  logic [ROWS-1:0]                   row_out_ready_i,
  output logic [ROWS-1:0]                   row_out_valid_o,
  output logic [ROWS-1:0][pkg::DATA_W-1:0] row_out_data_o,
  output logic [ROWS-1:0][1:0]              row_out_source_o,
  output logic                              endpoint_stall_o,
  output logic                              row_activity_o,
  output logic                              mem_activity_o,
  output logic [COLS-1:0]                   mem_request_valid_o,
  output logic [COLS-1:0][3:0]              mem_request_tile_o,
  output logic [COLS-1:0][pkg::TOKEN_W-1:0] mem_request_data_o
);

  import pkg::*;

  localparam int TILES       = ROWS * COLS;
  localparam int TILE_ID_W   = 4;
  localparam int PORT_ROW_EP = 4;
  localparam int PORT_MEM_EP = 9;

  typedef logic [1:0] row_col_t;

  logic [TILES-1:0] rowq_valid_q;
  logic [TILES-1:0] rowq_push;
  logic [TILES-1:0] rowq_pop;
  token_t           rowq_data_q [0:TILES-1];

  logic [TILES-1:0] memq_valid_q;
  logic [TILES-1:0] memq_push;
  logic [TILES-1:0] memq_pop;
  token_t           memq_data_q [0:TILES-1];

  logic [TILES-1:0] row_route_consumed_q;
  logic [TILES-1:0] mem_route_consumed_q;
  logic [TILES-1:0] row_route_need;
  logic [TILES-1:0] mem_route_need;
  logic [TILES-1:0] rowq_can_accept;
  logic [TILES-1:0] memq_can_accept;

  row_col_t row_rr_ptr_q [0:ROWS-1];
  row_col_t mem_rr_ptr_q [0:COLS-1];
  logic [2:0] row_pick [0:ROWS-1];
  logic [2:0] mem_pick [0:COLS-1];

  function automatic logic [2:0] rr_pick4(
    input logic [3:0] request,
    input row_col_t   start
  );
    logic found;
    integer offset;
    row_col_t candidate;
    begin
      rr_pick4 = '0;
      found    = 1'b0;
      for (offset = 0; offset < 4; offset = offset + 1) begin
        candidate = start + row_col_t'(offset);
        if (!found && request[candidate]) begin
          rr_pick4[2]   = 1'b1;
          rr_pick4[1:0] = candidate;
          found         = 1'b1;
        end
      end
    end
  endfunction

  assign rowq_can_accept = ~rowq_valid_q | rowq_pop;
  assign memq_can_accept = ~memq_valid_q | memq_pop;

  generate
    for (genvar tile_index = 0; tile_index < TILES;
         tile_index = tile_index + 1) begin : g_endpoint_need
      assign row_route_need[tile_index] =
          !row_route_consumed_q[tile_index] &&
          tile_route_mask_i[tile_index][PORT_ROW_EP] &&
          !clear_outputs_i;

      assign mem_route_need[tile_index] =
          !mem_route_consumed_q[tile_index] &&
          tile_route_mask_i[tile_index][PORT_MEM_EP] &&
          !clear_outputs_i;
    end
  endgenerate

  assign rowq_push = row_route_need & rowq_can_accept;
  assign memq_push = mem_route_need & memq_can_accept;

  assign endpoint_stall_o =
      (|(row_route_need & ~rowq_can_accept)) |
      (|(mem_route_need & ~memq_can_accept));

  assign row_activity_o = (|rowq_valid_q) | (|row_route_need);
  assign mem_activity_o = (|memq_valid_q) | (|mem_route_need);

  integer endpoint_index;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      row_route_consumed_q <= '1;
      mem_route_consumed_q <= '1;
    end else if (clear_outputs_i) begin
      row_route_consumed_q <= '1;
      mem_route_consumed_q <= '1;
    end else begin
      for (endpoint_index = 0; endpoint_index < TILES;
           endpoint_index = endpoint_index + 1) begin
        if (execute_enable_i) begin
          row_route_consumed_q[endpoint_index] <= 1'b0;
          mem_route_consumed_q[endpoint_index] <= 1'b0;
        end else begin
          if (rowq_push[endpoint_index]) begin
            row_route_consumed_q[endpoint_index] <= 1'b1;
          end
          if (memq_push[endpoint_index]) begin
            mem_route_consumed_q[endpoint_index] <= 1'b1;
          end
        end
      end
    end
  end

  integer queue_index;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rowq_valid_q <= '0;
      memq_valid_q <= '0;
      for (queue_index = 0; queue_index < TILES;
           queue_index = queue_index + 1) begin
        rowq_data_q[queue_index] <= '0;
        memq_data_q[queue_index] <= '0;
      end
    end else begin
      for (queue_index = 0; queue_index < TILES;
           queue_index = queue_index + 1) begin
        case ({rowq_push[queue_index], rowq_pop[queue_index]})
          2'b10,
          2'b11: begin
            rowq_valid_q[queue_index] <= 1'b1;
            rowq_data_q[queue_index]  <= tile_result_i[queue_index];
          end
          2'b01: begin
            rowq_valid_q[queue_index] <= 1'b0;
          end
          default: begin
            rowq_valid_q[queue_index] <= rowq_valid_q[queue_index];
          end
        endcase

        case ({memq_push[queue_index], memq_pop[queue_index]})
          2'b10,
          2'b11: begin
            memq_valid_q[queue_index] <= 1'b1;
            memq_data_q[queue_index]  <= tile_result_i[queue_index];
          end
          2'b01: begin
            memq_valid_q[queue_index] <= 1'b0;
          end
          default: begin
            memq_valid_q[queue_index] <= memq_valid_q[queue_index];
          end
        endcase
      end
    end
  end

  always_comb begin : p_endpoint_arbiters
    integer row_index;
    integer col_index;
    integer lane_index;
    logic [3:0] request_vector;
    logic [TILE_ID_W-1:0] selected_tile;

    rowq_pop = '0;
    memq_pop = '0;

    row_out_valid_o  = '0;
    row_out_data_o   = '0;
    row_out_source_o = '0;

    mem_request_valid_o = '0;
    mem_request_tile_o  = '0;
    mem_request_data_o  = '0;

    for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
      request_vector = '0;
      for (lane_index = 0; lane_index < COLS; lane_index = lane_index + 1) begin
        request_vector[lane_index] =
            rowq_valid_q[row_index * COLS + lane_index];
      end

      row_pick[row_index] =
          rr_pick4(request_vector, row_rr_ptr_q[row_index]);
      if (row_pick[row_index][2]) begin
        selected_tile = {row_index[1:0], row_pick[row_index][1:0]};
        row_out_valid_o[row_index]  = 1'b1;
        row_out_data_o[row_index]   =
            rowq_data_q[selected_tile][DATA_W-1:0];
        row_out_source_o[row_index] = row_pick[row_index][1:0];
        if (row_out_ready_i[row_index]) begin
          rowq_pop[selected_tile] = 1'b1;
        end
      end
    end

    for (col_index = 0; col_index < COLS; col_index = col_index + 1) begin
      request_vector = '0;
      for (lane_index = 0; lane_index < ROWS; lane_index = lane_index + 1) begin
        request_vector[lane_index] =
            memq_valid_q[lane_index * COLS + col_index];
      end

      mem_pick[col_index] =
          rr_pick4(request_vector, mem_rr_ptr_q[col_index]);
      if (mem_pick[col_index][2]) begin
        selected_tile = {mem_pick[col_index][1:0], col_index[1:0]};
        memq_pop[selected_tile] = 1'b1;
        mem_request_valid_o[col_index] = 1'b1;
        mem_request_tile_o[col_index]  = selected_tile;
        mem_request_data_o[col_index]  = memq_data_q[selected_tile];
      end
    end
  end

  integer ptr_row;
  integer ptr_col;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (ptr_row = 0; ptr_row < ROWS; ptr_row = ptr_row + 1) begin
        row_rr_ptr_q[ptr_row] <= '0;
      end
      for (ptr_col = 0; ptr_col < COLS; ptr_col = ptr_col + 1) begin
        mem_rr_ptr_q[ptr_col] <= '0;
      end
    end else begin
      for (ptr_row = 0; ptr_row < ROWS; ptr_row = ptr_row + 1) begin
        if (row_out_valid_o[ptr_row] && row_out_ready_i[ptr_row]) begin
          row_rr_ptr_q[ptr_row] <= row_out_source_o[ptr_row] + 2'd1;
        end
      end

      for (ptr_col = 0; ptr_col < COLS; ptr_col = ptr_col + 1) begin
        if (mem_request_valid_o[ptr_col]) begin
          mem_rr_ptr_q[ptr_col] <= mem_pick[ptr_col][1:0] + 2'd1;
        end
      end
    end
  end

endmodule
