package SMARTPkg;

  typedef struct packed {
    logic [32:0] data;
  } FlitFixed;

  // Direction encodings
  localparam int EAST  = 0;
  localparam int SOUTH = 1;
  localparam int WEST  = 2;
  localparam int NORTH = 3;
  localparam int LOCAL = 4;
  localparam int ALU_T = 5;
  localparam int TREG  = 5;
  localparam int NUM_INPUT_PORTS = 6;
  typedef logic [NUM_INPUT_PORTS-1:0] DirectionOneHot;

endpackage

