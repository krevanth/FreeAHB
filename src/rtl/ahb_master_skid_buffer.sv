// Copyright (C) 2017 Revanth Kamaraj
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

module ahb_master_skid_buffer #(parameter WDT=32) (
    input   logic              i_clk,
    input   logic              i_resetn,
    input   logic [WDT-1:0]    i_data,
    output  logic              o_stall,
    output  logic [WDT-1:0]    o_data,
    input   logic              i_stall
);

logic           stall;
logic [WDT-1:0] data_ff;

always_ff @ (posedge i_clk or negedge i_resetn)
    if(!i_resetn)    stall <= 1'd0;
    else             stall <= i_stall;

assign o_stall = stall;
assign o_data  = stall ? data_ff : i_data;

always_ff @ (posedge i_clk or negedge i_resetn)
    if(!i_resetn)    data_ff <= 'd0;
    else if (!stall) data_ff <= i_data;

endmodule : ahb_master_skid_buffer
