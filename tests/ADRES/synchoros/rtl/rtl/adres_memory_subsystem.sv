module adres_memory_subsystem #(
  parameter int ROWS = 4,
  parameter int COLS = 4,
  parameter int DMEM_WORDS_PER_BANK = 256,
  parameter int DMEM_ADDR_W =
      (DMEM_WORDS_PER_BANK <= 1) ? 1 : $clog2(DMEM_WORDS_PER_BANK)
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,
  input  logic                              run_i,
  input  logic                              execute_enable_i,
  input  logic                              mem_activity_i,
  input  logic [COLS-1:0]                   mem_request_valid_i,
  input  logic [COLS-1:0][3:0]              mem_request_tile_i,
  input  logic [COLS-1:0][pkg::TOKEN_W-1:0] mem_request_data_i,
  output logic [pkg::TOKEN_W-1:0]           mem_response_o [0:ROWS*COLS-1],
  output logic                              store_pending_any_o,
  input  logic                              dmem_host_valid_i,
  input  logic                              dmem_host_write_i,
  input  logic [1:0]                        dmem_host_bank_i,
  input  logic [DMEM_ADDR_W-1:0]            dmem_host_addr_i,
  input  logic [pkg::DATA_W-1:0]            dmem_host_wdata_i,
  output logic                              dmem_host_ready_o,
  output logic                              dmem_host_rvalid_o,
  output logic [pkg::DATA_W-1:0]            dmem_host_rdata_o
);

  import pkg::*;

  localparam int TILES = ROWS * COLS;

  logic [TILES-1:0] store_pending_q;
  logic [DMEM_ADDR_W-1:0] store_addr_q [0:TILES-1];

  logic dmem_host_fire;

  logic [COLS-1:0]                   dmem_bank_write_enable;
  logic [COLS-1:0][DMEM_ADDR_W-1:0] dmem_bank_addr;
  logic [COLS-1:0][DATA_W-1:0]      dmem_bank_wdata;
  logic [COLS-1:0][DATA_W-1:0]      dmem_bank_rdata;

  assign store_pending_any_o = |store_pending_q;

  assign dmem_host_ready_o = !run_i && !execute_enable_i &&
                             !mem_activity_i && !store_pending_any_o;
  assign dmem_host_fire = dmem_host_valid_i && dmem_host_ready_o;

  always_comb begin : p_dmem_bank_ports
    integer mem_col;
    logic [3:0] selected_tile;

    dmem_bank_write_enable = '0;
    dmem_bank_addr         = '0;
    dmem_bank_wdata        = '0;

    for (mem_col = 0; mem_col < COLS; mem_col = mem_col + 1) begin
      if (mem_request_valid_i[mem_col]) begin
        selected_tile = mem_request_tile_i[mem_col];

        if (store_pending_q[selected_tile]) begin
          dmem_bank_write_enable[mem_col] = 1'b1;
          dmem_bank_addr[mem_col] = store_addr_q[selected_tile];
          dmem_bank_wdata[mem_col] =
              mem_request_data_i[mem_col][DATA_W-1:0];
        end else begin
          dmem_bank_addr[mem_col] =
              mem_request_data_i[mem_col][DMEM_ADDR_W-1:0];
        end
      end
    end
  end

  adres_data_memory #(
    .BANKS          (COLS),
    .WORDS_PER_BANK (DMEM_WORDS_PER_BANK),
    .ADDR_W         (DMEM_ADDR_W),
    .DATA_W         (DATA_W)
  ) u_data_memory (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .bank_write_enable_i (dmem_bank_write_enable),
    .bank_addr_i         (dmem_bank_addr),
    .bank_wdata_i        (dmem_bank_wdata),
    .bank_rdata_o        (dmem_bank_rdata),
    .host_valid_i        (dmem_host_fire),
    .host_write_i        (dmem_host_write_i),
    .host_bank_i         (dmem_host_bank_i),
    .host_addr_i         (dmem_host_addr_i),
    .host_wdata_i        (dmem_host_wdata_i),
    .host_rvalid_o       (dmem_host_rvalid_o),
    .host_rdata_o        (dmem_host_rdata_o)
  );

  integer mem_col;
  integer mem_reset_tile;
  always_ff @(posedge clk_i or negedge rst_ni) begin : p_data_memory_protocol
    logic [3:0] selected_tile;

    if (!rst_ni) begin
      store_pending_q <= '0;

      for (mem_reset_tile = 0; mem_reset_tile < TILES;
           mem_reset_tile = mem_reset_tile + 1) begin
        store_addr_q[mem_reset_tile] <= '0;
        mem_response_o[mem_reset_tile] <= '0;
      end
    end else if (!dmem_host_fire) begin
      for (mem_col = 0; mem_col < COLS; mem_col = mem_col + 1) begin
        if (mem_request_valid_i[mem_col]) begin
          selected_tile = mem_request_tile_i[mem_col];

          if (store_pending_q[selected_tile]) begin
            store_pending_q[selected_tile] <= 1'b0;
            mem_response_o[selected_tile] <=
                {1'b1, {DATA_W{1'b0}}};
          end else if (mem_request_data_i[mem_col][DATA_W-1]) begin
            store_pending_q[selected_tile] <= 1'b1;
            store_addr_q[selected_tile] <=
                mem_request_data_i[mem_col][DMEM_ADDR_W-1:0];
            mem_response_o[selected_tile] <= '0;
          end else begin
            mem_response_o[selected_tile] <=
                {1'b1, dmem_bank_rdata[mem_col]};
          end
        end
      end
    end
  end

endmodule
