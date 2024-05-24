// ----------------------------------------------------------------------------
// Copyright (C) 2017-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
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
// ----------------------------------------------------------------------------

package ahb_manager_pack;

typedef enum logic [2:0] {SINGLE, INCR=3'd1, INCR4=3'd3, INCR8=3'd5, INCR16=3'd7} t_hburst;
typedef enum logic [1:0] {IDLE, BUSY, NONSEQ, SEQ}                                t_htrans;
typedef enum logic [2:0] {W8, W16, W32, W64, W128, W256, W512, W1024}             t_hsize;
typedef enum logic [1:0] {OKAY, ERROR, SPLIT, RETRY}                              t_hresp;

function automatic logic [8:0] compute_hburst
(logic [15:0] val, logic [31:0] addr, logic [2:0] sz, logic [31:0] mask);
    compute_hburst = ((|val[15:4]) & ~bcross(addr, 'd15, sz, mask)) ? {INCR16, 6'd16} :
                     ((|val[15:3]) & ~bcross(addr, 'd7,  sz, mask)) ? {INCR8 , 6'd8}  :
                     ((|val[15:2]) & ~bcross(addr, 'd3,  sz, mask)) ? {INCR4 , 6'd4}  :
                                                                      {INCR  , 6'd0};
endfunction

function automatic logic bcross
(logic [31:0] addr, logic [31:0] val, logic [2:0] sz, logic [31:0] mask);
    logic [1:0][31:0] laddr;
    laddr[0] = addr + (val << (1 << sz));

    for(int i=0;i<32;i++) begin
        laddr[1][i] = mask[i] ? addr[i] : laddr[0][i];
    end

    bcross = ( laddr[1][31:10] != addr[31:10] ) | ( laddr[1] < addr );
endfunction

`ifndef __FREEAHB_DEFINES__
`define __FREEAHB_DEFINES__

    `define FREEAHB_FF(Q,D,EN) \
    always @ (posedge i_hclk or negedge i_hreset_n) \
    if(!i_hreset_n) Q <= '0; else Q <= EN ? D : Q;

    `define FREEAHB_ASSERT(Y,X) \
    always @ (posedge i_hclk) assert(X) else $fatal(2, "TEST FAILED. CODE=%d", Y);

`endif

endpackage : ahb_manager_pack

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
