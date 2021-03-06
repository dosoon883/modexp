//======================================================================
//
// blockmem_rw32_r128.v
// --------------------
// Test implementation of a block memory that has different data
// widths on external (api) and internal ports.
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

module blockmem_rw32_r128(
                          input wire            clk,

                          input wire            api_we,
                          input wire  [07 : 0]  api_addr,
                          input wire  [31 : 0]  api_wr_data,
                          output wire [31 : 0]  api_rd_data,

                          input wire  [05  : 0] internal_addr,
                          output wire [127 : 0] internal_rd_data
                         );


  //----------------------------------------------------------------
  // Regs and memories.
  //----------------------------------------------------------------
  reg [31 : 0] mem0 [0 : 63];
  reg [31 : 0] mem1 [0 : 63];
  reg [31 : 0] mem2 [0 : 63];
  reg [31 : 0] mem3 [0 : 63];


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] muxed_api_rd_data;
  reg [31 : 0] mem0_api_rd_data;
  reg [31 : 0] mem1_api_rd_data;
  reg [31 : 0] mem2_api_rd_data;
  reg [31 : 0] mem3_api_rd_data;

  reg [31 : 0] mem0_int_rd_data;
  reg [31 : 0] mem1_int_rd_data;
  reg [31 : 0] mem2_int_rd_data;
  reg [31 : 0] mem3_int_rd_data;

  reg          mem0_we;
  reg          mem1_we;
  reg          mem2_we;
  reg          mem3_we;


  //----------------------------------------------------------------
  // Assignmets.
  //----------------------------------------------------------------
  assign api_rd_data      = muxed_api_rd_data;

  assign internal_rd_data = {mem3_int_rd_data, mem2_int_rd_data,
                             mem1_int_rd_data, mem0_int_rd_data};


  //----------------------------------------------------------------
  // Reg updates.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update_mem0
      if (mem0_we)
        mem0[api_addr[7 : 2]] <= api_wr_data;

      mem0_api_rd_data <= mem0[api_addr[7 : 2]];
      mem0_int_rd_data <= mem0[internal_addr];
    end

  always @ (posedge clk)
    begin : reg_update_mem1
      if (mem1_we)
        mem1[api_addr[7 : 2]] <= api_wr_data;

      mem1_api_rd_data <= mem1[api_addr[7 : 2]];
      mem1_int_rd_data <= mem1[internal_addr];
    end

  always @ (posedge clk)
    begin : reg_update_mem2
      if (mem2_we)
        mem2[api_addr[7 : 2]] <= api_wr_data;

      mem2_api_rd_data <= mem2[api_addr[7 : 2]];
      mem2_int_rd_data <= mem2[internal_addr];
    end

  always @ (posedge clk)
    begin : reg_update_mem3
      if (mem3_we)
        mem3[api_addr[7 : 2]] <= api_wr_data;

      mem3_api_rd_data <= mem3[api_addr[7 : 2]];
      mem3_int_rd_data <= mem3[internal_addr];
    end

  //----------------------------------------------------------------
  // api_mux
  //----------------------------------------------------------------
  always @*
    begin : api_mux
      mem0_we = 1'b0;
      mem1_we = 1'b0;
      mem2_we = 1'b0;
      mem3_we = 1'b0;

      case (api_addr[1 : 0])
        0:
          begin
            muxed_api_rd_data = mem0_api_rd_data;
            mem0_we           = api_we;
          end

        1:
          begin
            muxed_api_rd_data = mem1_api_rd_data;
            mem1_we           = api_we;
          end

        2:
          begin
            muxed_api_rd_data = mem2_api_rd_data;
            mem2_we           = api_we;
          end

        3:
          begin
            muxed_api_rd_data = mem3_api_rd_data;
            mem3_we           = api_we;
          end

        default:
          begin
          end
      endcase // case (api_addr[1 : 0])
    end // api_mux

endmodule // blockmem_rw32_r128

//======================================================================
// eof blockmem_rw32_r128.v
//======================================================================
