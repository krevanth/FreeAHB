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

module tb;

parameter DATA_WDT  = 32;
parameter MAX_LEN   = 8;
parameter MIN_LEN   = 4;
parameter BASE_ADDR = 'h100;

localparam MEM_SIZE = MAX_LEN;

import ahb_manager_pack::*;

localparam BEAT_WDT = 16;

bit                    i_hclk;
bit                    i_hreset_n;
logic [31:0]           o_haddr;
t_hburst               o_hburst;
t_htrans               o_htrans;
logic[DATA_WDT-1:0]    o_hwdata;
logic                  o_hwrite;
t_hsize                o_hsize;
logic [DATA_WDT-1:0]   i_hrdata;
logic                  i_hready;
t_hresp                i_hresp;
logic                  i_hgrant;
logic                  o_hbusreq;
logic                  o_next;
logic   [DATA_WDT-1:0] i_data;
bit      [31:0]        i_addr;
t_hsize                i_size = W8;
bit      [31:0]        i_mask;
bit                    i_wr;
bit                    i_rd;
bit     [BEAT_WDT-1:0] i_min_len;
bit                    i_first_xfer;
bit                    i_idle;
logic[DATA_WDT-1:0]    o_data;
logic[31:0]            o_addr;
logic                  o_dav;
bit                    dav;
bit [31:0]             dat;

`define STRING logic [256*8-1:0]

`STRING HBURST;
`STRING HTRANS;
`STRING HSIZE;
`STRING HRESP;

always @*
begin
        case(o_hburst)
        INCR:   HBURST = "INCR";
        INCR4:  HBURST = "INCR4";
        INCR8:  HBURST = "INCR8";
        INCR16: HBURST = "INCR16";
        default:HBURST = "<----?????--->";
        endcase

        case(o_htrans)
        SINGLE: HTRANS = "IDLE";
        BUSY:   HTRANS = "BUSY";
        SEQ:    HTRANS = "SEQ";
        NONSEQ: HTRANS = "NONSEQ";
        default:HTRANS = "<----?????--->";
        endcase

        case(i_hresp)
        OKAY:   HRESP = "OKAY";
        ERROR:  HRESP = "ERROR";
        SPLIT:  HRESP = "SPLIT";
        RETRY:  HRESP = "RETRY";
        default: HRESP = "<---?????---->";
        endcase

        case(o_hsize)
        W8  : HSIZE = "8BIT";
        W16 : HSIZE = "16BIT";
        W32 : HSIZE = "32BIT";
        W64 : HSIZE = "64BIT";
        W128: HSIZE = "128BIT";
        W256: HSIZE = "256BIT";
        W512: HSIZE = "512BIT";
        W1024 : HSIZE = "1024BIT";
        default : HSIZE = "<---?????--->";
        endcase
end

logic stall_tmp;
logic [2:0] rand_sel;

assign o_next  = ~stall_tmp;

ahb_manager_top #(.DATA_WDT(DATA_WDT)) u_ahb_manager_top
(
    .*,
    .o_rd_data(o_data),
    .o_rd_data_dav(o_dav),
    .o_rd_data_addr(o_addr),
    .i_wr_data(i_data), .o_stall(stall_tmp),
    .i_first_xfer(i_first_xfer)
);

ahb_subordinate_sim   #(.DATA_WDT(DATA_WDT), .MEM_SIZE(MEM_SIZE)) u_ahb_sub_sim (
    .i_hclk         (i_hclk),
    .i_hreset_n     (i_hreset_n),
    .i_hburst       (o_hburst),
    .i_htrans       (o_htrans),
    .i_hwdata       (o_hwdata),
    .i_haddr        (o_haddr - BASE_ADDR),
    .i_hwrite       (o_hwrite),
    .i_hgrant       (i_hgrant),
    .i_lfsr         (rand_sel),

    .o_hrdata       (i_hrdata),
    .o_hready       (i_hready),
    .o_hresp        (i_hresp)
);

always #10 i_hclk++;

always @ (posedge i_hclk)
    assert(!o_dav || !i_hreset_n || (o_data + BASE_ADDR == o_addr))
    else $fatal(2, "Data comparison mismatch.");

always @ (posedge i_hclk)
begin
    i_hgrant <= o_hbusreq ? $random : 'd0;
    rand_sel <= $random;
end

initial begin
        $dumpfile("ahb_manager.vcd");
        $dumpvars;

        i_rd         <= 'd0;
        i_wr         <= 'd0;
        i_first_xfer <= 'd0;
        i_idle       <= 'd1;
        i_hreset_n   <= 'd0;

        d(1);

        i_hreset_n   <= 1'd1;

        d(10);

        for(int i=0;i<2;i++)
        begin
            wait_for_next;

            {dat, dav}     = 0;

            i_addr        <= BASE_ADDR;
            i_min_len     <= MIN_LEN;
            i_wr          <= i == 0 ? 1'd1 : 1'd0;
            i_rd          <= i == 0 ? 1'd0 : 1'd1;
            i_first_xfer  <= 1'd1;
            i_data        <= i == 0 ? 0 : 'dx;
            i_idle        <= 1'd0;

            wait_for_next;

            while(dat < MAX_LEN - 1)
            begin
                    dav = $random;
                    dat = dat + dav;

                    i_first_xfer <= 1'd0;

                    if ( i == 0 )
                    begin
                        i_wr   <= dav;
                        i_data <= dav ? dat : 32'dx;
                    end
                    else
                    begin
                        i_rd   <= dav;
                        i_wr   <= 'd0;
                        i_data <= 'x;
                    end

                    wait_for_next;
            end

            i_rd          <= 1'd0;
            i_wr          <= 1'd0;
            i_first_xfer  <= 1'd0;
            i_idle        <= 1'd1;

            d(10);
        end

        d(100);

        $display("Normal end of sim");
        $finish;
end

initial
begin
    d(10000);
    $fatal(2, "Simulation hang.");
end

task wait_for_next;
        d(1);
        while(o_next !== 1) d(1);
endtask

task d(int x);
        repeat(x)
        @(posedge i_hclk);
endtask

endmodule

module ahb_subordinate_sim

import ahb_manager_pack::*;

#(parameter DATA_WDT = 32, parameter MEM_SIZE=256)

(

input                   i_hclk,
input                   i_hreset_n,
input [2:0]             i_hburst,
input [1:0]             i_htrans,
input [31:0]            i_hwdata,
input [31:0]            i_haddr,
input                   i_hwrite,
input                   i_hgrant,
input [2:0]             i_lfsr,

output logic [31:0]       o_hrdata,
output logic              o_hready,
output logic [1:0]        o_hresp

);

logic [MEM_SIZE-1:0][7:0]    mem;
logic [7:0]                  mem_wr_data;
logic [MEM_SIZE-1:0]         mem_wr_en;
logic [$clog2(MEM_SIZE)-1:0] mem_wr_addr;
logic                        write;
logic [31:0]                 addr;
logic [DATA_WDT-1:0]         data;
logic [2:0]                  rand_sel;
t_htrans                     mode;
logic                        hready_int;
logic                        tmp, sub_sel;
t_htrans                     htrans;

assign htrans = i_htrans;
assign rand_sel = i_lfsr;

always @ (posedge i_hclk or negedge i_hreset_n)
begin
    if(!i_hreset_n)
        sub_sel <= 'd0;
    else
         sub_sel  <=  ( i_hgrant & o_hready ) ? 1'd1 :
                      (~i_hgrant & o_hready ) ? 1'd0 : sub_sel;
end

always @ (posedge i_hclk or negedge i_hreset_n)
begin
    if(!i_hreset_n)
    begin
        tmp     <= 1'd0;
        mode    <= IDLE;
        o_hresp <= OKAY;
    end
    else if ( sub_sel & (o_hready | ( !o_hready && (o_hresp == SPLIT || o_hresp == RETRY) ) ) )
    begin
        if ( (htrans == IDLE || htrans == BUSY) && o_hready )
        begin
            o_hresp <= OKAY;
            mode    <= htrans;
        end
        else if ( htrans == IDLE && !o_hready )
        begin
            o_hresp <= OKAY;
            tmp     <= 1'd0;
        end
        else if ( htrans == SEQ || htrans == NONSEQ )
        begin
            mode <= htrans;

            if ( (o_hresp == SPLIT || o_hresp == RETRY || o_hresp == ERROR) && !o_hready )
            begin
                o_hresp <= o_hresp;
                tmp     <= 1'd0;
            end
            else if ( o_hready )
            begin
                o_hresp <= rand_sel[1:0] == 'd0 ? OKAY  :
                           rand_sel[1:0] == 'd1 ? ERROR :
                           rand_sel[1:0] == 'd2 ? SPLIT : RETRY;

                if ( rand_sel[1:0] == 'd2 || rand_sel[1:0] == 'd3 ) tmp <= 1'd1;
            end
        end
    end
end

always @ (posedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
        begin
            mem      <= '0;
            o_hrdata <= '0;
            write    <= '0;
        end
        else if ( o_hready )
        begin
                if ( i_htrans == SEQ || i_htrans == NONSEQ )
                begin
                        write <= i_hwrite;
                        addr  <= i_haddr;

                        if ( !i_hwrite )
                        begin
                            o_hrdata <= mem [i_haddr];
                        end
                end
                else
                begin
                        write <= 1'd0;
                end
        end
end

always @ (posedge i_hclk)
begin
    for(int i=0;i<MEM_SIZE;i++)
    begin
        if(mem_wr_en[i])
        begin
            mem[i] <= mem_wr_data;
        end
    end
end

always @*
begin
        mem_wr_en   = 'd0;
        mem_wr_data = 'd0;
        mem_wr_addr = 'd0;

        if ( write && o_hready )
        begin
                mem_wr_en[addr] = 1'd1;
                mem_wr_data     = i_hwdata;
                mem_wr_addr     = addr;
        end
end

always @ (negedge i_hclk or negedge i_hreset_n)
begin
        if ( !i_hreset_n )
                hready_int <= 1'd0;
        else
                hready_int <= rand_sel[2];
end

assign o_hready = sub_sel == 0 ? rand_sel[2] :
                  ((o_hresp == SPLIT || o_hresp == RETRY || o_hresp == ERROR) && tmp) ? 1'd0 :
                  hready_int;

endmodule

