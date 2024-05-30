/*
Copyright (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

`ifndef __FREEAHB_AHB_MASTER_DEFINES__
`define __FREEAHB_AHB_MASTER_DEFINES__
`define FREEAHB_FF(Q,D,EN)  \
    always @ (posedge i_hclk or negedge i_hreset_n) begin \
        if(!i_hreset_n) begin \
            Q <= '0; \
        end \
        else begin \
            Q <= (EN) ? (D) : (Q); \
        end \
    end
`endif // __FREEAHB_AHB_MASTER_DEFINES__

module ahb_manager #( parameter DATA_WDT = 32,
type t_hburst = enum logic [2:0] {SINGLE, INCR=3'd1, INCR4=3'd3, INCR8=3'd5,
                                  INCR16=3'd7},
type t_htrans = enum logic [1:0] {IDLE, BUSY, NONSEQ, SEQ},
type t_hsize  = enum logic [2:0] {W8, W16, W32, W64, W128, W256, W512, W1024},
type t_hresp  = enum logic [1:0] {OKAY, ERROR, SPLIT, RETRY}
) (
input  logic                  i_hclk,
input  logic                  i_hreset_n,
output logic [31:0]           o_haddr,
output       t_hburst         o_hburst,
output       t_htrans         o_htrans,
output logic [DATA_WDT-1:0]   o_hwdata,
output logic                  o_hwrite,
output       t_hsize          o_hsize,
input  logic [DATA_WDT-1:0]   i_hrdata,
input  logic                  i_hready,
input        t_hresp          i_hresp,
input  logic                  i_hgrant,
output logic                  o_hbusreq,

output logic                  o_err,
output logic                  o_stall,
input  logic                  i_idle,
input  logic                  i_wr,
input  logic   [DATA_WDT-1:0] i_wr_data,
input  logic   [31:0]         i_addr,
input  logic                  i_wrap,
input          t_hsize        i_size,
input  logic   [15:0]         i_min_len,
input  logic                  i_first_xfer,
input  logic                  i_rd,
output logic   [DATA_WDT-1:0] o_rd_data,
output logic   [31:0]         o_rd_data_addr,
output logic                  o_rd_data_dav );

logic signed [5:0]    burst_ctr, burst_ctr_nxt, burst_ctr_nxt_sc;
logic signed [16:0]   beat, beat_ctr, beat_ctr_burst, beat_ctr_rcmp,
                      beat_ctr_nxt, beatx;
logic        [1:0]    gnt, gnt_nxt;
t_hburst              hburst, hburst_nxt;
t_htrans              htrans0_nxt, htrans2_nxt;
t_htrans              htrans [3];
t_hsize               hsize  [3];
t_hsize               hsize0_nxt, x_size;
logic [2:0]           hwrite;
logic [2:0][31:0]     mask;
logic [DATA_WDT-1:0]  rd_data_nxt, hwdata0_nxt, x_wr_data, hwdata0_sc, rot_amt,
                      rd_data_int, rd_rot_int, rd_rot_nxt, rd_data_fin_nxt;
logic [2:0][31:0]     haddr;
logic [31:0]          addr_rcmp, addr_sc, mask0_nxt, addr_burst, haddr0_nxt,
                      x_mask, x_addr, addr_sc_sc, mask_precmp, prod,
                      rd_addr_int;
logic                 pend_split, pend_split_nxt, spl_ret_cyc_1, boundary_1k,
                      term_bc_no_incr,first_xfer, nonburst, rcmp_brst_sc,
                      recompute_brst, hbusreq_nxt, ui_idle, clkena_st1,
                      clkena_st2, clkena_st3, rd_dav_nxt, hresp_splt_ret,
                      hwrite0_nxt, htrans1_sq_nsq, htrans2_sq_nsq,
                      clkena_st1_idx2, htrans0_idle, hready_grant, htrans1_idle,
                      htrans0_busy, rd_wr, next, x_rd, x_wr, err, x_first_xfer,
                      x_wrap, htrans0_busy1k, rd_int, wr_int, fxfer,
                      load_htrans, unused_ok, rd_dav_int;
logic [15:0]          x_min_len;
logic [6:0][1:0][DATA_WDT-1:0] wgen;
logic [2:0][DATA_WDT-1:0]      hwdata;
logic [2:0][DATA_WDT+86:0]     skbuf_mem, skbuf_mem_nxt;

// Procedures.

function automatic logic [8:0] compute_hburst // Predict HBURST.
( logic [15:0] val, logic [31:0] addr, logic [2:0] sz, logic [31:0] imask );
logic unused;
unused = |{1'd1, val[1:0]};
return ((|val[15:4]) & ~burst_cross(addr, 'd15, sz, imask)) ? {INCR16,6'd16} :
       ((|val[15:3]) & ~burst_cross(addr, 'd7,  sz, imask)) ? {INCR8, 6'd8}  :
       ((|val[15:2]) & ~burst_cross(addr, 'd3,  sz, imask)) ? {INCR4, 6'd4}  :
                                                              {INCR,6'd0};
endfunction : compute_hburst

function automatic logic burst_cross // Will we cross 1K or wrap boundary ?
( logic [31:0] addr, logic [31:0] val, logic [2:0] sz, logic [31:0] imask );
    logic [1:0][31:0] laddr;
    laddr[0] = addr + (val << (1 << sz));

    // Mask=1 preserves bit.
    for(int i=0;i<32;i++) laddr[1][i] = imask[i] ? addr[i] : laddr[0][i];
    burst_cross = ( laddr[1][31:10] != addr[31:10] ) | ( laddr[1] < addr );
endfunction : burst_cross

// Handles data rotation as required by AHB (Byte Lane Management).
function automatic logic [DATA_WDT-1:0] data_rota ( logic src, t_hsize sz );
    data_rota =
    (({29'd0, sz} == 'd0) & (DATA_WDT >   8)) ? wgen[0][src] :
    (({29'd0, sz} == 'd1) & (DATA_WDT >  16)) ? wgen[1][src] :
    (({29'd0, sz} == 'd2) & (DATA_WDT >  32)) ? wgen[2][src] :
    (({29'd0, sz} == 'd3) & (DATA_WDT >  64)) ? wgen[3][src] :
    (({29'd0, sz} == 'd4) & (DATA_WDT > 128)) ? wgen[4][src] :
    (({29'd0, sz} == 'd5) & (DATA_WDT > 256)) ? wgen[5][src] :
    (({29'd0, sz} == 'd6) & (DATA_WDT > 512)) ? wgen[6][src] : 'd0;
endfunction : data_rota

// Gets mask when using wrap mode. Takes total length in bytes as input.
function automatic logic [31:0] get_mask ( logic [31:0] product );
    logic unused;
    unused = |{1'd1, product[31:17]};
    casez(product[16:0])
    17'b1_????_????_????_???? : return ~{16'd0, {16{1'd1}}};
    17'b0_1???_????_????_???? : return ~{17'd0, {15{1'd1}}};
    17'b0_01??_????_????_???? : return ~{18'd0, {14{1'd1}}};
    17'b0_001?_????_????_???? : return ~{19'd0, {13{1'd1}}};
    17'b0_0001_????_????_???? : return ~{20'd0, {12{1'd1}}};
    17'b0_0000_1???_????_???? : return ~{21'd0, {11{1'd1}}};
    17'b0_0000_01??_????_???? : return ~{22'd0, {10{1'd1}}};
    17'b0_0000_001?_????_???? : return ~{23'd0,  {9{1'd1}}};
    17'b0_0000_0001_????_???? : return ~{24'd0,  {8{1'd1}}};
    17'b0_0000_0000_1???_???? : return ~{25'd0,  {7{1'd1}}};
    17'b0_0000_0000_01??_???? : return ~{26'd0,  {6{1'd1}}};
    17'b0_0000_0000_001?_???? : return ~{27'd0,  {5{1'd1}}};
    17'b0_0000_0000_0001_???? : return ~{28'd0,  {4{1'd1}}};
    17'b0_0000_0000_0000_1??? : return ~{29'd0,  {3{1'd1}}};
    17'b0_0000_0000_0000_01?? : return ~{30'd0,  {2{1'd1}}};
    17'b0_0000_0000_0000_001? : return ~{31'd0,  {1{1'd1}}};
    17'b0_0000_0000_0000_0001 : return ~{32'd0};
    default                   : return 'x; // Don't care for many synth tools.
    endcase
endfunction

// Signal aliases.

for(genvar i=0;i<=6;i++) begin : l_wgen
    if( DATA_WDT <= (2**(i+3)) ) begin : l_wgeni
        assign wgen[i][0] = 'd0;
        assign wgen[i][1] = 'd0;
    end : l_wgeni
    else begin : l_wgenj
        assign wgen[i][0] =
        {{(DATA_WDT - ($clog2(DATA_WDT/(2 ** (i+3))) + i + 3)){1'd0}},
        haddr0_nxt[i + $clog2(DATA_WDT/(2 ** (i+3))) - 1:0], {3{1'd0}}};

        assign wgen[i][1] =
        {{(DATA_WDT - ($clog2(DATA_WDT/(2 ** (i+3))) + i + 3)){1'd0}},
          haddr[1][i + $clog2(DATA_WDT/(2 ** (i+3))) - 1:0], {3{1'd0}}};
    end : l_wgenj
end : l_wgen

assign htrans0_idle    = htrans[0] == IDLE;
assign htrans1_idle    = htrans[1] == IDLE;
assign htrans0_busy    = htrans[0] == BUSY;
assign hresp_splt_ret  = i_hresp   inside {SPLIT, RETRY};
assign htrans1_sq_nsq  = htrans[1] inside {SEQ, NONSEQ};
assign htrans2_sq_nsq  = htrans[2] inside {SEQ, NONSEQ};
assign load_htrans     = spl_ret_cyc_1 & ~htrans2_sq_nsq;
assign hready_grant    = i_hready & i_hgrant;
assign rd_wr           = x_rd | x_wr;
assign ui_idle         = x_first_xfer & ~x_rd & ~x_wr;
assign first_xfer      = x_first_xfer & rd_wr;
assign spl_ret_cyc_1   = gnt[0] & ~i_hready & hresp_splt_ret;
assign boundary_1k     = addr_sc[31:10] != haddr[0][31:10];
assign nonburst        = boundary_1k | ( addr_sc < haddr[0] );
assign term_bc_no_incr = (burst_ctr == 'd1) & (o_hburst != INCR);
assign htrans0_busy1k  = htrans0_busy
                       & (~|haddr[0][9:0] | ((haddr[0] & x_mask) == haddr[0]))
                       & rd_wr;

// Output drivers.

assign {o_haddr,  o_hburst,o_htrans,o_hwdata,   o_hwrite, o_hsize} =
       {haddr[0], hburst,  htrans[0], hwdata[1],hwrite[0],hsize[0]};

// General pipeline management.

assign next =   ~htrans2_sq_nsq & ~spl_ret_cyc_1 &
                (( hready_grant & ~pend_split ) | ui_idle);

assign gnt_nxt     = spl_ret_cyc_1 ? 2'd0 : i_hready ? {gnt[0], i_hgrant} : gnt;
assign hbusreq_nxt = rd_wr | ~x_first_xfer | ~htrans1_idle;

`FREEAHB_FF({o_hbusreq, gnt}, {hbusreq_nxt, gnt_nxt}, 1'd1)

// 2 Way Skid buffer (Basically 2 deep sync FIFO).

`FREEAHB_FF(o_stall     , ~next           , 1'd1)
`FREEAHB_FF(skbuf_mem[0], skbuf_mem_nxt[0], ~o_stall)
`FREEAHB_FF(skbuf_mem[1], skbuf_mem_nxt[1], ~o_stall)
`FREEAHB_FF(skbuf_mem[2], skbuf_mem_nxt[2], ~o_stall)

assign skbuf_mem_nxt[2] =
{i_wr_data, wr_int, rd_int, i_addr, fxfer, i_wrap, i_min_len, i_size, 32'd0};

assign
{x_wr_data, x_wr, x_rd, x_addr, x_first_xfer, x_wrap, x_min_len, x_size, x_mask}
=  o_stall ? skbuf_mem[0] : skbuf_mem[1] ;

assign prod             = skbuf_mem[2][50:35] * ('d1 << skbuf_mem[2][34:32]);
assign mask_precmp      = skbuf_mem[2][51] ? get_mask ( prod ) : 'd0;
assign rd_int           = i_rd & ~i_idle;
assign wr_int           = i_wr & ~i_idle;
assign fxfer            = i_first_xfer | i_idle;
assign skbuf_mem_nxt[0] = skbuf_mem[1];
assign skbuf_mem_nxt[1] = skbuf_mem[2] | {{(DATA_WDT+55){1'd0}}, mask_precmp};

// Pipe Stage 1 (ADDR)

assign pend_split_nxt = spl_ret_cyc_1 | (hready_grant ? 1'd0 : pend_split);
assign recompute_brst = (~htrans0_busy | htrans0_busy1k) & rcmp_brst_sc;

assign rcmp_brst_sc   = |{first_xfer, ~gnt[0], term_bc_no_incr, htrans0_idle,
                          nonburst, htrans0_busy1k};

assign {mask0_nxt, hwdata0_nxt, hwrite0_nxt, hsize0_nxt} =
        spl_ret_cyc_1  ? { mask[0] , hwdata[0] , hwrite[0] , hsize[0] } :
        pend_split     ? { mask[1] , hwdata[1] , hwrite[1] , hsize[1] } :
        htrans2_sq_nsq ? { mask[2] , hwdata[2] , hwrite[2] , hsize[2] } :
                         { x_mask  , hwdata0_sc , x_wr      , x_size  } ;

assign rot_amt     = data_rota('d0, x_size);
assign hwdata0_sc  = x_wr_data << rot_amt;
assign clkena_st1  = spl_ret_cyc_1 | hready_grant;

assign {haddr0_nxt, htrans0_nxt} =
spl_ret_cyc_1  ? {haddr[0], IDLE}   :
pend_split     ? {haddr[1], NONSEQ} :
htrans2_sq_nsq ? {haddr[2], NONSEQ} :
ui_idle        ? {haddr[0], IDLE}   :
recompute_brst ?
 {rd_wr ? {addr_rcmp, NONSEQ} : {haddr[0], IDLE}} :
 {addr_burst, rd_wr ? SEQ : BUSY};

assign addr_sc_sc = haddr[0] + ({31'd0, ~htrans0_busy} << x_size);

for(genvar i=0;i<32;i++) begin : l_addr_sc // Mask=1 preserves bit.
    assign addr_sc[i] = x_mask[i] ? haddr[0][i] : addr_sc_sc[i];
end : l_addr_sc

assign addr_rcmp    = x_first_xfer ? x_addr : addr_sc;
assign addr_burst   = haddr[0] + ((htrans0_busy ? 'd0 : 'd1) << x_size);
assign beat_ctr_nxt = spl_ret_cyc_1  ? beat_ctr :
                      pend_split     ? beat     :
                      htrans2_sq_nsq ? beatx    :
                      ui_idle        ? beat_ctr :
                      recompute_brst ? beat_ctr_rcmp : beat_ctr_burst;

assign beat_ctr_burst = hburst == INCR ? beat_ctr :
                        (beat_ctr - (rd_wr ? 'd1 : 'd0));

assign beat_ctr_rcmp  = x_first_xfer ? {1'd0, x_min_len} : beat_ctr_burst;
assign {hburst_nxt, burst_ctr_nxt} =
spl_ret_cyc_1  ? {hburst, burst_ctr}                                           :
pend_split     ? compute_hburst(beat [15:0], haddr[1], hsize[1], mask[1])      :
htrans2_sq_nsq ? compute_hburst(beatx[15:0], haddr[2], hsize[2], mask[2])      :
ui_idle        ? {hburst, burst_ctr}                                           :
recompute_brst ? compute_hburst(beat_ctr_rcmp[15:0], addr_rcmp, x_size, x_mask):
                 {hburst, burst_ctr_nxt_sc};

assign burst_ctr_nxt_sc = hburst == INCR ? burst_ctr :
                          (burst_ctr - (rd_wr ? 'd1 : 'd0));

`FREEAHB_FF({
pend_split,     htrans[0],   haddr[0],   beat_ctr,     burst_ctr, hburst
,htrans[2],     mask[0],     hwdata[0],  hwrite[0],    hsize[0]
},{
pend_split_nxt, htrans0_nxt, haddr0_nxt, beat_ctr_nxt, burst_ctr_nxt, hburst_nxt
,htrans2_nxt,   mask0_nxt,   hwdata0_nxt, hwrite0_nxt, hsize0_nxt
}, clkena_st1)

assign htrans2_nxt = load_htrans                    ? htrans[0] :
                     (~spl_ret_cyc_1 & ~pend_split) ? IDLE      : htrans[2];

// Backup current transaction during SPLIT/RETRY (htrans[2] handled above).

assign clkena_st1_idx2  = clkena_st1 & load_htrans;

`FREEAHB_FF({mask[2], hwdata[2], hwrite[2], hsize[2], haddr[2], beatx},
            {mask[0], hwdata[0], hwrite[0], hsize[0], haddr[0], beat},
            clkena_st1_idx2)

// Pipe Stage 2 (HWDATA)

assign clkena_st2 =  gnt[0] & i_hready;

`FREEAHB_FF(
{hwrite[1], mask[1], hwdata[1], haddr[1], hsize[1], htrans[1], beat},
{hwrite[0], mask[0], hwdata[0], haddr[0], hsize[0], htrans[0], beat_ctr},
clkena_st2)

// Pipe Stage 3 (HRDATA)

assign clkena_st3  =  gnt[1] & i_hready & htrans1_sq_nsq & ~hresp_splt_ret;
assign rd_dav_nxt  = clkena_st3 & ~hwrite[1];
assign rd_rot_nxt  = data_rota('d1, hsize[1]);
assign rd_data_nxt = i_hrdata;

`FREEAHB_FF({rd_data_int, rd_addr_int, rd_rot_int},
            {rd_data_nxt, haddr[1],    rd_rot_nxt},
            clkena_st3)

`FREEAHB_FF(rd_dav_int, rd_dav_nxt, 1'd1)

// Pipe Stage 4 (Output Data)

assign rd_data_fin_nxt = rd_data_int >> rd_rot_int;

`FREEAHB_FF({o_rd_data, o_rd_data_addr},
            {rd_data_fin_nxt, rd_addr_int}, rd_dav_int)

`FREEAHB_FF(o_rd_data_dav, rd_dav_int, 1'd1)

// Error detect.

assign err = ~((beat_ctr >= 'sd0) & (burst_ctr >= 'sd0) & (burst_ctr <= 'sd16));

`FREEAHB_FF(o_err, err, 1'd1)

// EOM
assign unused_ok = |{1'd1,
                     x_wrap
                    };
endmodule : ahb_manager

// -----------------------------------------------------------------------------
// END OF FILE
// -----------------------------------------------------------------------------
