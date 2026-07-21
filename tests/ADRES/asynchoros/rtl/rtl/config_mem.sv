module config_mem #(
  parameter int WORD_W = 79,
  parameter int DEPTH  = 16,
  parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                  clk_i,

  input  logic                  write_enable_i,
  input  logic [ADDR_W-1:0]     write_addr_i,
  input  logic [WORD_W-1:0]     write_data_i,

  input  logic [ADDR_W-1:0]     read_addr_i,
  output logic [WORD_W-1:0]     read_data_o
);

//  logic [WORD_W-1:0] mem [0:DEPTH-1];
//
//  // Configuration is intentionally not reset. Program every context that can
//  // execute before asserting execute_enable_i at the tile level.
//  always_ff @(posedge clk_i) begin
//    if (write_enable_i && (int'(write_addr_i) < DEPTH)) begin
//      mem[write_addr_i] <= write_data_i;
//    end
//  end
//
//  // Asynchronous context read supports one configuration per execute cycle.
//  // A synchronous SRAM implementation requires a fetch/prefetch stage.
//  always_comb begin
//    if (int'(read_addr_i) < DEPTH) begin
//      read_data_o = mem[read_addr_i];
//    end else begin
//      read_data_o = '0;
//    end
//  end
//
//`ifndef SYNTHESIS
//  always_ff @(posedge clk_i) begin
//    if (write_enable_i) begin
//      assert (int'(write_addr_i) < DEPTH)
//        else $error("Configuration address %0d is outside depth %0d",
//                    write_addr_i, DEPTH);
//    end
//  end
//`endif

endmodule
