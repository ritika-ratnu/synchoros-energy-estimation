module tile_core (
  input  logic clk_i,
  input  logic rst_ni,

  // One global context address is normally broadcast to every PE in the array.
  input  logic [pkg::CTX_ADDR_W-1:0] context_addr_i,
  input  logic                                      execute_enable_i,
  input  logic                                      clear_outputs_i,

  // Per-PE configuration-memory programming port.
  input  logic                                      cfg_write_enable_i,
  input  logic [pkg::CTX_ADDR_W-1:0] cfg_write_addr_i,
  input  logic [pkg::TILE_CFG_W-1:0] cfg_write_data_i,

  // local_noc_adapter assigns the physical meaning of these ten links.
  input  logic [pkg::NUM_PORTS-1:0]
               [pkg::TOKEN_W-1:0] port_in_i,
  output logic [pkg::NUM_PORTS-1:0]
               [pkg::TOKEN_W-1:0] port_out_o,
  output logic [pkg::NUM_PORTS-1:0] port_out_enable_o,

  // Optional integration/debug visibility.
  output logic [pkg::TOKEN_W-1:0] alu_result_o,
  output logic [pkg::TOKEN_W-1:0] output_register_o
);

  import pkg::*;

  logic [TILE_CFG_W-1:0] config_word;
  tile_cfg_t              tile_config;

  token_t predicate_rf_data;
  token_t lhs_rf_data;
  token_t rhs_rf_data;

  token_t predicate_value;
  token_t lhs_value;
  token_t rhs_value;

  token_t alu_result;
  token_t output_data_q;
  logic [NUM_PORTS-1:0] output_enable_q;

  assign tile_config = config_word;

  config_mem #(
    .WORD_W (TILE_CFG_W),
    .DEPTH  (CONFIG_DEPTH),
    .ADDR_W (CTX_ADDR_W)
  ) u_config_mem (
    .clk_i          (clk_i),
    .write_enable_i (cfg_write_enable_i),
    .write_addr_i   (cfg_write_addr_i),
    .write_data_i   (cfg_write_data_i),
    .read_addr_i    (context_addr_i),
    .read_data_o    (config_word)
  );

  reg_file #(
    .DATA_W (TOKEN_W),
    .DEPTH  (RF_DEPTH),
    .ADDR_W (RF_ADDR_W)
  ) u_reg_file (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),
    .write_enable_i         (execute_enable_i && tile_config.rf_write_enable),
    .write_addr_i           (tile_config.rf_write_addr),
    .write_data_i           (alu_result),
    .predicate_read_addr_i  (tile_config.predicate_rf_addr),
    .lhs_read_addr_i        (tile_config.lhs_rf_addr),
    .rhs_read_addr_i        (tile_config.rhs_rf_addr),
    .predicate_read_data_o  (predicate_rf_data),
    .lhs_read_data_o        (lhs_rf_data),
    .rhs_read_data_o        (rhs_rf_data)
  );

  function automatic token_t select_source (
    input source_sel_t selector,
    input token_t      rf_data
  );
    begin
      case (selector)
        SRC_LINK_0:    select_source = port_in_i[0];
        SRC_LINK_1:    select_source = port_in_i[1];
        SRC_LINK_2:    select_source = port_in_i[2];
        SRC_LINK_3:    select_source = port_in_i[3];
        SRC_LINK_4:    select_source = port_in_i[4];
        SRC_LINK_5:    select_source = port_in_i[5];
        SRC_LINK_6:    select_source = port_in_i[6];
        SRC_LINK_7:    select_source = port_in_i[7];
        SRC_LINK_8:    select_source = port_in_i[8];
        SRC_LINK_9:    select_source = port_in_i[9];
        SRC_RF:        select_source = rf_data;
        SRC_OUT_REG:   select_source = output_data_q;
        SRC_IMMEDIATE: select_source = tile_config.immediate;
        SRC_ZERO:      select_source = '0;
        SRC_ONE:       select_source = {{(TOKEN_W-1){1'b0}}, 1'b1};
        default:       select_source = '0;
      endcase
    end
  endfunction

  always_comb begin
    predicate_value = select_source(tile_config.predicate_sel, predicate_rf_data);
    lhs_value       = select_source(tile_config.lhs_sel,       lhs_rf_data);
    rhs_value       = select_source(tile_config.rhs_sel,       rhs_rf_data);
  end

  // Figure mapping:
  //   P  -> op_predicate
  //   I1 -> op_LHS
  //   I2 -> op_RHS
  // op_SHIFT is not a fourth network mux here; it comes from configuration.
  simple_alu #(
    .width (DATA_W)
  ) u_alu (
    .op_predicate (predicate_value[DATA_W-1:0]),
    .op_LHS       (lhs_value),
    .op_RHS       (rhs_value),
    .op_SHIFT     (tile_config.immediate),
    .operation    (tile_config.operation),
    .result       (alu_result)
  );

  output_register #(
    .DATA_W    (TOKEN_W),
    .NUM_PORTS (NUM_PORTS)
  ) u_output_register (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .clear_enable_i (clear_outputs_i),
    .advance_i      (execute_enable_i),
    .write_enable_i (tile_config.out_write_enable),
    .write_data_i   (alu_result),
    .write_mask_i   (tile_config.out_enable_mask),
    .data_o         (output_data_q),
    .enable_mask_o  (output_enable_q)
  );

  // One registered ALU result is broadcast as data. The registered mask marks
  // which physical links are active for that result.
  generate
    for (genvar port_index = 0; port_index < NUM_PORTS; port_index++) begin : g_outputs
      assign port_out_o[port_index] = output_data_q;
    end
  endgenerate

  assign port_out_enable_o = output_enable_q;
  assign alu_result_o       = alu_result;
  assign output_register_o  = output_data_q;

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni && execute_enable_i) begin
      assert (tile_config.predicate_sel != SRC_RESERVED)
        else $error("Reserved predicate source in context %0d", context_addr_i);
      assert (tile_config.lhs_sel != SRC_RESERVED)
        else $error("Reserved LHS source in context %0d", context_addr_i);
      assert (tile_config.rhs_sel != SRC_RESERVED)
        else $error("Reserved RHS source in context %0d", context_addr_i);

      if (cfg_write_enable_i && (cfg_write_addr_i == context_addr_i)) begin
        $warning("Executing and rewriting context %0d on the same edge; read-during-write behavior is implementation-dependent", context_addr_i);
      end
    end
  end
`endif

endmodule
