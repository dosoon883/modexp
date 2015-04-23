//======================================================================
//
// tb_modexp.v
// -----------
// Testbench modular exponentiation core.
//
//
// Author: Joachim Strombergson, Peter Magnusson
// Copyright (c) 2015, Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

//------------------------------------------------------------------
// Simulator directives.
//------------------------------------------------------------------
`timescale 1ns/100ps


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_modexp();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG = 1;

  localparam CLK_HALF_PERIOD = 1;
  localparam CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  // The DUT address map.
  localparam GENERAL_PREFIX      = 4'h0;
  localparam ADDR_NAME0          = 8'h00;
  localparam ADDR_NAME1          = 8'h01;
  localparam ADDR_VERSION        = 8'h02;

  localparam ADDR_CTRL           = 8'h08;
  localparam CTRL_START_BIT      = 0;

  localparam ADDR_STATUS         = 8'h09;
  localparam STATUS_READY_BIT    = 0;

  localparam ADDR_MODULUS_LENGTH  = 8'h20;
  localparam ADDR_MESSAGE_LENGTH  = 8'h21;
  localparam ADDR_EXPONENT_LENGTH = 8'h22;

  localparam MODULUS_PREFIX      = 4'h1;
  localparam ADDR_MODULUS_START  = 8'h00;
  localparam ADDR_MODULUS_END    = 8'hff;

  localparam EXPONENT_PREFIX     = 4'h2;
  localparam ADDR_EXPONENT_START = 8'h00;
  localparam ADDR_EXPONENT_END   = 8'hff;

  localparam MESSAGE_PREFIX      = 4'h3;
  localparam MESSAGE_START       = 8'h00;
  localparam MESSAGE_END         = 8'hff;

  localparam RESULT_PREFIX       = 4'h4;
  localparam RESULT_START        = 8'h00;
  localparam RESULT_END          = 8'hff;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;

  reg [31 : 0]  read_data;
  reg [127 : 0] result_data;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_cs;
  reg           tb_we;
  reg [11  : 0] tb_address;
  reg [31 : 0]  tb_write_data;
  wire [31 : 0] tb_read_data;
  wire          tb_error;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  modexp dut(
             .clk(tb_clk),
             .reset_n(tb_reset_n),
             .cs(tb_cs),
             .we(tb_we),
             .address(tb_address),
             .write_data(tb_write_data),
             .read_data(tb_read_data)
            );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;

      #(CLK_PERIOD);

      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state();
    begin
      $display("cycle: 0x%016x", cycle_ctr);
      $display("State of DUT");
      $display("------------");
      $display("Inputs and outputs:");
      $display("cs   = 0x%01x, we = 0x%01x", tb_cs, tb_we);
      $display("addr = 0x%08x, read_data = 0x%08x, write_data = 0x%08x",
               tb_address, tb_read_data, tb_write_data);
      $display("");

      $display("State:");
      $display("ready_reg = 0x%01x, start_reg = 0x%01x",
               dut.ready_reg, dut.start_reg);
      $display("residue_valid = 0x%01x", dut.residue_valid_reg);
      $display("loop_counter = 0x%08x", dut.loop_counter_reg);
      $display("exponent_length = 0x%02x, modulus_length = 0x%02x, length = 0x%02x, length_m1 = 0x%02x",
               dut.exponent_length_reg, dut.modulus_length_reg,
               dut.length_reg, dut.length_m1_reg);
      $display("ctrl_reg =  0x%04x", dut.modexp_ctrl_reg);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut();
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;

      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
      $display("");
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results();
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim();
    begin
      cycle_ctr          = 0;
      error_ctr          = 0;
      tc_ctr             = 0;

      tb_clk             = 0;
      tb_reset_n         = 1;

      tb_cs              = 0;
      tb_we              = 0;
      tb_address         = 8'h00;
      tb_write_data      = 32'h00000000;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // write_word()
  //
  // Write the given word to the DUT using the DUT interface.
  //----------------------------------------------------------------
  task write_word(input [11 : 0] address,
                  input [31 : 0] word);
    begin
      if (DEBUG)
        begin
          $display("*** (write_word) Writing 0x%08x to 0x%02x.", word, address);
          $display("");
        end

      tb_address = address;
      tb_write_data = word;
      tb_cs = 1;
      tb_we = 1;
      #(2 * CLK_PERIOD);
      tb_cs = 0;
      tb_we = 0;
    end
  endtask // write_word


  //----------------------------------------------------------------
  // read_word()
  //
  // Read a data word from the given address in the DUT.
  // the word read will be available in the global variable
  // read_data.
  //----------------------------------------------------------------
  task read_word(input [11 : 0] address);
    begin
      tb_address = address;
      tb_cs = 1;
      tb_we = 0;
      #(CLK_PERIOD);
      read_data = tb_read_data;
      tb_cs = 0;

      if (DEBUG)
        begin
          $display("*** (read_word) Reading 0x%08x from 0x%02x.", read_data, address);
          $display("");
        end
    end
  endtask // read_word


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait until the ready flag in the core is set.
  //----------------------------------------------------------------
  task wait_ready();
    begin
      while (tb_read_data != 32'h00000001)
          read_word({GENERAL_PREFIX, ADDR_STATUS});

      if (DEBUG)
        $display("*** (wait_ready) Ready flag has been set.");
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // tc1
  //
  // A first, very simple testcase where we want to do:
  // c = m ** e % N with the following (decimal) test values:
  //  m = 3
  //  e = 7
  //  n = 11
  //  c = 3 ** 7 % 11 = 9
  //----------------------------------------------------------------
  task tc1();
    reg [31 : 0] read_data;

    begin
      tc_ctr = tc_ctr + 1;
      $display("TC1: Trying to calculate 3**7 mod 11 = 9");

      // Write 13 to (m)esaage memory.
      write_word({MESSAGE_PREFIX, 8'h00}, 32'h00000003);

      // Write 11 to exponent memory and set length to one word.
      write_word({EXPONENT_PREFIX, 8'h00}, 32'h00000007);
      write_word({GENERAL_PREFIX, ADDR_EXPONENT_LENGTH}, 32'h00000001);

      // Write 7 to modulus memory and set length to one word.
      write_word({MODULUS_PREFIX, 8'h00}, 32'h0000000b);
      write_word({GENERAL_PREFIX, ADDR_MODULUS_LENGTH}, 32'h00000001);

      // Start processing and wait for ready.
      write_word({GENERAL_PREFIX, ADDR_CTRL}, 32'h00000001);
      wait_ready();

      // Read out result word and check result.
      read_word({RESULT_PREFIX, 8'h00});
      read_data = tb_read_data;

      if (read_data == 32'h00000009)
        begin
          $display("*** TC1 successful.");
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC1 NOT successful.");
          $display("Expected: 0x06, got 0x%08x", read_data);
          error_ctr = error_ctr + 1;
        end
    end
  endtask // tc1



  //----------------------------------------------------------------
  // tc2
  //
  // c = m ** e % N with the following (decimal) test values:
  //  m = 251
  //  e = 251
  //  n = 257
  //  c = 251 ** 251 % 257 = 183
  //----------------------------------------------------------------
  task tc2();
    reg [31 : 0] read_data;

    begin
      tc_ctr = tc_ctr + 1;
      $display("TC1: Trying to calculate 251**251 mod 257 = 183");

      // Write 13 to (m)esaage memory.
      write_word({MESSAGE_PREFIX, 8'h00}, 32'h000000fb);

      // Write 11 to exponent memory and set length to one word.
      write_word({EXPONENT_PREFIX, 8'h00}, 32'h000000fb);
      write_word({GENERAL_PREFIX, ADDR_EXPONENT_LENGTH}, 32'h00000001);

      // Write 7 to modulus memory and set length to one word.
      write_word({MODULUS_PREFIX, 8'h00}, 32'h00000101);
      write_word({GENERAL_PREFIX, ADDR_MODULUS_LENGTH}, 32'h00000001);

      // Start processing and wait for ready.
      write_word({GENERAL_PREFIX, ADDR_CTRL}, 32'h00000001);
      wait_ready();

      // Read out result word and check result.
      read_word({RESULT_PREFIX, 8'h00});
      read_data = tb_read_data;

      if (read_data == 32'h000000b7)
        begin
          $display("*** TC1 successful.");
          $display("");
        end
      else
        begin
          $display("*** ERROR: TC1 NOT successful.");
          $display("Expected: 0x06, got 0x%08x", read_data);
          error_ctr = error_ctr + 1;
        end
    end
  endtask // tc2


  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : main

      $display("   -= Testbench for modexp started =-");
      $display("    =================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();

      tc1();
      tc2();

      display_test_results();

      $display("");
      $display("*** modexp simulation done. ***");
      $finish;
    end // main
endmodule // tb_modexp

//======================================================================
// EOF tb_modexp.v
//======================================================================
