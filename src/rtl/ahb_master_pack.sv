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

package ahb_master_pack;

typedef enum logic [2:0] {SINGLE, INCR=3'd1, INCR4=3'd3, INCR8=3'd5, INCR16=3'd7} t_hburst;
typedef enum logic [1:0] {IDLE, BUSY, NONSEQ, SEQ}                                t_htrans;
typedef enum logic [2:0] {W8, W16, W32, W64, W128, W256, W512, W1024}             t_hsize;
typedef enum logic [1:0] {OKAY, ERROR, SPLIT, RETRY}                              t_hresp;

endpackage : ahb_master_pack
