\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   
   // ########################################################
   // #                                                      #
   // #  Empty template for Tiny Tapeout Makerchip Projects  #
   // #                                                      #
   // ########################################################
   
   // ========
   // Settings
   // ========
   
   //-------------------------------------------------------
   // Build Target Configuration
   //
   var(my_design, tt_um_example)   /// The name of your top-level TT module, to match your info.yml.
   var(target, ASIC)   /// Note, the FPGA CI flow will set this to FPGA.
   //-------------------------------------------------------
   
   var(in_fpga, 1)   /// 1 to include the demo board. (Note: Logic will be under /fpga_pins/fpga.)
   var(debounce_inputs, 0)         /// 1: Provide synchronization and debouncing on all input signals.
                                   /// 0: Don't provide synchronization and debouncing.
                                   /// m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   
   // ======================
   // Computed From Settings
   // ======================
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))

\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/5744600215af09224b7235479be84c30c6e50cb7/tlv_lib/tiny_tapeout_lib.tlv'])
   m4_include_lib(https://raw.githubusercontent.com/stevehoover/gian-course/9ce47c64c435ae69c2d2c3733f86abfe158d8276/reference_designs/PmodKYPD.tlv)
	
\TLV my_design()
   
   
   
   // ==================
   // |                |
   // | YOUR CODE HERE |
   // |                |
   // ==================
   
   // Note that pipesignals assigned here can be found under /fpga_pins/fpga.
   
   |pipe
      m5+PmodKYPD(|pipe, /keypad, @0, $num[3:0], 1'b1, ['left:40, top: 80, width: 20, height: 20'])
      @0
         $reset = *reset;
         
         //$match = ($num == *random_number);
         //$count= >>1$score;
      @1
         //?$match
         //   $score[3:0] = $count + 1'b1;
         $num[3:0] = *ui_in[3:0];
         m5+sseg_decoder($segments_n, *uio_out)
         *uo_out[7:0] = {1'b0 , ~ $segments_n} ;
         //*uo_out = /keypad$sampling ? {4'b0, /keypad$sample_row_mask} : {1'b0 , ~ $segments_n};
   
   
     
   
   // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
   *uo_out = 8'b0;
   m5_if_neq(m5_target, FPGA, ['*uio_out = 8'b0;'])
   m5_if_neq(m5_target, FPGA, ['*uio_oe = 8'b0;'])

// Set up the Tiny Tapeout lab environment.
\TLV tt_lab()
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   m5_if_neq(m5_target, FPGA, ['logic [7:0] uio_in, uio_out, uio_oe;'])
   logic [31:0] r;  // a random value
   always @(posedge clk) r <= m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   assign ui_in = r[7:0];
   m5_if_neq(m5_target, FPGA, ['assign uio_in = 8'b0;'])
   logic ena = 1'b0;
   logic rst_n = ! reset;
   
   /*
   // Or, to provide specific inputs at specific times (as for lab C-TB) ...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step 5 cycles, past reset.
         ui_in = 8'hFF;
      // ...etc.
   end
   */
   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);
   
   assign passed = top.cyc_cnt > 3000;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
\SV



// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output logic [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    m5_if_eq(m5_target, FPGA, ['/']['*'])   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    m5_if_eq(m5_target, FPGA, ['*']['/'])
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n    // reset_n - low to reset
);
   wire reset = ! rst_n;

   // List all potentially-unused inputs to prevent warnings
   wire _unused = &{ena, clk, rst_n, 1'b0};
   
   

\TLV
   /* verilator lint_off UNOPTFLAT */
   m5_if(m5_in_fpga, ['m5+tt_lab()'], ['m5+my_design()'])

\SV_plus
   
   // ==========================================
   // If you are using Verilog for your design,
   // your Verilog logic goes here.
   // Note, output assignments are in my_design.
   // ==========================================
   logic [7:0] random_number;
   logic feed_back;
   logic [7:0]lfsr;
	logic [7:0]count;
   logic match;
   logic [7:0] score ;
   
   assign feed_back = lfsr[2] ^ lfsr[1] ;

   //assign uio_out = score;
   
   initial lfsr = 8'd1;
   
   always @(posedge clk)begin
      if(reset)
         count <= 0;
      else if (count == 'hFF) 
         count <= 0;
      else
         count <= count + 1;
      end

	always @(posedge count[6]) begin
      	if(reset)
            lfsr <= 8'd1;
         else
            lfsr <= {5'b0,lfsr[1:0],feed_back };
   end
   
   assign random_number = lfsr;
   assign match = ({4'b0,ui_in[3:0]} == random_number) ? 1'b1 : 1'b0;
   
   always @(posedge count[5])begin
      	if(match)
            score <= score + 1'b1;
      	else if (pstate == INIT)
            score <= 0;
          else
            score <= score;
      end

reg [1:0]pstate,nstate;        
parameter INIT=2'b00, START=2'b01, CAPTURE=2'b10, PRINT=2'b11;
logic [2:0] player;
   
initial player = 1;
// Function to generate a random number (using the LFSR state)
function [2:0] generate_random;
   input [2:0] lfsr;  // LFSR state
 begin
  // Shift the LFSR and insert the feedback value into the LSB
 generate_random = {lfsr[1:0], feed_back};
 end
endfunction
   
 always @(posedge clk,negedge rst_n)
     begin
       if(!rst_n)
         pstate<=INIT;
       else
         pstate<=nstate;
     end
   
 always @(posedge clk)
     begin
       case(pstate)
           INIT:begin
                 player <= player + 1'd1;
                 uio_out <= player;
                 nstate <= START;
                end
          START:begin
             	 uio_out  <=  'hFF ; //ALL BITS ARE ON INDICATING START
                nstate <= CAPTURE;
             end
          CAPTURE:begin
                   //random_number = generate_random(lfsr);
                   uio_out  <= random_number;
						for (byte i = 0 ; i<10 ; i++)begin
                     if (i<10) nstate <= CAPTURE;
                     else nstate <= PRINT;
                  end
                 end
          PRINT : begin
             		uio_out <= score;
             		nstate <= INIT;
             end

       endcase
     end
   
\SV
endmodule
