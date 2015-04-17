//======================================================================
//
// residue.v
// ---------
// Modulus 2**2N residue calculator for montgomery calculations.
//
// m_residue_2_2N_array( N, M, Nr)
//   Nr = 00...01 ; Nr = 1 == 2**(2N-2N)
//   for (int i = 0; i < 2 * N; i++)
//     Nr = Nr shift left 1
//     if (Nr less than M) continue;
//     Nr = Nr - M
// return Nr
//
//
//
// Author: Peter Magnusson
// Copyright (c) 2015 Assured AB
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

module residue(
  input wire clk,
  input wire reset_n,

  input wire  calculate,
  output wire ready,

  input wire  [14 : 0] nn, //MAX(2*N)=8192*2 (14 bit) 
  input wire  [07 : 0] length,

  output wire [07 : 0] opa_rd_addr,
  input wire  [31 : 0] opa_rd_data,
  output wire [07 : 0] opa_wr_addr,
  output wire [31 : 0] opa_wr_data,
  output wire          opa_wr_we,

  output wire [07 : 0] opm_addr,
  input wire  [31 : 0] opm_data

);

//----------------------------------------------------------------
// Internal constant and parameter definitions.
//----------------------------------------------------------------


localparam CTRL_IDLE          = 4'h0;
localparam CTRL_INIT          = 4'h1;
localparam CTRL_INIT_STALL    = 4'h2;
localparam CTRL_SHL           = 4'h3;
localparam CTRL_SHL_STALL     = 4'h4;
localparam CTRL_COMPARE       = 4'h5;
localparam CTRL_COMPARE_STALL = 4'h6;
localparam CTRL_SUB           = 4'h7;
localparam CTRL_SUB_STALL     = 4'h8;
localparam CTRL_LOOP          = 4'h9;

//----------------------------------------------------------------
// Registers including update variables and write enable.
//----------------------------------------------------------------

reg [07 : 0] opa_rd_addr_reg;
reg [07 : 0] opa_wr_addr_reg;
reg [31 : 0] opa_wr_data_reg;
reg          opa_wr_we_reg;
reg [07 : 0] opm_addr_reg;
reg          ready_reg;
reg          ready_new;
reg          ready_we;
reg [03 : 0] residue_ctrl_reg;
reg [03 : 0] residue_ctrl_new;
reg          residue_ctrl_we;
reg          reset_word_index;
reg          reset_n_counter;
reg [14 : 0] loop_counter_1_to_nn_reg; //for i = 1 to nn (2*N)
reg [14 : 0] loop_counter_1_to_nn_new;
reg          loop_counter_1_to_nn_we;
reg [14 : 0] nn_reg;
reg          nn_we;
reg [07 : 0] length_m1_reg;
reg [07 : 0] length_m1_new;
reg          length_m1_we;
reg [07 : 0] word_index_reg;
reg [07 : 0] word_index_new;
reg          word_index_we;

//----------------------------------------------------------------
// Concurrent connectivity for ports etc.
//----------------------------------------------------------------
assign opa_rd_addr = opa_rd_addr_reg;
assign opa_wr_addr = opa_wr_addr_reg;
assign opa_wr_data = opa_wr_data_reg;
assign opm_addr    = opm_addr_reg;
assign ready       = ready_reg;




  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          residue_ctrl_reg <= CTRL_IDLE;
          word_index_reg   <= 8'h0;
          length_m1_reg    <= 8'h0;
          nn_reg           <= 15'h0;
          loop_counter_1_to_nn_reg <= 15'h0;
        end
      else
        begin
          if (residue_ctrl_we)
            residue_ctrl_reg <= residue_ctrl_new;

          if (word_index_we)
            word_index_reg <= word_index_new;

          if (length_m1_we)
            length_m1_reg <= length_m1_new;

          if (nn_we)
            nn_reg <= nn;

          if (loop_counter_1_to_nn_we)
            loop_counter_1_to_nn_reg <= loop_counter_1_to_nn_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  //----------------------------------------------------------------
  always @*
    begin : process_1_to_2n
      loop_counter_1_to_nn_new = loop_counter_1_to_nn_reg + 15'h1;
      loop_counter_1_to_nn_we  = 1'b0;

      if (reset_n_counter)
        begin
         loop_counter_1_to_nn_new = 15'h1;
         loop_counter_1_to_nn_we  = 1'b1;
        end

      if (residue_ctrl_reg == CTRL_LOOP)
        loop_counter_1_to_nn_we  = 1'b1;
    end

  //----------------------------------------------------------------
  //----------------------------------------------------------------
  always @*
    begin : word_index_process
      word_index_new = word_index_reg - 8'h1;
      word_index_we  = 1'b1;

      if (reset_word_index)
        word_index_new = length_m1_reg;

      if (residue_ctrl_reg == CTRL_IDLE)
        word_index_new = length_m1_new; //reduce a pipeline stage with early read

    end

//----------------------------------------------------------------
// residue_ctrl
//
// Control FSM for residue
//----------------------------------------------------------------
always @*
  begin : residue_ctrl
    ready_new = 1'b0;
    ready_we  = 1'b0;

    residue_ctrl_new = CTRL_IDLE;
    residue_ctrl_we  = 1'b0;

    reset_word_index = 1'b0;
    reset_n_counter  = 1'b0;

    length_m1_new  = length - 8'h1;
    length_m1_we   = 1'b0;

    nn_we = 1'b0;

    case (residue_ctrl_reg)
      CTRL_IDLE:
        if (calculate)
          begin
            ready_new = 1'b0;
            ready_we  = 1'b1;
            residue_ctrl_new = CTRL_INIT;
            residue_ctrl_we  = 1'b1;
            reset_word_index = 1'b1;
            length_m1_we     = 1'b1;
            nn_we            = 1'b1;
          end

      CTRL_INIT:
        if (word_index_reg == 8'h0)
          begin
            residue_ctrl_new = CTRL_INIT_STALL;
            residue_ctrl_we  = 1'b1;
          end

      CTRL_INIT_STALL:
        begin
          reset_word_index = 1'b1;
          reset_n_counter  = 1'b1;
          residue_ctrl_new = CTRL_COMPARE;
          residue_ctrl_we  = 1'b1;
        end

      CTRL_COMPARE:
        begin
        end

      CTRL_COMPARE_STALL:
        begin
        end

      CTRL_SUB:
        begin
        end

      CTRL_SUB_STALL:
        begin
        end

      CTRL_SHL:
        begin
        end

      CTRL_SHL_STALL:
        begin
        end

      CTRL_LOOP:
        begin
          if (loop_counter_1_to_nn_reg == nn_reg)
           begin
            ready_new = 1'b1;
            ready_we  = 1'b1;
            residue_ctrl_new = CTRL_IDLE;
            residue_ctrl_we  = 1'b1;
           end
        end

      default:
        begin
        end

    endcase
  end

endmodule // residue

//======================================================================
// EOF residue.v
//======================================================================