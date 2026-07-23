module adres_data_memory #(
  parameter int BANKS = 4,
  parameter int WORDS_PER_BANK = 256,
  parameter int ADDR_W =
      (WORDS_PER_BANK <= 1) ? 1 : $clog2(WORDS_PER_BANK),
  parameter int DATA_W = 32,
  parameter int BANK_W = (BANKS <= 1) ? 1 : $clog2(BANKS)
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,

  // One independent array-side port per bank. Reads are asynchronous;
  // writes occur on the rising edge when bank_write_enable_i is asserted.
  input  logic [BANKS-1:0]                  bank_write_enable_i,
  input  logic [BANKS-1:0][ADDR_W-1:0]      bank_addr_i,
  input  logic [BANKS-1:0][DATA_W-1:0]      bank_wdata_i,
  output logic [BANKS-1:0][DATA_W-1:0]      bank_rdata_o,

  // Serialized host/debug port. host_valid_i is an acceptance pulse from the
  // parent, so no separate ready signal is required inside this IP.
  input  logic                              host_valid_i,
  input  logic                              host_write_i,
  input  logic [BANK_W-1:0]                 host_bank_i,
  input  logic [ADDR_W-1:0]                 host_addr_i,
  input  logic [DATA_W-1:0]                 host_wdata_i,
  output logic                              host_rvalid_o,
  output logic [DATA_W-1:0]                 host_rdata_o
);


endmodule
