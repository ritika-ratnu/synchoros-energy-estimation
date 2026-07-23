package pkg;

  // Constants chosen to match the supplied figure and simple_alu interface.
  localparam int DATA_W        = 32;
  localparam int TOKEN_W       = 33;
  localparam int NUM_PORTS     = 10;
  localparam int RF_DEPTH      = 16;
  localparam int CONTEXT_DEPTH = 256;
  localparam int CONFIG_DEPTH  = 16 ;
  localparam int OP_W          = 6;

  localparam int RF_ADDR_W  = (RF_DEPTH <= 1) ? 1 : $clog2(RF_DEPTH);
  localparam int CTX_ADDR_W = (CONTEXT_DEPTH <= 1) ? 1 : $clog2(CONTEXT_DEPTH);
  localparam int SRC_SEL_W  = 4;

  typedef logic [TOKEN_W-1:0] token_t;
  typedef logic [RF_ADDR_W-1:0] rf_addr_t;
  typedef logic [SRC_SEL_W-1:0] source_sel_t;

  // Source-selector encoding for the three muxes shown in the figure:
  // predicate/P, LHS/I1, and RHS/I2.
  localparam source_sel_t SRC_LINK_0    = 4'd0;
  localparam source_sel_t SRC_LINK_1    = 4'd1;
  localparam source_sel_t SRC_LINK_2    = 4'd2;
  localparam source_sel_t SRC_LINK_3    = 4'd3;
  localparam source_sel_t SRC_LINK_4    = 4'd4;
  localparam source_sel_t SRC_LINK_5    = 4'd5;
  localparam source_sel_t SRC_LINK_6    = 4'd6;
  localparam source_sel_t SRC_LINK_7    = 4'd7;
  localparam source_sel_t SRC_LINK_8    = 4'd8;
  localparam source_sel_t SRC_LINK_9    = 4'd9;
  localparam source_sel_t SRC_RF        = 4'd10;
  localparam source_sel_t SRC_OUT_REG   = 4'd11;
  localparam source_sel_t SRC_IMMEDIATE = 4'd12;
  localparam source_sel_t SRC_ZERO      = 4'd13;
  localparam source_sel_t SRC_ONE       = 4'd14;
  localparam source_sel_t SRC_RESERVED  = 4'd15;

  // op_SHIFT is supplied directly from this configuration immediate. Inside
  // simple_alu, operation[5] chooses op_SHIFT instead of op_LHS as op_2.
  //
  // Packed bit layout, from MSB to LSB:
  //   [78:46] immediate
  //   [45:40] operation
  //   [39:36] predicate_sel
  //   [35:32] lhs_sel
  //   [31:28] rhs_sel
  //   [27:24] predicate_rf_addr
  //   [23:20] lhs_rf_addr
  //   [19:16] rhs_rf_addr
  //   [15:12] rf_write_addr
  //   [11]    rf_write_enable
  //   [10]    out_write_enable
  //   [9:0]   out_enable_mask
  typedef struct packed {
    token_t                 immediate;
    logic [OP_W-1:0]        operation;
    source_sel_t            predicate_sel;
    source_sel_t            lhs_sel;
    source_sel_t            rhs_sel;
    rf_addr_t               predicate_rf_addr;
    rf_addr_t               lhs_rf_addr;
    rf_addr_t               rhs_rf_addr;
    rf_addr_t               rf_write_addr;
    logic                   rf_write_enable;
    logic                   out_write_enable;
    logic [NUM_PORTS-1:0]   out_enable_mask;
  } tile_cfg_t;

  localparam int TILE_CFG_W = $bits(tile_cfg_t); // 79 bits

  // ALU operation constants from the supplied case statement.
  localparam logic [OP_W-1:0] OP_NOP    = 6'b000000;
  localparam logic [OP_W-1:0] OP_ADD    = 6'b000001;
  localparam logic [OP_W-1:0] OP_SUB    = 6'b000010;
  localparam logic [OP_W-1:0] OP_MUL    = 6'b000011;
  localparam logic [OP_W-1:0] OP_LSL    = 6'b001000;
  localparam logic [OP_W-1:0] OP_LSR    = 6'b001001;
  localparam logic [OP_W-1:0] OP_ASR    = 6'b001010;
  localparam logic [OP_W-1:0] OP_AND    = 6'b001011;
  localparam logic [OP_W-1:0] OP_OR     = 6'b001100;
  localparam logic [OP_W-1:0] OP_XOR    = 6'b001101;
  localparam logic [OP_W-1:0] OP_SELECT = 6'b010000;
  localparam logic [OP_W-1:0] OP_CMERGE = 6'b010001;
  localparam logic [OP_W-1:0] OP_CMP_EQ = 6'b010010;
  localparam logic [OP_W-1:0] OP_CMP_LT = 6'b010011;
  localparam logic [OP_W-1:0] OP_BRANCH = 6'b010100;
  localparam logic [OP_W-1:0] OP_CMP_GT = 6'b010101;
  localparam logic [OP_W-1:0] OP_MOV    = 6'b011111;

  // Setting operation[5] selects op_SHIFT. These are useful examples.
  localparam logic [OP_W-1:0] OP_ADDI   = 6'b100001;
  localparam logic [OP_W-1:0] OP_MOVI   = 6'b111111;

endpackage
