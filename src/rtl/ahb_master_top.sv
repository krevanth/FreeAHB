// Copyright (C) 2017-2024 Revanth Kamaraj (krevanth)
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
//
// AHB master that implements all 2.0 features except WRAP transfers.

module ahb_master_top import ahb_master_pack::*; #(parameter DATA_WDT = 32, parameter BEAT_WDT = 32) (

        // ---------------------------
        // AHB interface.
        // ---------------------------

        input                       i_hclk,
        input                       i_hreset_n,
        output    [31:0]            o_haddr,
        output    t_hburst          o_hburst,
        output    t_htrans          o_htrans,
        output    [DATA_WDT-1:0]    o_hwdata,
        output                      o_hwrite,
        output    t_hsize           o_hsize,
        input     [DATA_WDT-1:0]    i_hrdata,
        input                       i_hready,
        input     t_hresp           i_hresp,
        input                       i_hgrant,
        output                      o_hbusreq,

        // ----------------------------
        // User Interface
        // ----------------------------

        // User interface (Command). Do not change any of them throughout the
        // burst except i_first_xfer - that too only when o_stall = 0. Use
        // i_first_xfer=1 to signal start of a new burst. Again, note that
        // this can be done only when o_stall = 0. Note HTB: Hold Through Burst.
        // DO NOT MAKE I_IDLE=1 IN BETWEEN AN ONGOING BURST OPERATION.

        output                   o_stall,        // All UI inputs stalled when 1.
        input                    i_idle,         // Make 1 to indicate NO ACTIVITY. Ignores rd, wr and first_xfer.
        input     [DATA_WDT-1:0] i_wr_data,      // Data to write. Can change throughout write burst.
        input                    i_wr_data_dav,  // Data to write valid (Can be gapped to pause writes).
        input      [31:0]        i_addr,         // Base address of burst. HTB.
        input      t_hsize       i_size,         // Size of transfer i.e., hsize. HTB.
        input                    i_wr,           // Write to AHB bus. HTB.
        input                    i_rd,           // Read from AHB bus. (Can be gapped to pause reads).
        input     [BEAT_WDT-1:0] i_min_len,      // Minimum guaranteed length of burst i.e., beats. HTB.
        input                    i_first_xfer,   // Initiate a new burst. Make 0 on subsequent beats.

        // User Interface (Read Response) - Always in order. Arrives some time
        // after appropriate read commands are presented on the command
        // interface.

        output    [DATA_WDT-1:0] o_data,         // Data got from AHB is presented here.
        output    [31:0]         o_addr,         // Corresponding address is presented here.
        output                   o_dav           // Used as o_data valid indicator.
);

wire [DATA_WDT-1:0] wr_data;      // Data to write.
wire                wr_data_dav;  // Data to write valid.
wire  [31:0]        addr;         // Base address of burst.
t_hsize             size;         // Size of transfer i.e., hsize.
wire                wr;           // Write to AHB bus.
wire                rd;           // Read from AHB bus.
wire [BEAT_WDT-1:0] min_len;      // Minimum guaranteed length of burst.
wire                cont;         // From skid buffer to AHB master.
wire                next;         // From AHB master core to skid buffer.

ahb_master_skid_buffer
#(
    .WDT(DATA_WDT + BEAT_WDT + 39)
) u_skid_buffer (
    .i_clk(i_hclk),
    .i_resetn(i_hreset_n),
    .i_data({i_wr_data, i_wr_data_dav, i_addr, i_size, i_wr & ~i_idle,i_rd & ~i_idle,
             i_min_len, ~(i_idle|i_first_xfer)}),
    .o_stall(o_stall),
    .o_data({wr_data,wr_data_dav,addr,size,wr,rd,min_len,cont}),
    .i_stall(~next)
);

ahb_master
#(
    .DATA_WDT(DATA_WDT),
    .BEAT_WDT(BEAT_WDT)
) u_ahb_master (
    .i_hclk(i_hclk),
    .i_hreset_n(i_hreset_n),
    .o_haddr(o_haddr),
    .o_hburst(o_hburst),
    .o_htrans(o_htrans),
    .o_hwdata(o_hwdata),
    .o_hwrite(o_hwrite),
    .o_hsize(o_hsize),
    .i_hrdata(i_hrdata),
    .i_hready(i_hready),
    .i_hresp(i_hresp),
    .i_hgrant(i_hgrant),
    .o_hbusreq(o_hbusreq),
    .i_data(wr_data),
    .i_dav(wr_data_dav),
    .i_addr(addr),
    .i_size(size),
    .i_wr(wr),
    .i_rd(rd),
    .i_min_len(min_len),
    .i_cont(cont),
    .o_next(next),
    .o_data(o_data),
    .o_addr(o_addr),
    .o_dav(o_dav)
);

endmodule : ahb_master_top