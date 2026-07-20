# 4x4 ADRES CGRA integration

## Build order
Compile the files in `ADRES_hierarchy.txt`.

## Tile IDs
```text
  0   1   2   3
  4   5   6   7
  8   9  10  11
 12  13  14  15
```

The programming port writes one tile configuration memory at a time using `cfg_*`.

## Tile port map

One-hop connectivity along each PE’s row and column.
(Current implementation has a multi-bus style to support multiple transfers in the same cycle.)

## Data memory

Four banks, one below each PE column.

```text
bank column = global_word_address[1:0]
local address = global_word_address >> 2
```

The compiler should place or route the memory operation into the corresponding
column.

### Port-9 request protocol

A read is one token:

```text
payload[31] = 0
payload[DMEM_ADDR_W-1:0] = local word address
```

A write is two tokens from the same tile:

```text
header payload[31] = 1
header payload[DMEM_ADDR_W-1:0] = local word address
next token payload[31:0] = write data
```

The response mailbox on input port 9 retains the latest completion:

```text
{1'b1, read_data}  read complete
{1'b1, 32'b0}      write complete
```

A tile must complete a pending write with its data token before starting another
memory transaction. The host memory port is accepted only when the array is
stopped and all memory queues/write sequences are idle.

## Backpressure

Every tile has a one-entry queue for row egress and memory requests. If a tile
produces another endpoint token while its queue cannot accept it, `stall_o`
causes the global context controller to hold every PE. This keeps the static
row/column schedule aligned while shared endpoints drain independently.

## Corrections applied to the supplied RTL

- `pkg::NUM_PORTS` changed from 5 to 10. Ten ports are required by the source
  selector encoding and by the 79-bit tile configuration word.
- The tile variable named `config` was renamed because `config` is a
  SystemVerilog keyword.
- The split `$warning` string in `tile.sv` was made legal SystemVerilog.
- Arithmetic right shift now casts the payload to signed.
- ALU result widths are explicit 33-bit values.
- Generic address comparisons use explicit integer casts to avoid signedness
  ambiguity.

                                                              
                                                              
                        run_i       set_context_i       set_context_addr_i   execute_enable_o     context_addr_o
                           |               |                   |                    ^                   ^
                           v               v                   v                    |                   |
                  +-----------------------------------------------------------------ADRES----------------------------+
                  |                                 |                   |                                           |
                  |                    +------------+-------------------+-----------+                               |
                  |                    |            Context Controller              |                               |
                  |                    +------------+-------------------+-----------+                               |
                  |                                 |                   |                                           |
                  |                     execute_enable_o        context_addr_o                                      |
                  |                                 |                   |                                           |
                  |             +-------------------+-------+-----------+------------------------+                  |
                  |             |                           |                                    |                  |
                  |             v                           v                                    v                  |
                  |    +----------------------+  +----------------------+              +----------------------+     |
                  |    | Row Input Ready      |  | Tile Matrix          |------------->| Endpoint Queue /     |-----|-----> stall_o
                  |    | Logic                |  |                      |              | Backpressure Logic   |     |
                  |    +----------+-----------+  |                      |              +----------+-----------+     |
                  |               |              |                      |                         |                 |
                  |               +--------------|                      |---------------------> row_in_ready_o      |
clear_outputs_i --|----------------------------->|                      |-------------------------+                 |
cfg_write_enable_i|----------------------------->|                      |     +----------------------+              |      
cfg_tile_i -------|----------------------------->|                      |---->| Row Egress Logic     |              |      
cfg_write_addr_i -|----------------------------->|                      |     |                      |              |      
cfg_write_data_i -|----------------------------->|                      |     +----------------------+              |      
row_in_valid_i ---|----------------------------->|                      |                                           |      
row_in_data_i ----|----------------------------->|                      |                                           |      dmem_host_valid_i
                  |                              +----------|-----------+                                           |      dmem_host_write_i
                  |                                         v                                                       |      dmem_host_bank_i   
                  |                              +----------------------+                                           |      dmem_host_addr_i   
                  |                              | DM Host-Access       |<------------------------------------------|----- dmem_host_wdata_i  
                  |                              | Logic                |------------------------------------------------> dmem_host_ready_o    
                  |                              +----------+-----------+                                           |      dmem_host_rvalid_o    
                  |                                         |                                                       |      dmem_host_rdata_o   
                  |                                         v                                                       |      row_out_valid_o     
                  |                               +----------------------+                                          |      row_out_data_o      
                  |                        run_i->| Array-Idle Logic     |--------> array_idle_o                    |      row_out_source_o   
                  |              row_out_ready_i->+----------+-----------+                                          |
                  |                                                                                                 |      
                  +-------------------------------------------------------------------------------------------------+
                                                                                            
                                                                                            
                                                                                            
                                                                                            
                                                                                            
