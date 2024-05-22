//  Copyright (C) 2017 Revanth Kamaraj
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

module ahb_manager import ahb_manager_pack::*; #(parameter DATA_WDT = 32, parameter BEAT_WDT = 32) (

        // AHB
        input   logic                   i_hclk,
        input   logic                   i_hreset_n,
        output  logic [31:0]            o_haddr,
        output  t_hburst                o_hburst,
        output  t_htrans                o_htrans,
        output  logic [DATA_WDT-1:0]    o_hwdata,
        output  logic                   o_hwrite,
        output  t_hsize                 o_hsize,
        input   logic [DATA_WDT-1:0]    i_hrdata,
        input   logic                   i_hready,
        input   t_hresp                 i_hresp,
        input   logic                   i_hgrant,
        output  logic                   o_hbusreq,

        // UI
        output logic                o_next,   // UI must change only if this is 1.
        input  logic [DATA_WDT-1:0] i_data,   // Data to write. Can change during burst if o_next = 1.
        input  logic                i_dav,    // Data to write valid. Can change during burst if o_next = 1.
        input  logic  [31:0]        i_addr,   // Base address of burst.
        input  t_hsize              i_size,   // Size of transfer. Like hsize.
        input  logic                i_wr,     // Write to AHB bus.
        input  logic                i_rd,     // Read from AHB bus.
        input  logic [BEAT_WDT-1:0] i_min_len,// Minimum guaranteed length of burst.
        input  logic                i_cont,   // Current transfer continues previous one.
        output logic [DATA_WDT-1:0] o_data,   // Data got from AHB is presented here.
        output logic [31:0]         o_addr,   // Corresponding address is presented here.
        output logic                o_dav     // Used as o_data valid indicator.
);

logic [4:0]                burst_ctr;
logic [BEAT_WDT-1:0]       beat_ctr;
logic [1:0]                gnt;
t_hburst                   hburst;
t_htrans                   htrans [2];
t_hsize                    hsize  [2];
logic [1:0]                hwrite;
logic [1:0][DATA_WDT-1:0]  hwdata;
logic [1:0][31:0]          haddr ;
logic [BEAT_WDT-1:0]       beat;
logic                      pend_split;
logic [BEAT_WDT-1:0]       beat_ctr_sc, beat_ctr_nxt;

wire spl_ret_cyc_1   = gnt[1] & ~i_hready & (i_hresp == SPLIT || i_hresp == RETRY);
wire rd_wr           = i_rd | (i_wr & i_dav);
wire b1k_spec        = (haddr[0] + ('d1 << i_size)) >> 'd10 != {10'd0, haddr[0][31:10]};
wire term_bc         = (burst_ctr == 'd1) & (o_hburst != INCR);
wire first_xfer      = ~i_cont & rd_wr;
wire htrans_idle     = htrans[0] == IDLE;
wire rcmp_brst_sc    = |{first_xfer, ~gnt[0], term_bc, htrans_idle, b1k_spec};
wire rcmp_brst       = (htrans[0] != BUSY) & rcmp_brst_sc;
wire [31:0] addr_arg = ~i_cont ? i_addr : haddr[0] + ({31'd0, rd_wr} << i_size);
wire ui_idle         = ~i_cont & ~i_rd & ~i_wr;
assign o_next        = ( i_hready & i_hgrant & ~pend_split ) | ui_idle | ( i_wr & ~i_dav );
assign beat_ctr_sc   = (hburst == INCR ? beat_ctr : (beat_ctr - (rd_wr ? 'd1 : 'd0)));
assign beat_ctr_nxt  = ~i_cont ? i_min_len : beat_ctr_sc;

assign {o_haddr, o_hburst, o_htrans, o_hwdata, o_hwrite, o_hsize} =
       {haddr[0], hburst, htrans[0], hwdata[1], hwrite[0], hsize[0]};

always_ff @ (posedge i_hclk or negedge i_hreset_n)
        if ( !i_hreset_n )        gnt <= 2'd0;
        else if ( spl_ret_cyc_1 ) gnt <= 2'd0; // A split retry cycle 1 will invalidate the pipeline.
        else if ( i_hready )      gnt <= {gnt[0], i_hgrant};

always_ff @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n ) o_hbusreq <= 1'd0;
        else               o_hbusreq <= i_rd | i_wr | i_cont;
end

always_ff @ (posedge i_hclk or negedge i_hreset_n) // Address phase stage 1.
        if ( !i_hreset_n )
        begin
            htrans[0]  <= IDLE;
            pend_split <= 1'd0;
        end
        else if ( spl_ret_cyc_1 ) // Split retry cycle 1.
        begin
            htrans[0]  <= IDLE;
            pend_split <= 1'd1;
        end
        else if ( i_hready & i_hgrant )
        begin
            pend_split <= 1'd0;

            if ( pend_split ) // Perform pipeline rollback.
            begin
                {hwdata[0], hwrite[0], hsize[0], haddr[0]} <= {hwdata[1], hwrite[1], hsize[1], haddr[1]};
                htrans[0]                                  <= NONSEQ;
                {hburst, burst_ctr}                        <= compute_hburst(beat, haddr[1], hsize[1]);
                beat_ctr                                   <= beat;
            end
            else
            begin
                 {hwdata[0], hwrite[0], hsize[0]} <= {i_data, i_wr, i_size};

                if ( ~i_cont & ~rd_wr )
                begin
                         htrans[0] <= IDLE;
                end
                else if ( rcmp_brst ) // Recompute burst properties
                begin
                        haddr[0]            <= !i_cont ? i_addr : haddr[0] + ({31'd0, rd_wr} << i_size);
                        htrans[0]           <= rd_wr ? NONSEQ : IDLE;
                        {hburst, burst_ctr} <= compute_hburst ( beat_ctr_nxt, addr_arg, i_size );
                        beat_ctr            <= beat_ctr_nxt;
                end
                else
                begin   // We are in a normal burst. No need to change HBURST.
                        haddr[0]  <= haddr[0] + ((htrans[0] != BUSY ? 'd1 : 'd0) << i_size);
                        htrans[0] <= rd_wr ? SEQ : BUSY;
                        burst_ctr <= o_hburst == INCR ? burst_ctr : (burst_ctr - (rd_wr ? 'd1 : 'd0));
                        beat_ctr  <= o_hburst == INCR ? beat_ctr  : (beat_ctr  - (rd_wr ? 'd1 : 'd0));
                end
            end
        end

always_ff @ (posedge i_hclk or negedge i_hreset_n) // HWDATA phase. Stage II.
        if ( !i_hreset_n ) {hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1], beat} <= 'x;
        else if ( i_hready & gnt[0] )
        begin
                {hwdata[1], haddr[1], hwrite[1], hsize[1], htrans[1], beat} <=
                {hwdata[0], haddr[0], hwrite[0], hsize[0], htrans[0], beat_ctr};
        end

always_ff @ (posedge i_hclk or negedge i_hreset_n) // HRDATA phase. Stage III.
        if ( !i_hreset_n )
        begin
                o_dav  <= 1'd0;
                o_data <= 'dx;
                o_addr <= 'dx;
        end
        else if ( gnt[1] & i_hready & (htrans[1] == SEQ || htrans[1] == NONSEQ) )
        begin
                o_dav  <= ~hwrite[1];
                o_data <=  i_hrdata;
                o_addr <=  haddr[1];
        end
        else o_dav <= 1'd0;

function automatic [7:0] compute_hburst (input [BEAT_WDT-1:0] val, input [31:0] addr, input [2:0] sz);
        compute_hburst = (val > 15 && no_cross(addr, 15, sz)) ? {INCR16, 5'd16} :
                         (val > 7  && no_cross(addr, 7,  sz)) ? {INCR8 , 5'd8}  :
                         (val > 3  && no_cross(addr, 3,  sz)) ? {INCR4 , 5'd4}  : {INCR, 5'd0};
endfunction

function automatic no_cross(input [31:0] addr, input [31:0] val, input [2:0] sz);
        no_cross = !( addr + (val << (1 << sz )) >> 10 != {10'd0, addr[31:10]} );
endfunction

endmodule : ahb_manager
