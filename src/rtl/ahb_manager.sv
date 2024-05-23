// ----------------------------------------------------------------------------
// Copyright (C) 2017-2024 Revanth Kamaraj
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

module ahb_manager import ahb_manager_pack::*; #(parameter DATA_WDT = 32) (

        // AHB

        input   logic                i_hclk,
        input   logic                i_hreset_n,
        output  logic [31:0]         o_haddr,
        output  t_hburst             o_hburst,
        output  t_htrans             o_htrans,
        output  logic [DATA_WDT-1:0] o_hwdata,
        output  logic                o_hwrite,
        output  t_hsize              o_hsize,
        input   logic [DATA_WDT-1:0] i_hrdata,
        input   logic                i_hready,
        input   t_hresp              i_hresp,
        input   logic                i_hgrant,
        output  logic                o_hbusreq,

        // UI

        output logic                 o_err,        // Internal error occured. Must reset.
        output logic                 o_next,       // UI must change only if this is 1.
        input  logic [DATA_WDT-1:0]  i_wr_data,    // Data to write. Can change during burst if o_next = 1.
        input  logic                 i_wr,         // Write to AHB bus. Qualifies i_wr_data.
        input  logic                 i_rd,         // Read from AHB bus.
        input  logic  [15:0]         i_min_len,    // Minimum guaranteed length of burst.
        input  logic  [31:0]         i_addr,       // Base address of burst.
        input  t_hsize               i_size,       // Size of transfer. Like hsize.
        input  logic                 i_first_xfer, // First beat of new burst.
        output logic [DATA_WDT-1:0]  o_data,       // Data got from AHB is presented here.
        output logic [31:0]          o_addr,       // Corresponding address is presented here.
        output logic                 o_dav         // Used as o_data valid indicator.
);

logic signed [5:0]       burst_ctr, burst_ctr_nxt; // Local chunk size of burst length.
logic signed [16:0]      beat, beat_ctr, beat_ctr_sc, beat_ctr_nxt, beatx; // Overall burst length.
logic        [1:0]       gnt, gnt_nxt;
t_hburst                 hburst;
t_htrans                 htrans [3];
t_hsize                  hsize  [3];
logic                    hwrite [3];
logic    [DATA_WDT-1:0]  hwdata [3];
logic    [DATA_WDT-1:0]  data_nxt;
logic    [31:0]          haddr  [3];
logic    [31:0]          addr_arg, addr_nxt;
logic pend_split, pend_split_nxt, spl_ret_cyc_1, boundary_1k, term_bc_no_incr,first_xfer,
      rcmp_brst_sc, recompute_brst, hbusreq_nxt, ui_idle, clkena_st1, clkena_st2, clkena_st3, dav_nxt;

assign spl_ret_cyc_1   = gnt[0] & ~i_hready & (i_hresp == SPLIT || i_hresp == RETRY);
assign boundary_1k     = (haddr[0] + ('d1 << i_size)) >> 'd10 != {10'd0, haddr[0][31:10]};
assign term_bc_no_incr = (burst_ctr == 'd1) & (o_hburst != INCR);
assign first_xfer      = i_first_xfer & (i_rd | i_wr);
assign rcmp_brst_sc    = |{first_xfer, ~gnt[0], term_bc_no_incr, htrans[0] == IDLE, boundary_1k};
assign recompute_brst  = (htrans[0] != BUSY) & rcmp_brst_sc;
assign addr_arg        = i_first_xfer ? i_addr : haddr[0] + ({31'd0, (i_rd | i_wr)} << i_size);
assign ui_idle         = i_first_xfer & ~i_rd & ~i_wr;
assign clkena_st1      =  spl_ret_cyc_1 | (i_hready & i_hgrant);
assign clkena_st2      =  gnt[0] & i_hready;
assign clkena_st3      =  gnt[1] & i_hready & (htrans[1] == SEQ || htrans[1] == NONSEQ) &
                          ((i_hresp != SPLIT) & (i_hresp != RETRY));
assign beat_ctr_sc     = (hburst == INCR ? beat_ctr  : (beat_ctr  - ((i_rd | i_wr) ? 'd1 : '0)));
assign burst_ctr_nxt   = (hburst == INCR ? burst_ctr : (burst_ctr - ((i_rd | i_wr) ? 'd1  :'0)));
assign beat_ctr_nxt    = i_first_xfer ? {1'd0, i_min_len} : beat_ctr_sc;
assign o_err           = ~((beat_ctr >= 0) & (burst_ctr >= 0) & (burst_ctr <= 16));
assign o_next          = (htrans[2] != SEQ) & (htrans[2] != NONSEQ) & ~spl_ret_cyc_1 &
                         ((i_hready & i_hgrant & ~pend_split ) | ui_idle);
assign gnt_nxt         = spl_ret_cyc_1 ? 2'd0 : i_hready ? {gnt[0], i_hgrant} : gnt;
assign hbusreq_nxt     = i_rd | i_wr | ~i_first_xfer | (htrans[1] != IDLE);
assign pend_split_nxt  = spl_ret_cyc_1 ? 1'd1 : ((i_hready & i_hgrant) ? 1'd0 : pend_split);

assign {dav_nxt, data_nxt, addr_nxt} = clkena_st3 ? {~hwrite[1], i_hrdata, haddr[1]} : {1'd0, o_data, o_addr};

assign {o_haddr,  o_hburst,o_htrans,o_hwdata,   o_hwrite, o_hsize} =
       {haddr[0], hburst,  htrans[0], hwdata[1],hwrite[0],hsize[0]};

`FREEAHB_FF(gnt, gnt_nxt, 1'd1)
`FREEAHB_FF(o_hbusreq, hbusreq_nxt, 1'd1)
`FREEAHB_FF({hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1], beat},
            {hwdata[0], haddr[0], hwrite[0], hsize[0], htrans[0], beat_ctr}, clkena_st2) // Stage 2 (HWDATA)
`FREEAHB_FF({o_dav, o_data, o_addr}, {dav_nxt, data_nxt, addr_nxt}, 1'd1) // Stage 3 (HRDATA)

// Stage 1 (ADDR)

`FREEAHB_FF(pend_split, pend_split_nxt, clkena_st1)

always_ff @ (posedge i_hclk or negedge i_hreset_n)
    if ( !i_hreset_n )
    begin
       {hwdata[0], hwrite[0], hsize[0], hburst, beat_ctr, burst_ctr, htrans[0]} <= 'd0;
       {hwdata[2], hwrite[2], hsize[2], htrans[2], beatx} <= 'd0;
    end
    else if ( clkena_st1 )
    begin
        if ( spl_ret_cyc_1 )
        begin
            if ( htrans[2] != SEQ && htrans[2] != NONSEQ )
            begin
                {hwdata[2], hwrite[2], hsize[2], haddr[2], htrans[2], beatx} <=
                {hwdata[0], hwrite[0], hsize[0], haddr[0], htrans[0], beat};
            end

            htrans[0] <= IDLE;
        end
        else if ( pend_split ) // Perform pipeline rollback.
        begin
            {hwdata[0], hwrite[0], hsize[0], haddr[0], htrans[0], beat_ctr} <=
            {hwdata[1], hwrite[1], hsize[1], haddr[1], NONSEQ,    beat};

            {hburst, burst_ctr} <= compute_hburst(beat[15:0], haddr[1], hsize[1]);
        end
        else if ( htrans[2] == SEQ || htrans[2] == NONSEQ ) // Restore original transaction.
        begin
            {hwdata[0], hwrite[0], hsize[0], haddr[0], htrans[0], htrans[2], beat_ctr} <=
            {hwdata[2], hwrite[2], hsize[2], haddr[2], NONSEQ,    IDLE,      beatx};

            {hburst, burst_ctr} <= compute_hburst(beatx[15:0], haddr[2], hsize[2]);
        end
        else
        begin
            {hwdata[0], hwrite[0], hsize[0], htrans[2]} <= {i_wr_data, i_wr, i_size, IDLE};

            if ( ui_idle ) htrans[0] <= IDLE;
            else if ( recompute_brst ) // Recompute burst properties
            begin
                haddr[0]            <= i_first_xfer ? i_addr : (haddr[0] + ({31'd0, (i_rd|i_wr)} << i_size));
                htrans[0]           <= (i_rd | i_wr) ? NONSEQ : IDLE;
                {hburst, burst_ctr} <= compute_hburst(beat_ctr_nxt[15:0], addr_arg, i_size );
                beat_ctr            <= beat_ctr_nxt;
            end
            else // We are in normal burst. No need to change HBURST.
            begin
                haddr[0]            <= haddr[0] + ((htrans[0] != BUSY ? 'd1 : 'd0) << i_size);
                htrans[0]           <= (i_rd | i_wr) ? SEQ : BUSY;
                burst_ctr           <= burst_ctr_nxt;
                beat_ctr            <= beat_ctr_sc;
            end
        end
    end

endmodule : ahb_manager

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
