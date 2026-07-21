// Self-checking testbench for ADRES.
//
// Covered behaviors:
//   - reset and idle status
//   - host reads/writes to all four data-memory banks
//   - context load, execute enable, and context advancement
//   - row input -> tile -> row output datapath
//   - row-output ready/valid backpressure
//   - two-tile round-robin row arbitration
//   - global endpoint stall and queue pop-and-replace
//
// Example (Icarus Verilog):
//   iverilog -g2012 -s tb_ADRES -o simv \
//     pkg.sv config_mem.sv reg_file.sv output_register.sv simple_alu.sv \
//     tile.sv global_controller.sv ADRES.sv tb_ADRES.sv
//   vvp simv

`default_nettype none

module tb;
  import pkg::*;

  localparam int DMEM_WORDS_PER_BANK = 16;
  localparam int DMEM_ADDR_W = $clog2(DMEM_WORDS_PER_BANK);
  localparam time CLK_PERIOD = 10ns;

  localparam int PORT_ROW_EP = 4;

  logic                       clk_i;
  logic                       rst_ni;

  logic                       run_i;
  logic                       set_context_i;
  logic [CTX_ADDR_W-1:0]      set_context_addr_i;
  logic                       clear_outputs_i;
  logic                       execute_enable_o;
  logic [CTX_ADDR_W-1:0]      context_addr_o;
  logic                       stall_o;
  logic                       array_idle_o;

  logic                       cfg_write_enable_i;
  logic [3:0]                 cfg_tile_i;
  logic [CTX_ADDR_W-1:0]      cfg_write_addr_i;
  logic [TILE_CFG_W-1:0]      cfg_write_data_i;

  logic [3:0]                 row_in_valid_i;
  logic [3:0][31:0]           row_in_data_i;
  logic [3:0]                 row_in_ready_o;

  logic [3:0]                 row_out_valid_o;
  logic [3:0][31:0]           row_out_data_o;
  logic [3:0][1:0]            row_out_source_o;
  logic [3:0]                 row_out_ready_i;

  logic                       dmem_host_valid_i;
  logic                       dmem_host_write_i;
  logic [1:0]                 dmem_host_bank_i;
  logic [DMEM_ADDR_W-1:0]     dmem_host_addr_i;
  logic [31:0]                dmem_host_wdata_i;
  logic                       dmem_host_ready_o;
  logic                       dmem_host_rvalid_o;
  logic [31:0]                dmem_host_rdata_o;

  int unsigned error_count;

  ADRES #(
    .DMEM_WORDS_PER_BANK (DMEM_WORDS_PER_BANK),
    .DMEM_ADDR_W         (DMEM_ADDR_W),
    .FORCE_LINK_VALID    (1'b1)
  ) dut (
    .clk_i,
    .rst_ni,
    .run_i,
    .set_context_i,
    .set_context_addr_i,
    .clear_outputs_i,
    .execute_enable_o,
    .context_addr_o,
    .stall_o,
    .array_idle_o,
    .cfg_write_enable_i,
    .cfg_tile_i,
    .cfg_write_addr_i,
    .cfg_write_data_i,
    .row_in_valid_i,
    .row_in_data_i,
    .row_in_ready_o,
    .row_out_valid_o,
    .row_out_data_o,
    .row_out_source_o,
    .row_out_ready_i,
    .dmem_host_valid_i,
    .dmem_host_write_i,
    .dmem_host_bank_i,
    .dmem_host_addr_i,
    .dmem_host_wdata_i,
    .dmem_host_ready_o,
    .dmem_host_rvalid_o,
    .dmem_host_rdata_o
  );

  initial clk_i = 1'b0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  function automatic logic [TILE_CFG_W-1:0] make_cfg(
    input token_t                 immediate,
    input logic [OP_W-1:0]        operation,
    input source_sel_t            predicate_sel,
    input source_sel_t            lhs_sel,
    input source_sel_t            rhs_sel,
    input logic                   rf_write_enable,
    input rf_addr_t               rf_write_addr,
    input logic                   out_write_enable,
    input logic [NUM_PORTS-1:0]   out_enable_mask
  );
    tile_cfg_t cfg;
    begin
      cfg = '0;
      cfg.immediate         = immediate;
      cfg.operation         = operation;
      cfg.predicate_sel     = predicate_sel;
      cfg.lhs_sel           = lhs_sel;
      cfg.rhs_sel           = rhs_sel;
      cfg.predicate_rf_addr = '0;
      cfg.lhs_rf_addr       = '0;
      cfg.rhs_rf_addr       = '0;
      cfg.rf_write_addr     = rf_write_addr;
      cfg.rf_write_enable   = rf_write_enable;
      cfg.out_write_enable  = out_write_enable;
      cfg.out_enable_mask   = out_enable_mask;
      make_cfg              = cfg;
    end
  endfunction

  function automatic logic [TILE_CFG_W-1:0] cfg_nop();
    begin
      cfg_nop = make_cfg(
        '0,
        OP_NOP,
        SRC_ZERO,
        SRC_ZERO,
        SRC_ZERO,
        1'b0,
        '0,
        1'b0,
        '0
      );
    end
  endfunction

  function automatic logic [TILE_CFG_W-1:0] cfg_immediate_to_row(
    input logic [31:0] value
  );
    logic [NUM_PORTS-1:0] route_mask;
    begin
      route_mask = '0;
      route_mask[PORT_ROW_EP] = 1'b1;
      cfg_immediate_to_row = make_cfg(
        {1'b1, value},
        OP_MOVI,
        SRC_ZERO,
        SRC_ZERO,
        SRC_ZERO,
        1'b0,
        '0,
        1'b1,
        route_mask
      );
    end
  endfunction

  function automatic logic [TILE_CFG_W-1:0] cfg_row_input_to_row();
    logic [NUM_PORTS-1:0] route_mask;
    begin
      route_mask = '0;
      route_mask[PORT_ROW_EP] = 1'b1;
      cfg_row_input_to_row = make_cfg(
        '0,
        OP_MOV,
        SRC_ZERO,
        SRC_LINK_4,
        SRC_ZERO,
        1'b0,
        '0,
        1'b1,
        route_mask
      );
    end
  endfunction

  task automatic check_true(
    input logic condition,
    input string message
  );
    begin
      if (condition !== 1'b1) begin
        error_count++;
        $error("CHECK FAILED: %s", message);
      end
    end
  endtask

  task automatic check_equal32(
    input logic [31:0] actual,
    input logic [31:0] expected,
    input string message
  );
    begin
      if (actual !== expected) begin
        error_count++;
        $error("CHECK FAILED: %s. expected=0x%08h actual=0x%08h",
               message, expected, actual);
      end
    end
  endtask

  task automatic initialize_inputs();
    begin
      run_i                = 1'b0;
      set_context_i        = 1'b0;
      set_context_addr_i   = '0;
      clear_outputs_i      = 1'b0;

      cfg_write_enable_i   = 1'b0;
      cfg_tile_i           = '0;
      cfg_write_addr_i     = '0;
      cfg_write_data_i     = '0;

      row_in_valid_i       = '0;
      row_in_data_i        = '0;
      row_out_ready_i      = '0;

      dmem_host_valid_i    = 1'b0;
      dmem_host_write_i    = 1'b0;
      dmem_host_bank_i     = '0;
      dmem_host_addr_i     = '0;
      dmem_host_wdata_i    = '0;
    end
  endtask

  task automatic reset_dut();
    begin
      initialize_inputs();
      rst_ni = 1'b0;
      repeat (3) @(posedge clk_i);
      @(negedge clk_i);
      rst_ni = 1'b1;
      @(posedge clk_i);
      #1ns;

      check_true(execute_enable_o === 1'b0,
                 "execute_enable_o must be low after reset");
      check_true(context_addr_o === '0,
                 "context address must reset to zero");
      check_true(stall_o === 1'b0,
                 "stall_o must be low after reset");
      check_true(array_idle_o === 1'b1,
                 "array must be idle after reset");
    end
  endtask

  task automatic write_cfg(
    input int unsigned tile,
    input int unsigned context_idx,
    input logic [TILE_CFG_W-1:0] cfg
  );
    begin
      @(negedge clk_i);
      cfg_tile_i         = tile[3:0];
      cfg_write_addr_i   = context_idx[CTX_ADDR_W-1:0];
      cfg_write_data_i   = cfg;
      cfg_write_enable_i = 1'b1;

      @(posedge clk_i);
      #1ns;

      @(negedge clk_i);
      cfg_write_enable_i = 1'b0;
    end
  endtask

  task automatic program_nop_context(input int unsigned context_idx);
    begin
      for (int unsigned tile = 0; tile < 16; tile++) begin
        write_cfg(tile, context_idx, cfg_nop());
      end
    end
  endtask

  task automatic set_context(input int unsigned context_idx);
    begin
      @(negedge clk_i);
      set_context_addr_i = context_idx[CTX_ADDR_W-1:0];
      set_context_i      = 1'b1;

      @(posedge clk_i);
      #1ns;
      check_true(context_addr_o === context_idx[CTX_ADDR_W-1:0],
                 $sformatf("context address must load %0d", context_idx));
      check_true(execute_enable_o === 1'b0,
                 "set_context_i must suppress execution");

      @(negedge clk_i);
      set_context_i = 1'b0;
    end
  endtask

  task automatic pulse_run_one_cycle(
    input logic [3:0]       input_valid,
    input logic [3:0][31:0] input_data
  );
    begin
      @(negedge clk_i);
      row_in_valid_i = input_valid;
      row_in_data_i  = input_data;
      run_i          = 1'b1;
      #1ns;
      check_true(execute_enable_o === 1'b1,
                 "run_i must enable execution when the array is not stalled");
      check_true(row_in_ready_o === 4'hf,
                 "all row inputs must be ready during execution");

      @(posedge clk_i);
      #1ns;

      @(negedge clk_i);
      run_i          = 1'b0;
      row_in_valid_i = '0;
      row_in_data_i  = '0;
    end
  endtask

  task automatic wait_for_row_output(
    input int unsigned row,
    input int unsigned expected_source,
    input logic [31:0] expected_data
  );
    int unsigned cycles;
    begin
      cycles = 0;
      while ((row_out_valid_o[row] !== 1'b1) && (cycles < 20)) begin
        @(posedge clk_i);
        #1ns;
        cycles++;
      end

      check_true(row_out_valid_o[row] === 1'b1,
                 $sformatf("row %0d output timed out", row));
      check_true(row_out_source_o[row] === expected_source[1:0],
                 $sformatf("row %0d source must be tile column %0d",
                           row, expected_source));
      check_equal32(row_out_data_o[row], expected_data,
                    $sformatf("row %0d output data mismatch", row));
    end
  endtask

  task automatic consume_row_output(input int unsigned row);
    begin
      @(negedge clk_i);
      row_out_ready_i[row] = 1'b1;
      @(posedge clk_i);
      #1ns;
      row_out_ready_i[row] = 1'b0;
    end
  endtask

  task automatic host_write(
    input int unsigned bank,
    input int unsigned address,
    input logic [31:0] data
  );
    int unsigned cycles;
    begin
      cycles = 0;
      while ((dmem_host_ready_o !== 1'b1) && (cycles < 20)) begin
        @(posedge clk_i);
        #1ns;
        cycles++;
      end
      check_true(dmem_host_ready_o === 1'b1,
                 "host memory write timed out waiting for ready");

      @(negedge clk_i);
      dmem_host_bank_i  = bank[1:0];
      dmem_host_addr_i  = address[DMEM_ADDR_W-1:0];
      dmem_host_wdata_i = data;
      dmem_host_write_i = 1'b1;
      dmem_host_valid_i = 1'b1;

      @(posedge clk_i);
      #1ns;

      @(negedge clk_i);
      dmem_host_valid_i = 1'b0;
      dmem_host_write_i = 1'b0;
    end
  endtask

  task automatic host_read_check(
    input int unsigned bank,
    input int unsigned address,
    input logic [31:0] expected_data
  );
    int unsigned cycles;
    begin
      cycles = 0;
      while ((dmem_host_ready_o !== 1'b1) && (cycles < 20)) begin
        @(posedge clk_i);
        #1ns;
        cycles++;
      end
      check_true(dmem_host_ready_o === 1'b1,
                 "host memory read timed out waiting for ready");

      @(negedge clk_i);
      dmem_host_bank_i  = bank[1:0];
      dmem_host_addr_i  = address[DMEM_ADDR_W-1:0];
      dmem_host_write_i = 1'b0;
      dmem_host_valid_i = 1'b1;

      @(posedge clk_i);
      #1ns;
      check_true(dmem_host_rvalid_o === 1'b1,
                 "host memory read must assert rvalid");
      check_equal32(dmem_host_rdata_o, expected_data,
                    $sformatf("host memory bank %0d address %0d mismatch",
                              bank, address));

      @(negedge clk_i);
      dmem_host_valid_i = 1'b0;
    end
  endtask

  task automatic test_host_memory();
    begin
      $display("[TEST] Host access to all four data-memory banks");
      for (int unsigned bank = 0; bank < 4; bank++) begin
        host_write(bank, bank + 1, 32'h1000_0000 + bank);
      end
      for (int unsigned bank = 0; bank < 4; bank++) begin
        host_read_check(bank, bank + 1, 32'h1000_0000 + bank);
      end
    end
  endtask

  task automatic test_context_control();
    begin
      $display("[TEST] Context load and one-cycle execution");
      program_nop_context(5);
      set_context(5);
      pulse_run_one_cycle('0, '0);
      check_true(context_addr_o === 4'd6,
                 "one successful execution must advance the context");
      check_true(execute_enable_o === 1'b0,
                 "execution must stop after run_i is deasserted");
    end
  endtask

  task automatic test_row_input_path();
    logic [3:0][31:0] input_data;
    begin
      $display("[TEST] Row input through tile 0 to row 0 output");
      program_nop_context(0);
      write_cfg(0, 0, cfg_row_input_to_row());
      set_context(0);

      input_data = '0;
      input_data[0] = 32'hCAFE_BABE;
      pulse_run_one_cycle(4'b0001, input_data);

      wait_for_row_output(0, 0, 32'hCAFE_BABE);

      // Verify standard ready/valid backpressure: data must remain stable while
      // the sink is not ready.
      repeat (2) begin
        @(posedge clk_i);
        #1ns;
        check_true(row_out_valid_o[0] === 1'b1,
                   "row output valid must remain asserted under backpressure");
        check_equal32(row_out_data_o[0], 32'hCAFE_BABE,
                      "row output data must remain stable under backpressure");
      end

      consume_row_output(0);
      @(posedge clk_i);
      #1ns;
      check_true(row_out_valid_o[0] === 1'b0,
                 "row output must clear after the handshake");
      check_true(array_idle_o === 1'b1,
                 "array must return idle after the output drains");
    end
  endtask

  task automatic test_row_arbitration();
    begin
      $display("[TEST] Round-robin arbitration between two tiles in row 0");
      program_nop_context(1);
      write_cfg(0, 1, cfg_immediate_to_row(32'd11));
      write_cfg(1, 1, cfg_immediate_to_row(32'd22));
      set_context(1);
      pulse_run_one_cycle('0, '0);

      wait_for_row_output(0, 0, 32'd11);
      consume_row_output(0);

      wait_for_row_output(0, 1, 32'd22);
      consume_row_output(0);

      @(posedge clk_i);
      #1ns;
      check_true(row_out_valid_o[0] === 1'b0,
                 "both row arbitration entries must drain");
      check_true(array_idle_o === 1'b1,
                 "array must be idle after arbitration outputs drain");
    end
  endtask

  task automatic test_global_stall();
    logic [CTX_ADDR_W-1:0] held_context;
    begin
      $display("[TEST] Global stall and pop-and-replace endpoint queue");
      program_nop_context(2);
      program_nop_context(3);
      write_cfg(0, 2, cfg_immediate_to_row(32'd100));
      write_cfg(0, 3, cfg_immediate_to_row(32'd200));
      set_context(2);

      @(negedge clk_i);
      run_i = 1'b1;

      // Context 2 executes here.
      @(posedge clk_i);
      #1ns;
      check_true(context_addr_o === 4'd3,
                 "context 2 execution must advance to context 3");
      check_true(stall_o === 1'b0,
                 "first pending row output must fit in an empty queue");

      // Context 3 executes while context 2 enters the one-entry row queue.
      @(posedge clk_i);
      #1ns;
      check_true(context_addr_o === 4'd4,
                 "context 3 execution must advance to context 4");
      check_true(stall_o === 1'b1,
                 "second row output must stall behind a full endpoint queue");
      check_true(execute_enable_o === 1'b0,
                 "stall must suppress execute_enable_o");
      check_true(row_out_valid_o[0] === 1'b1,
                 "the first queued result must be visible during stall");
      check_equal32(row_out_data_o[0], 32'd100,
                    "the first queued result must be context 2 data");

      held_context = context_addr_o;
      @(posedge clk_i);
      #1ns;
      check_true(stall_o === 1'b1,
                 "stall must persist while the output remains blocked");
      check_true(context_addr_o === held_context,
                 "context address must hold during stall");

      // Stop issuing contexts, then accept the first result. The row queue must
      // pop context 2 and capture context 3 on the same edge.
      @(negedge clk_i);
      run_i = 1'b0;
      row_out_ready_i[0] = 1'b1;

      @(posedge clk_i);
      #1ns;
      row_out_ready_i[0] = 1'b0;
      check_true(stall_o === 1'b0,
                 "stall must clear after the blocked result enters the queue");
      check_true(row_out_valid_o[0] === 1'b1,
                 "pop-and-replace must keep row valid asserted");
      check_equal32(row_out_data_o[0], 32'd200,
                    "the replacement queue entry must be context 3 data");

      consume_row_output(0);
      @(posedge clk_i);
      #1ns;
      check_true(array_idle_o === 1'b1,
                 "array must become idle after the stalled output drains");
    end
  endtask

  initial begin
    error_count = 0;
    rst_ni      = 1'b0;

    $dumpfile("tb_ADRES.vcd");
    $dumpvars(0, tb);

    reset_dut();
    test_host_memory();

    reset_dut();
    test_context_control();

    reset_dut();
    test_row_input_path();

    reset_dut();
    test_row_arbitration();

    reset_dut();
    test_global_stall();

    if (error_count == 0) begin
      $display("\nADRES TESTBENCH PASSED\n");
      $finish;
    end else begin
      $fatal(1, "ADRES TESTBENCH FAILED with %0d error(s)", error_count);
    end
  end

  initial begin
    #100us;
    $fatal(1, "ADRES testbench watchdog timeout");
  end

endmodule

`default_nettype wire
