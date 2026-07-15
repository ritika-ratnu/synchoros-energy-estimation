# HyCUBE (asynchoros)

RTL and testbench derived from the [`HyCUBE project`](https://github.com/aditi3512/HyCUBE).

This copy is included to support the **HyCUBE asynchoros testcase** in this repository; minor local edits exist only for the purpose of integration/reproducibility.

## RTL design 

- The full chip wrapper exists as `chip_with_pad` → `chip` → `hycube`, but we instantiate `hycube` directly.
- The HyCUBE fabric inside `hycube` is a \(4 \times 4\) tile array (`NUM_TILES_X = NUM_TILES_Y = 4`).

```text
Top-level wrappers (available in rtl/rtl/)

  chip_with_pad
      |
      +--> chip  
            |                                                                 
            +--> spi_all  (programming interface / drives scan_data path)     
            |                                                                 
            +--> clkGen_top_blmux (clock generation)                          
            |                                                                 
            +--> hycube  (core fabric)                                        
                                                                              
Core fabric (hycube.sv)

  hycube
    |
    +--> Control-memory macros (per tile)   TS6N40LPA24X64M2F (CM, 64-bit wide)
    |
    +--> Data-memory macros (leftmost tiles)  TSDN40LPA512X32M4F (DM, 32-bit wide)
    |
    +--> 4x4 Tile Array
          (Tile[i][j] for i in Y, j in X)
            |
            +--> tile (tile.sv)
                  |
                  +--> router (router.sv) + xbar/encoder/globals packages
                  |
                  +--> simple_alu (simple_alu.sv)
                  |
                  +--> local CM/DM interfaces
                  |
                  +--> NoC links (N/E/S/W) connecting neighboring tiles

NoC connectivity 

   [0,0] -- [0,1] -- [0,2] -- [0,3]
     |        |        |        |
   [1,0] -- [1,1] -- [1,2] -- [1,3]
     |        |        |        |
   [2,0] -- [2,1] -- [2,2] -- [2,3]
     |        |        |        |
   [3,0] -- [3,1] -- [3,2] -- [3,3]
```

## Testbench

  1) Initialize + reset release
  2) Program Data Memory (DM) 
  3) Program Control Memory (CM) 
  4) Start execution
     - wait a couple cycles
     - set scan_start_exec = 1
     - DUT runs until exec_end indicates completion
```
