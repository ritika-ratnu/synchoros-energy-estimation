////////////////////////////////////////////////////////////////////////////////
////                                                                        ////
//// Project Name: HyCUBE (Verilog, SystemVerilog)                          ////
////                                                                        ////
//// Module Name: router                                                    ////
////                                                                        ////
////                                                                        ////
////  This file is part of the HyCUBE project                               ////
////  https://github.com/aditi3512/HyCUBE                                   ////
////                                                                        ////
////  Author(s):                                                            ////
////      NUS, MIT                                                          ////
////                                                                        ////
////  Refer to Readme.txt for more information                              ////
////                                                                        ////
////////////////////////////////////////////////////////////////////////////////
////                                                                        ////
//// Copyright 2020 Author(s)						    ////
//// Permission is hereby granted, free of charge, to any person 	    ////
//// obtaining a copy of this software and associated documentation 	    ////
//// files (the "Software"), to deal in the Software without restriction,   ////
//// including without limitation the rights to use, copy, modify, merge,   ////
//// publish, distribute, sublicense, and/or sell copies of the Software,   ////
//// and to permit persons to whom the Software is furnished to do so, 	    ////
//// subject to the following conditions:				    ////
////									    ////
//// The above copyright notice and this permission notice shall be 	    ////
//// included in all copies or substantial portions of the Software.	    ////
////									    ////
//// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 	    ////
//// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     ////
//// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. ////
//// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR 	    ////
//// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 	    ////	
//// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION     ////
//// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.	    ////
////                                                                        ////
//// You should have received a copy of the MIT                             ////
//// License along with this source; if not, download it                    ////
//// from https://opensource.org/licenses/MIT                               ////
////                                                                        ////
////////////////////////////////////////////////////////////////////////////////


//------------------------------------------------------------------------------
// SMART Router
//------------------------------------------------------------------------------
module router(
    clk,
    reset,

    i__sram_xbar_sel,

    i__flit_in,
    i__alu_out,
    i__treg,
    o__flit_out,
    regbypass,
    regWEN
);

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
import SMARTPkg::*;

parameter NUM_VCS                       = 4;

localparam NUM_INPUT_PORTS              = 6;
localparam NUM_OUTPUT_PORTS             = 7;
localparam LOG_NUM_VCS                  = $clog2(NUM_VCS);
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// IO
//------------------------------------------------------------------------------

// General
input  logic                            clk;
input  logic                            reset;

input  logic [NUM_INPUT_PORTS-1:0]	i__sram_xbar_sel	        [NUM_OUTPUT_PORTS-1:0];

// Incoming flit and outgoing credit
input  FlitFixed         i__flit_in                      [NUM_INPUT_PORTS-1-2:0];
input  FlitFixed         i__alu_out;
input  FlitFixed         i__treg;

// Outgoing flit and incoming credit
output FlitFixed         o__flit_out                     [NUM_OUTPUT_PORTS-1:0];

input  [3:0] 				regbypass;
input  [3:0] 				regWEN;

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------

FlitFixed                w__flit_xbar_flit_out                   [NUM_OUTPUT_PORTS-1:0];

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Submodules
//------------------------------------------------------------------------------
    logic [NUM_INPUT_PORTS-1:0]         this_flit_xbar_sel              [NUM_OUTPUT_PORTS-1:0];
    FlitFixed                           this_flit_out_local             [NUM_INPUT_PORTS-1-2:0];
    FlitFixed                           this_flit_in                    [NUM_INPUT_PORTS-1:0];
    FlitFixed                           this_flit_xbar_flit_out         [NUM_OUTPUT_PORTS-1:0];

    always_comb
    begin
        for(int j = 0; j < NUM_INPUT_PORTS-2; j++)
        begin
	    this_flit_in[j] 		= i__flit_in[j];
        end
	    this_flit_in[ALU_T] 	= i__alu_out;
	    this_flit_in[TREG]  	= i__treg;

        for(int j = 0; j < NUM_OUTPUT_PORTS; j++)
        begin
            for(int k = 0; k < NUM_INPUT_PORTS; k++)
            begin
                this_flit_xbar_sel[j][k] = i__sram_xbar_sel[j][k];
            end
        end
    end

always @(posedge clk)
if (reset)
begin
   for(int j = 0; j < NUM_INPUT_PORTS-2; j++)
   begin
	this_flit_out_local[j] <= {33{1'b0}};
   end
end
else 
begin
   for(int j = 0; j < NUM_INPUT_PORTS-2; j++)
   begin
	    if (regWEN[j] == 1'b1)  //ASKmanupa
	    begin
		this_flit_out_local[j] <= i__flit_in[j];
		$display("ASK router this_flit_out_local = %b", this_flit_out_local[j]);
	    end
   end
end
    always_comb
    begin
        for(int j = 0; j < NUM_OUTPUT_PORTS; j++)
        begin
            w__flit_xbar_flit_out[j] = this_flit_xbar_flit_out[j];
        end
    end

    xbar_bypass  
        #(
            .DATA_WIDTH                 ($bits(FlitFixed))
        )
        xbar_bypass(
            .i__sel                     (this_flit_xbar_sel),
            .i__data_in_local           (this_flit_out_local),
            .i__data_in_remote          (this_flit_in),
	    .regbypass			(regbypass),
            .o__data_out                (this_flit_xbar_flit_out)
        );

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Flit to neighbor router
//------------------------------------------------------------------------------
always_comb
begin
    for(int i = 0; i < (NUM_OUTPUT_PORTS); i++)
    begin
        o__flit_out[i] = w__flit_xbar_flit_out[i];
    end
end
//------------------------------------------------------------------------------


endmodule


