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

module ahb_manager import ahb_manager_pack::*; #(parameter DATA_WDT = 32) (
// AHB
input  logic                i_hclk,
input  logic                i_hreset_n,
output logic [31:0]         o_haddr,
output t_hburst             o_hburst,
output t_htrans             o_htrans,
output logic [DATA_WDT-1:0] o_hwdata,
output logic                o_hwrite,
output t_hsize              o_hsize,
input  logic [DATA_WDT-1:0] i_hrdata,
input  logic                i_hready,
input  t_hresp              i_hresp,
input  logic                i_hgrant,
output logic                o_hbusreq,

// UI
output logic                o_err,        // Internal error occured. Must reset.
output logic                o_next,       // UI must change only if this is 1.
input  logic [DATA_WDT-1:0] i_wr_data,    // Data to write. Can change if o_next = 1.
input  logic                i_wr,         // Write to AHB bus. Qualifies i_wr_data.
input  logic                i_rd,         // Read from AHB bus.
input  logic  [15:0]        i_min_len,    // Minimum guaranteed length of burst.
input  logic  [31:0]        i_mask,       // Wrap mask. Mask bits remain same.
input  logic  [31:0]        i_addr,       // Base address of burst.
input  t_hsize              i_size,       // Size of transfer. Like hsize.
input  logic                i_first_xfer, // First beat of new burst. Idle if 1 and rd=wr=0.
output logic [DATA_WDT-1:0] o_data,       // Data got from AHB is presented here.
output logic [31:0]         o_addr,       // Corresponding address is presented here.
output logic                o_dav         // Used as o_data valid indicator.
);

logic signed [5:0]       burst_ctr, burst_ctr_nxt, burst_ctr_nxt_sc;
logic signed [16:0]      beat, beat_ctr, beat_ctr_sc, beat_ctr_nxt_sc,
                         beat_ctr_nxt, beatx, beatx_nxt;
logic        [1:0]       gnt, gnt_nxt;
t_hburst                 hburst, hburst_nxt;
t_htrans                 htrans0_nxt, htrans2_nxt;
t_htrans                 htrans [3];
t_hsize                  hsize  [3];
logic                    hwrite [3];
logic    [DATA_WDT-1:0]  hwdata [3];
logic    [31:0]          mask   [3];
t_hsize                  hsize0_nxt;
logic    [DATA_WDT-1:0]  data_nxt, hwdata0_nxt;
logic    [31:0]          haddr  [3];
logic    [31:0]          addr_arg, rd_addr_nxt, addr_nxt, addr_nxt_sc, mask0_nxt,
                         addr_nrml, haddr0_nxt;
logic                    pend_split, pend_split_nxt, spl_ret_cyc_1, boundary_1k,
                         term_bc_no_incr,first_xfer, nonburst, rcmp_brst_sc,
                         recompute_brst, hbusreq_nxt, ui_idle, clkena_st1,
                         clkena_st2, clkena_st3, dav_nxt, hresp_splt_ret, hwrite0_nxt,
                         htrans1_sq_nsq, htrans2_sq_nsq, clkena_st1_idx2, htrans0_idle,
                         hready_grant, htrans1_idle, htrans0_busy, rd_wr;

for(genvar i=0;i<32;i++) begin : l_addr_nxt
    assign addr_nxt[i] = i_mask[i] ? haddr[0][i] : addr_nxt_sc[i];
end : l_addr_nxt

assign htrans0_idle     = htrans[0] == IDLE;
assign htrans1_idle     = htrans[1] == IDLE;
assign htrans0_busy     = htrans[0] == BUSY;
assign hresp_splt_ret   = (i_hresp == SPLIT) | (i_hresp   ==  RETRY);
assign htrans1_sq_nsq   = (htrans[1] == SEQ) | (htrans[1] == NONSEQ);
assign htrans2_sq_nsq   = (htrans[2] == SEQ) | (htrans[2] == NONSEQ);
assign hready_grant     = i_hready & i_hgrant;
assign rd_wr            = i_rd | i_wr;
assign ui_idle          = i_first_xfer & ~i_rd & ~i_wr;
assign first_xfer       = i_first_xfer & rd_wr;
assign spl_ret_cyc_1    = gnt[0] & ~i_hready & hresp_splt_ret;
assign boundary_1k      = addr_nxt[31:10] != haddr[0][31:10];
assign nonburst         = boundary_1k | (addr_nxt < addr_nxt_sc);
assign term_bc_no_incr  = (burst_ctr == 'd1) & (o_hburst != INCR);
assign pend_split_nxt   = spl_ret_cyc_1 ? 1'd1 : (hready_grant ? 1'd0 : pend_split);

assign addr_nrml        = (haddr[0] + ((~htrans0_busy ? 'd1 : 'd0) << i_size));
assign addr_nxt_sc      = haddr[0] + ({31'd0, rd_wr} << i_size);
assign addr_arg         = i_first_xfer ? i_addr : addr_nxt_sc;

assign rcmp_brst_sc     = |{first_xfer, ~gnt[0], term_bc_no_incr, htrans0_idle, nonburst};
assign recompute_brst   = (htrans[0] != BUSY) & rcmp_brst_sc;

assign clkena_st1       =  spl_ret_cyc_1 | hready_grant;
assign clkena_st1_idx2  = clkena_st1 & spl_ret_cyc_1 & ~htrans2_sq_nsq;
assign clkena_st2       =  gnt[0] & i_hready;
assign clkena_st3       =  gnt[1] & i_hready & htrans1_sq_nsq & ~hresp_splt_ret;

assign beat_ctr_sc      = hburst == INCR ? beat_ctr  : (beat_ctr  - {17{rd_wr}});
assign burst_ctr_nxt_sc = hburst == INCR ? burst_ctr : (burst_ctr - { 6{rd_wr}});
assign beat_ctr_nxt_sc  = i_first_xfer ? {1'd0, i_min_len} : beat_ctr_sc;

assign o_err            = ~((beat_ctr >= 0) & (burst_ctr >= 0) & (burst_ctr <= 16));
assign o_next           = ~htrans2_sq_nsq & ~spl_ret_cyc_1 & (( hready_grant & ~pend_split ) | ui_idle);

assign gnt_nxt          = spl_ret_cyc_1 ? 2'd0 : i_hready ? {gnt[0], i_hgrant} : gnt;
assign hbusreq_nxt      = rd_wr | ~i_first_xfer | ~htrans1_idle;

assign {dav_nxt, data_nxt, rd_addr_nxt} = clkena_st3 ?
       {~hwrite[1], i_hrdata, haddr[1]} : {1'd0, o_data, o_addr};

assign {o_haddr,  o_hburst,o_htrans,o_hwdata,   o_hwrite, o_hsize} =
       {haddr[0], hburst,  htrans[0], hwdata[1],hwrite[0],hsize[0]};

assign htrans0_nxt =  spl_ret_cyc_1  ? IDLE   :
                      pend_split     ? NONSEQ :
                      htrans2_sq_nsq ? NONSEQ :
                      ui_idle        ? IDLE   :
                      recompute_brst ? (rd_wr ? NONSEQ : IDLE) :
                      (rd_wr ? SEQ : BUSY);

assign haddr0_nxt =  spl_ret_cyc_1  ? haddr[0] :
                     pend_split     ? haddr[1] :
                     htrans2_sq_nsq ? haddr[2] :
                     ui_idle        ? haddr[0] :
                     recompute_brst ? addr_arg : addr_nrml;

assign beat_ctr_nxt =   spl_ret_cyc_1  ? beat_ctr :
                        pend_split     ? beat     :
                        htrans2_sq_nsq ? beatx    :
                        ui_idle        ? beat_ctr :
                        recompute_brst ? beat_ctr_nxt_sc : beat_ctr_sc;

assign {hburst_nxt, burst_ctr_nxt} =
spl_ret_cyc_1  ? {hburst, burst_ctr}                                             :
pend_split     ? compute_hburst(beat [15:0], haddr[1], hsize[1], mask[1])        :
htrans2_sq_nsq ? compute_hburst(beatx[15:0], haddr[2], hsize[2], mask[2])        :
ui_idle        ? {hburst, burst_ctr}                                             :
recompute_brst ? compute_hburst(beat_ctr_nxt_sc[15:0], addr_arg, i_size, i_mask) :
{hburst, burst_ctr_nxt_sc};

assign beatx_nxt = spl_ret_cyc_1 & ~htrans2_sq_nsq ? beat : beatx;

assign htrans2_nxt = ( spl_ret_cyc_1 & ~htrans2_sq_nsq) ? htrans[0] :
                     (~spl_ret_cyc_1 & ~pend_split    ) ? IDLE : htrans[2];

assign {mask0_nxt, hwdata0_nxt, hwrite0_nxt, hsize0_nxt} =
        spl_ret_cyc_1  ? { mask[0] , hwdata[0] , hwrite[0] , hsize[0] } :
        pend_split     ? { mask[1] , hwdata[1] , hwrite[1] , hsize[1] } :
        htrans2_sq_nsq ? { mask[2] , hwdata[2] , hwrite[2] , hsize[2] } :
                         { i_mask  , i_wr_data , i_wr      , i_size   } ;

`FREEAHB_FF(gnt, gnt_nxt, 1'd1)
`FREEAHB_FF(o_hbusreq, hbusreq_nxt, 1'd1)

// Pipe Stage 1 (ADDR)

`FREEAHB_FF(pend_split, pend_split_nxt, clkena_st1)
`FREEAHB_FF(htrans[0],  htrans0_nxt,    clkena_st1)
`FREEAHB_FF(haddr[0],   haddr0_nxt,     clkena_st1)
`FREEAHB_FF(beat_ctr,   beat_ctr_nxt,   clkena_st1)
`FREEAHB_FF(burst_ctr,  burst_ctr_nxt,  clkena_st1)
`FREEAHB_FF(hburst,     hburst_nxt,     clkena_st1)
`FREEAHB_FF(beatx,      beatx_nxt,      clkena_st1)
`FREEAHB_FF(htrans[2],  htrans2_nxt,    clkena_st1)
`FREEAHB_FF({mask[2], hwdata[2], hwrite[2], hsize[2], haddr[2]},
            {mask[0], hwdata[0], hwrite[0], hsize[0], haddr[0]}, clkena_st1_idx2)
`FREEAHB_FF({mask[0],   hwdata[0],   hwrite[0],     hsize[0]},
            {mask0_nxt, hwdata0_nxt, hwrite0_nxt, hsize0_nxt}, clkena_st1)

// Pipe Stage 2 (HWDATA)

`FREEAHB_FF({mask[1], hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1], beat},
            {mask[0], hwdata[0], haddr[0], hwrite[0], hsize[0], htrans[0], beat_ctr},
             clkena_st2)

// Pipe Stage 3 (HRDATA)

`FREEAHB_FF({o_dav, o_data, o_addr}, {dav_nxt, data_nxt, rd_addr_nxt}, 1'd1)

endmodule : ahb_manager

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
