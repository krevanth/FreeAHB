// ----------------------------------------------------------------------------
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
// AHB manager that implements all 2.0 features except WRAP transfers.
// ----------------------------------------------------------------------------

module ahb_manager_top import ahb_manager_pack::*; #(parameter DATA_WDT = 32) (

        // ---------------------------
        // AHB interface.
        // ---------------------------

        input     logic                  i_hclk,
        input     logic                  i_hreset_n,
        output    logic [31:0]           o_haddr,
        output    t_hburst               o_hburst,
        output    t_htrans               o_htrans,
        output    logic [DATA_WDT-1:0]   o_hwdata,
        output    logic                  o_hwrite,
        output    t_hsize                o_hsize,
        input     logic [DATA_WDT-1:0]   i_hrdata,
        input     logic                  i_hready,
        input     t_hresp                i_hresp,
        input     logic                  i_hgrant,
        output    logic                  o_hbusreq,

        // ----------------------------
        // User Interface
        // ----------------------------

        // User interface (Command). Do not change any of them throughout the
        // burst except i_first_xfer - that too only when o_stall = 0. Use
        // i_first_xfer=1 to signal start of a new burst. Again, note that
        // this can be done only when o_stall = 0.
        //
        // Note that HTB means Hold Throughout Burst. HF means should be valid
        // for first beat i.e., when i_first_xfer=1.
        //
        // DO NOT MAKE I_IDLE=1 IN BETWEEN AN ONGOING BURST OPERATION. ONLY
        // MAKE IT 1 AFTER ENTIRE BURST COMMAND SEQUENCE HAS COMPLETELY BEEN
        // GIVEN TO THE UNIT. OUT OF RESET, KEEP I_IDLE=1 FOR AT LEAST
        // 1 CYCLE.
        //
        // WHEN I_FIRST_XFER=1, YOU SHOULD HAVE EITHER RD=1 OR WR=1.

        output logic                  o_stall,        // All UI inputs stalled when 1.
        input  logic                  i_idle,         // Make 1 to indicate NO ACTIVITY. Ignores rd, wr and first_xfer.
        input  logic   [DATA_WDT-1:0] i_wr_data,      // Data to write. Can change throughout write burst.
        input  logic    [31:0]        i_addr,         // Base address of burst. HF.
        input  t_hsize                i_size,         // Size of transfer i.e., hsize. HTB.
        input  logic                  i_wr,           // Write to AHB bus.  (Can be gapped to pause writes).
        input  logic                  i_rd,           // Read from AHB bus. (Can be gapped to pause reads).
        input  logic   [15:0]         i_min_len,      // Minimum guaranteed length of burst i.e., beats. HF.
        input  logic                  i_first_xfer,   // Initiate a new burst. Make 0 on subsequent beats.

        // User Interface (Read Response) - Always in order. Arrives some time
        // after appropriate read commands are presented on the command
        // interface.

        output logic   [DATA_WDT-1:0] o_data,         // Data got from AHB is presented here.
        output logic   [31:0]         o_addr,         // Corresponding address is presented here.
        output logic                  o_dav           // Used as o_data valid indicator.
);

logic [DATA_WDT-1:0] wr_data;      // Data to write.
logic  [31:0]        addr;         // Base address of burst.
t_hsize              size;         // Size of transfer i.e., hsize.
logic                wr;           // Write to AHB bus.
logic                rd;           // Read from AHB bus.
logic [15:0]         min_len;      // Minimum guaranteed length of burst.
logic                first_xfer;   // From skid buffer to AHB manager.
logic                next;         // From AHB manager core to skid buffer.
logic                err;          // For assertion.

`ifndef SYNTHESIS

    t_hsize              size_prev;           // For assertion.
    bit                  notstarted = 1'd1;   // For assertion.

    always @ (posedge i_hclk) // Assertion
    begin : assertion

        size_prev <= i_size;

        if      (first_xfer) notstarted <= 1'd0;
        else if (i_idle)     notstarted <= 1'd1;

        assert (~i_hreset_n | ~i_first_xfer | (i_first_xfer & (i_rd | i_wr)))
        else $fatal(2, "When first xfer=1, make either rd=1 or wr=1.");

        if ( i_size != size_prev )
        begin
            assert(~i_hreset_n | i_first_xfer | i_idle) else
            $fatal(2, "Keep i_size constant throughout burst sequence.");
        end

        if ( notstarted & ~first_xfer )
        begin
            assert(~i_hreset_n | i_idle) else
            $fatal(2, "Keep i_idle=1 out of reset/in between burst sequences.");
        end

        assert (~i_hreset_n | ~err) else $fatal(2, "Internal overflow.");

    end : assertion

`else

wire unused = |{1'd1, err};

`endif

// Skid buffer for UI signals.
ahb_manager_skid_buffer
#(
    .WDT(DATA_WDT + 16 + 38)
) u_skid_buffer (
    .i_clk(i_hclk),
    .i_resetn(i_hreset_n),
    .i_data({i_wr_data, i_addr, i_size, i_wr & ~i_idle,i_rd & ~i_idle,
             i_min_len, (i_idle | i_first_xfer)}),
    .o_stall(o_stall),
    .o_data({wr_data, addr,size,wr,rd,min_len,first_xfer}),
    .i_stall(~next)
);

// AHB manager core.
ahb_manager
#(
    .DATA_WDT(DATA_WDT)
) u_ahb_manager (
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
    .i_wr_data(wr_data),
    .i_addr(addr),
    .i_size(size),
    .i_wr(wr),
    .i_rd(rd),
    .i_min_len(min_len),
    .i_first_xfer(first_xfer),
    .o_next(next),
    .o_data(o_data),
    .o_addr(o_addr),
    .o_dav(o_dav),
    .o_err(err)
);

endmodule : ahb_manager_top

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
