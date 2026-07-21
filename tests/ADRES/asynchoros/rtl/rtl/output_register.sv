module output_register #(
  parameter int DATA_W    = 33,
  parameter int NUM_PORTS = 10
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,

  input  logic                     clear_enable_i,
  input  logic                     advance_i,
  input  logic                     write_enable_i,
  input  logic [DATA_W-1:0]        write_data_i,
  input  logic [NUM_PORTS-1:0]     write_mask_i,

  output logic [DATA_W-1:0]        data_o,
  output logic [NUM_PORTS-1:0]     enable_mask_o
);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_o        <= '0;
      enable_mask_o <= '0;
    end else if (clear_enable_i) begin
      // Retain data for optional local feedback, but disable every route.
      enable_mask_o <= '0;
    end else if (advance_i) begin
      if (write_enable_i) begin
        data_o        <= write_data_i;
        enable_mask_o <= write_mask_i;
      end else begin
        // This context emits no network value. Retaining data still permits
        // SRC_OUT_REG to use the previous result as local feedback.
        enable_mask_o <= '0;
      end
    end
  end

endmodule
