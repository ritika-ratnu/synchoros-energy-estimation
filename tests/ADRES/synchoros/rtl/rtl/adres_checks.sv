module adres_checks #(
  parameter int DMEM_WORDS_PER_BANK = 256,
  parameter int DMEM_ADDR_W =
      (DMEM_WORDS_PER_BANK <= 1) ? 1 : $clog2(DMEM_WORDS_PER_BANK)
) (
  input logic       clk_i,
  input logic       rst_ni,
  input logic       run_i,
  input logic       cfg_write_enable_i,
  input logic [3:0] cfg_tile_i,
  input logic       dmem_host_valid_i,
  input logic       dmem_host_ready_i
);

  import pkg::*;

`ifndef SYNTHESIS
  initial begin
    assert (NUM_PORTS == 10)
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

      if (dmem_host_valid_i && !dmem_host_ready_i && run_i) begin
        $warning("Host data-memory request ignored while ADRES is running");
      end
    end
  end
`endif

endmodule
