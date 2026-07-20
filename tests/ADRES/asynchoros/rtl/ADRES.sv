module ADRES #(
  parameter int DMEM_WORDS_PER_BANK = 1024,
  parameter int DMEM_ADDR_W =
      (DMEM_WORDS_PER_BANK <= 1) ? 1 : $clog2(DMEM_WORDS_PER_BANK),

  parameter bit FORCE_LINK_VALID = 1'b1
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  // Global control.
  input  logic                         run_i,
  input  logic                         set_context_i,
  input  logic [pkg::CTX_ADDR_W-1:0]  set_context_addr_i,
  input  logic                         clear_outputs_i,
  output logic                         execute_enable_o,
  output logic [pkg::CTX_ADDR_W-1:0]  context_addr_o,
  output logic                         stall_o,
  output logic                         array_idle_o,

  // Tile configuration.
  input  logic                         cfg_write_enable_i,
  input  logic [3:0]                   cfg_tile_i,
  input  logic [pkg::CTX_ADDR_W-1:0]  cfg_write_addr_i,
  input  logic [pkg::TILE_CFG_W-1:0]  cfg_write_data_i,

  // Row instream with global valid.
  input  logic [3:0]                   row_in_valid_i,
  input  logic [3:0][31:0]             row_in_data_i,
  output logic [3:0]                   row_in_ready_o,

  // Row outstream.
  output logic [3:0]                   row_out_valid_o,
  output logic [3:0][31:0]             row_out_data_o,
  output logic [3:0][1:0]              row_out_source_o,
  input  logic [3:0]                   row_out_ready_i,

  //Debug ports for four data-memory banks.
  input  logic                         dmem_host_valid_i,
  input  logic                         dmem_host_write_i,
  input  logic [1:0]                   dmem_host_bank_i,
  input  logic [DMEM_ADDR_W-1:0]       dmem_host_addr_i,
  input  logic [31:0]                  dmem_host_wdata_i,
  output logic                         dmem_host_ready_o,
  output logic                         dmem_host_rvalid_o,
  output logic [31:0]                  dmem_host_rdata_o
);

  import pkg::*;

  localparam int ROWS       = 4;
  localparam int COLS       = 4;
  localparam int TILES      = ROWS * COLS;
  localparam int NOC_PORTS  = 10;
  localparam int TILE_ID_W  = 4;

  localparam int PORT_ROW_C0 = 0;
  localparam int PORT_ROW_C1 = 1;
  localparam int PORT_ROW_C2 = 2;
  localparam int PORT_ROW_C3 = 3;
  localparam int PORT_ROW_EP = 4;
  localparam int PORT_COL_R0 = 5;
  localparam int PORT_COL_R1 = 6;
  localparam int PORT_COL_R2 = 7;
  localparam int PORT_COL_R3 = 8;
  localparam int PORT_MEM_EP = 9;

  typedef logic [1:0] row_col_t;

  // Tile ports and NoC 
  logic [NOC_PORTS-1:0][TOKEN_W-1:0] tile_port_in [0:ROWS-1][0:COLS-1];
  logic [NOC_PORTS-1:0][TOKEN_W-1:0] tile_port_out_unused [0:ROWS-1][0:COLS-1];
  token_t                            tile_result [0:TILES-1];
  token_t                            tile_alu_result_unused [0:TILES-1];
  logic [NOC_PORTS-1:0] tile_route_mask [0:TILES-1];

  // Row queue for output from tile to row's exeternal output.
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

  // Round-robin state.  Each row arbitrates four row-output queues; each column
  // arbitrates the four memory queues belonging to that column.
  row_col_t row_rr_ptr_q [0:ROWS-1];
  row_col_t mem_rr_ptr_q [0:COLS-1];
  logic [2:0] row_pick [0:ROWS-1]; // {valid, winning column[1:0]}
  logic [2:0] mem_pick [0:COLS-1]; // {valid, winning row[1:0]}

  // Four physically independent data-memory banks, one beneath each column.
  logic [DATA_W-1:0] dmem [0:COLS-1][0:DMEM_WORDS_PER_BANK-1];

  // Per-tile protocol state and persistent response mailbox.
  logic [TILES-1:0] store_pending_q;
  logic [DMEM_ADDR_W-1:0] store_addr_q [0:TILES-1];
  token_t mem_response_q [0:TILES-1];

  logic endpoint_stall;
  logic dmem_engine_idle;
  logic dmem_host_fire;

  // ---------------------------------------------------------------------------
  // Small helper functions
  // ---------------------------------------------------------------------------

  function automatic token_t make_link_token(input token_t value);
    begin
      make_link_token = value;
      if (FORCE_LINK_VALID) begin
        make_link_token[TOKEN_W-1] = 1'b1;
      end
    end
  endfunction

  // Four-way round-robin selector.  Return value is {found, index[1:0]}.
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
          found          = 1'b1;
        end
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Global controller
  // ---------------------------------------------------------------------------

  global_controller #(
    .DEPTH  (CONTEXT_DEPTH),
    .ADDR_W (CTX_ADDR_W)
  ) u_context_controller (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .run_i              (run_i),
    .stall_i            (endpoint_stall),
    .set_context_i      (set_context_i),
    .set_context_addr_i (set_context_addr_i),
    .execute_enable_o   (execute_enable_o),
    .context_addr_o     (context_addr_o)
  );

  assign stall_o        = endpoint_stall;
  assign row_in_ready_o = {ROWS{execute_enable_o}};

  // ---------------------------------------------------------------------------
  // Tile array and configuration-write decode
  // ---------------------------------------------------------------------------

  generate
    for (genvar row = 0; row < ROWS; row = row + 1) begin : g_row
      for (genvar col = 0; col < COLS; col = col + 1) begin : g_col
        localparam int TILE_ID = row * COLS + col;
        localparam logic [TILE_ID_W-1:0] TILE_ID_VALUE = TILE_ID;

        tile u_tile (
          .clk_i               (clk_i),
          .rst_ni              (rst_ni),
          .context_addr_i      (context_addr_o),
          .execute_enable_i    (execute_enable_o),
          .clear_outputs_i     (clear_outputs_i),
          .cfg_write_enable_i  (cfg_write_enable_i &&
                                (cfg_tile_i == TILE_ID_VALUE)),
          .cfg_write_addr_i    (cfg_write_addr_i),
          .cfg_write_data_i    (cfg_write_data_i),
          .port_in_i           (tile_port_in[row][col]),
          .port_out_o          (tile_port_out_unused[row][col]),
          .port_out_enable_o   (tile_route_mask[TILE_ID]),
          .alu_result_o        (tile_alu_result_unused[TILE_ID]),
          .output_register_o   (tile_result[TILE_ID])
        );
      end
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // Network
  // ---------------------------------------------------------------------------

  integer noc_row;
  integer noc_col;
  integer noc_src;
  integer noc_dst;
  integer noc_tile_id;

  always_comb begin
    for (noc_row = 0; noc_row < ROWS; noc_row = noc_row + 1) begin
      for (noc_col = 0; noc_col < COLS; noc_col = noc_col + 1) begin
        tile_port_in[noc_row][noc_col] = '0;

        if (row_in_valid_i[noc_row]) begin
          tile_port_in[noc_row][noc_col][PORT_ROW_EP] =
              {1'b1, row_in_data_i[noc_row]};
        end

        noc_tile_id = noc_row * COLS + noc_col;
        tile_port_in[noc_row][noc_col][PORT_MEM_EP] =
            mem_response_q[noc_tile_id];
      end
    end

    // Row network
    for (noc_row = 0; noc_row < ROWS; noc_row = noc_row + 1) begin
      for (noc_src = 0; noc_src < COLS; noc_src = noc_src + 1) begin
        for (noc_dst = 0; noc_dst < COLS; noc_dst = noc_dst + 1) begin
          if (tile_route_mask[noc_row * COLS + noc_src][noc_dst]) begin
            tile_port_in[noc_row][noc_dst][noc_src] =
                make_link_token(tile_result[noc_row * COLS + noc_src]);
          end
        end
      end
    end

    // Column network
    for (noc_col = 0; noc_col < COLS; noc_col = noc_col + 1) begin
      for (noc_src = 0; noc_src < ROWS; noc_src = noc_src + 1) begin
        for (noc_dst = 0; noc_dst < ROWS; noc_dst = noc_dst + 1) begin
          if (tile_route_mask[noc_src * COLS + noc_col]
                             [PORT_COL_R0 + noc_dst]) begin
            tile_port_in[noc_dst][noc_col][PORT_COL_R0 + noc_src] =
                make_link_token(tile_result[noc_src * COLS + noc_col]);
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Global backpressure
  // ---------------------------------------------------------------------------

  assign rowq_can_accept = ~rowq_valid_q | rowq_pop;
  assign memq_can_accept = ~memq_valid_q | memq_pop;

  generate
    for (genvar tile_index = 0; tile_index < TILES;
         tile_index = tile_index + 1) begin : g_endpoint_need
      assign row_route_need[tile_index] =
          !row_route_consumed_q[tile_index] &&
          tile_route_mask[tile_index][PORT_ROW_EP] &&
          !clear_outputs_i;

      assign mem_route_need[tile_index] =
          !mem_route_consumed_q[tile_index] &&
          tile_route_mask[tile_index][PORT_MEM_EP] &&
          !clear_outputs_i;
    end
  endgenerate

  assign rowq_push = row_route_need & rowq_can_accept;
  assign memq_push = mem_route_need & memq_can_accept;

  assign endpoint_stall =
      (|(row_route_need & ~rowq_can_accept)) |
      (|(mem_route_need & ~memq_can_accept));

  // A route is marked consumed once it enters its endpoint queue.  Executing a
  // new context clears the markers for the newly produced output epoch.  This
  // also lets the final output of a stopped array drain exactly once.
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
        if (execute_enable_o) begin
          // The tile output register changes after this edge.  The old output
          // may be queued on this same edge; the zero applies to the new epoch.
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

  // Queue storage supports pop-and-replace in one cycle.
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
            rowq_data_q[queue_index]  <= tile_result[queue_index];
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
            memq_data_q[queue_index]  <= tile_result[queue_index];
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

  // ---------------------------------------------------------------------------
  // Round-robin selection for row egress and column memory banks
  // ---------------------------------------------------------------------------

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
      end
    end
  end

  // Round-robin pointers advance after a successful dequeue.
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
        if (mem_pick[ptr_col][2]) begin
          mem_rr_ptr_q[ptr_col] <= mem_pick[ptr_col][1:0] + 2'd1;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Column-banked data memory and serialized LSU protocol
  // ---------------------------------------------------------------------------

  assign dmem_engine_idle = !(|memq_valid_q) && !(|store_pending_q) &&
                            !(|mem_route_need);

  assign dmem_host_ready_o = !run_i && !execute_enable_o && dmem_engine_idle;
  assign dmem_host_fire    = dmem_host_valid_i && dmem_host_ready_o;

  // Full-array idle additionally waits for row egress queues and final endpoint
  // copies.  Memory-response mailboxes do not count as activity because they are
  // architectural state, like registers.
  assign array_idle_o = !run_i && !execute_enable_o &&
                        !(|rowq_valid_q) && !(|memq_valid_q) &&
                        !(|store_pending_q) &&
                        !(|row_route_need) && !(|mem_route_need);

  integer mem_col;
  integer mem_reset_tile;
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_data_memory
    logic [TILE_ID_W-1:0] selected_tile;

    if (!rst_ni) begin
      store_pending_q    <= '0;
      dmem_host_rvalid_o <= 1'b0;
      dmem_host_rdata_o  <= '0;

      for (mem_reset_tile = 0; mem_reset_tile < TILES;
           mem_reset_tile = mem_reset_tile + 1) begin
        store_addr_q[mem_reset_tile]   <= '0;
        mem_response_q[mem_reset_tile] <= '0;
      end
    end else begin
      dmem_host_rvalid_o <= 1'b0;

      if (dmem_host_fire) begin
        if (dmem_host_write_i) begin
          dmem[dmem_host_bank_i][dmem_host_addr_i] <= dmem_host_wdata_i;
        end else begin
          dmem_host_rdata_o  <= dmem[dmem_host_bank_i][dmem_host_addr_i];
          dmem_host_rvalid_o <= 1'b1;
        end
      end else begin
        for (mem_col = 0; mem_col < COLS; mem_col = mem_col + 1) begin
          if (mem_pick[mem_col][2]) begin
            selected_tile = {mem_pick[mem_col][1:0], mem_col[1:0]};

            if (store_pending_q[selected_tile]) begin
              // Second flit of a write sequence.
              dmem[mem_col][store_addr_q[selected_tile]] <=
                  memq_data_q[selected_tile][DATA_W-1:0];
              store_pending_q[selected_tile] <= 1'b0;
              mem_response_q[selected_tile]  <=
                  {1'b1, {DATA_W{1'b0}}};
            end else if (memq_data_q[selected_tile][DATA_W-1]) begin
              // First flit of a write sequence.  payload[31] is the write flag.
              store_pending_q[selected_tile] <= 1'b1;
              store_addr_q[selected_tile] <=
                  memq_data_q[selected_tile][DMEM_ADDR_W-1:0];
              mem_response_q[selected_tile] <= '0;
            end else begin
              // Single-flit read request.  The response mailbox is persistent.
              mem_response_q[selected_tile] <=
                  {1'b1,
                   dmem[mem_col]
                       [memq_data_q[selected_tile][DMEM_ADDR_W-1:0]]};
            end
          end
        end
      end
    end
  end

`ifndef SYNTHESIS
  // Elaboration and protocol-oriented checks.  The supplied package must use
  // NUM_PORTS=10; otherwise the tile's SRC_LINK_5..9 selectors and route mask do
  // not match the architecture described above.
  initial begin
    assert (NUM_PORTS == NOC_PORTS)
      else $fatal(1,
                  "ADRES requires pkg::NUM_PORTS=10; current value is %0d",
                  NUM_PORTS);
    assert (TILE_CFG_W == 79)
      else $fatal(1,
                  "ADRES expects the 79-bit ten-port tile configuration; got %0d",
                  TILE_CFG_W);
    assert (DMEM_WORDS_PER_BANK > 0)
      else $fatal(1, "DMEM_WORDS_PER_BANK must be positive");
    assert (DMEM_ADDR_W <= 31)
      else $fatal(1,
                  "Memory address must leave payload bit 31 for the write flag");
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      if (cfg_write_enable_i && run_i) begin
        $warning("Reprogramming tile %0d while the array is running", cfg_tile_i);
      end

      if (dmem_host_valid_i && !dmem_host_ready_o && run_i) begin
        $warning("Host data-memory request ignored while ADRES is running");
      end
    end
  end
`endif

endmodule

`default_nettype wire
