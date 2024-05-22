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

module tb;

import ahb_manager_pack::*;

parameter DATA_WDT = 32;
parameter BEAT_WDT = 32;

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
logic                  o_next;   // UI must change only if this is 1.
logic   [DATA_WDT-1:0] i_data;   // Data to write. Can change during burst if o_next = 1.
bit      [31:0]        i_addr;   // Base address of burst.
t_hsize                i_size = W8;     // Size of transfer. Like hsize.
bit                    i_wr;     // Write to AHB bus.
bit                    i_rd;     // Read from AHB bus.
bit     [BEAT_WDT-1:0] i_min_len;// Minimum guaranteed length of burst.
bit                    i_first_xfer; // First transfer.
bit                    i_idle;
logic[DATA_WDT-1:0]    o_data;   // Data got from AHB is presented here.
logic[31:0]            o_addr;   // Corresponding address is presented here.
logic                  o_dav;    // Used as o_data valid indicator.
bit                    dav;
bit [31:0]             dat;


`define STRING reg [256*8-1:0]

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
        W32 : HSIZE = "32BIT"; // 32-bit
        W64 : HSIZE = "64BIT"; // 64-bit
        W128: HSIZE = "128BIT";
        W256: HSIZE = "256BIT";
        W512: HSIZE = "512BIT";
        W1024 : HSIZE = "1024BIT";
        default : HSIZE = "<---?????--->";
        endcase
end

logic [DATA_WDT-1:0] hwdata0, hwdata1;
logic stall_tmp;

assign o_next  = ~stall_tmp;
assign hwdata0 = U_AHB_MASTER.o_hwdata[0];
assign hwdata1 = U_AHB_MASTER.o_hwdata[1];

ahb_manager_top #(.DATA_WDT(DATA_WDT), .BEAT_WDT(BEAT_WDT)) U_AHB_MASTER
(.*, .i_wr_data(i_data), .o_stall(stall_tmp), .i_first_xfer(i_first_xfer));

ahb_subordinate_sim   #(.DATA_WDT(DATA_WDT)) U_AHB_SLAVE_SIM_1 (

.i_hclk         (i_hclk),
.i_hreset_n     (i_hreset_n),
.i_hburst       (o_hburst),
.i_htrans       (o_htrans),
.i_hwdata       (o_hwdata),
.i_hsel         (1'd1),
.i_haddr        (o_haddr),
.i_hwrite       (o_hwrite),
.i_hready       (1'd1),
.o_hrdata       (i_hrdata),
.o_hready       (i_hready),
.o_hresp        (i_hresp)

);

always #10 i_hclk++;

initial forever
begin
        @ (posedge i_hclk);

        if ( o_hbusreq )
                i_hgrant <= $random;
        else
                i_hgrant <= 1'd0;
end

initial
begin
        $dumpfile("ahb_manager.vcd");
        $dumpvars;

        // Set IDLE for some time.
        i_rd         <= 0;
        i_wr         <= 0;
        i_first_xfer <= 'd0;
        i_idle       <= 1'd1;

        // Reset
        i_hreset_n <= 1'd0;
        d(1);
        i_hreset_n <= 1'd1;

        d(10);

        // Write, then read.
        for(int i=0;i<2;i++)
        begin

            dat = 0;
            dav = 0;

            // We can change inputs at any time.
            // Starting a write burst.
            i_min_len     <= 42;
            i_wr          <= i == 0 ? 1'd1 : 1'd0;
            i_rd          <= i == 0 ? 1'd0 : 1'd1;
            i_first_xfer  <= 1'd1; // First txn.
            i_data        <= i == 0 ? 0 : 'dx;     // First data is 0.
            i_idle        <= 1'd0;

            // Further change requires o_next.
            wait_for_next;

            // Write to the unit as if reading from a FIFO with intermittent
            // FIFO empty conditions shown as dav = 0.
            while(dat < 42)
            begin: bk
                    dav = $random;
                    dat = dat + dav;

                    i_first_xfer <= 1'd0;

                    if ( i == 0 )
                    begin
                        i_wr      <= dav;
                        i_data    <= dav ? dat : 32'dx;
                    end
                    else i_rd <= $random;

                    wait_for_next;
            end

            $display("Going to IDLE...");

            // Go to IDLE.
            i_rd          <= 1'd0;
            i_wr          <= 1'd0;
            i_first_xfer  <= 1'd0;
            i_idle        <= 1'd1;

            d(10);
        end

        d(10);

        $finish;
end

initial
begin
    d(10000);
    $fatal(2, "Simulation hang.");
end

task wait_for_next;
        bit x;
        x = 1'd0;

        d(1);

        while(o_next !== 1)
        begin
                if(x == 0) $display("Waiting...");
                x = 1;
                d(1);
        end
endtask

task d(int x);
        repeat(x)
        @(posedge i_hclk);
endtask

endmodule

module ahb_subordinate_sim #(parameter DATA_WDT = 32, parameter MEM_SIZE=256) (

input                   i_hclk,
input                   i_hreset_n,
input [2:0]             i_hburst,
input [1:0]             i_htrans,
input [31:0]            i_hwdata,
input                   i_hsel,
input [31:0]            i_haddr,
input                   i_hwrite,
output reg [31:0]       o_hrdata,

input                   i_hready,
output reg              o_hready,
output    [1:0]         o_hresp

);

localparam [1:0] IDLE   = 0;
localparam [1:0] BUSY   = 1;
localparam [1:0] NONSEQ = 2;
localparam [1:0] SEQ    = 3;
localparam [1:0] OKAY   = 0;
localparam [1:0] ERROR  = 1;
localparam [1:0] SPLIT  = 2;
localparam [1:0] RETRY  = 3;
localparam [2:0] SINGLE = 0; /* Unused. Done as a burst of 1. */
localparam [2:0] INCR   = 1;
localparam [2:0] WRAP4  = 2;
localparam [2:0] INCR4  = 3;
localparam [2:0] WRAP8  = 4;
localparam [2:0] INCR8  = 5;
localparam [2:0] WRAP16 = 6;
localparam [2:0] INCR16 = 7;
localparam [2:0] BYTE   = 0;
localparam [2:0] HWORD  = 1;
localparam [2:0] WORD   = 2; /* 32-bit */
localparam [2:0] DWORD  = 3; /* 64-bit */
localparam [2:0] BIT128 = 4;
localparam [2:0] BIT256 = 5;
localparam [2:0] BIT512 = 6;
localparam [2:0] BIT1024 = 7;

reg [7:0] mem [MEM_SIZE-1:0];
reg [7:0]  mem_wr_data;
reg [MEM_SIZE-1:0]           mem_wr_en;
reg [$clog2(MEM_SIZE)-1:0]   mem_wr_addr;

reg write, read;
reg [31:0] addr;
reg [DATA_WDT-1:0] data;

assign o_hresp = OKAY;

initial forever
begin
        @(posedge i_hclk or negedge i_hreset_n);

        if ( !i_hreset_n )
        begin
                read  <= 1'd0;
                write <= 1'd0;
        end
        else if ( o_hready && i_hready )
        begin
                if ( i_hsel && (i_htrans == SEQ || i_htrans == NONSEQ) )
                begin
                        write <= i_hwrite;
                        addr  <= i_haddr;
                end
                else
                begin
                        write <= 1'd0;
                end
        end
end

initial forever
begin
        @ (posedge i_hclk && !i_hwrite && o_hready && i_hready );

        if ( i_hsel && (i_htrans == SEQ || i_htrans == NONSEQ) )
        begin
                $display($time, "%m :: Reading data %x from address %x", mem[i_haddr], i_haddr);
                o_hrdata <= mem [i_haddr];
        end
end

for(genvar i=0;i<MEM_SIZE;i++)
    always @ (posedge i_hclk)
        if ( mem_wr_en[i] )
        begin
            $display($time, "%m :: Writing data %x to address %x...", i_hwdata, addr);
            mem [mem_wr_addr] <= mem_wr_data;
        end

always @*
begin
        mem_wr_en = 'd0;
        mem_wr_data = 'd0;
        mem_wr_addr = 'd0;

        if ( write && o_hready )
        begin
                mem_wr_en[addr] = 1'd1;
                mem_wr_data     = i_hwdata;
                mem_wr_addr     = addr;
        end
end

initial forever
begin
        @ (negedge i_hclk or negedge i_hreset_n);

        if ( !i_hreset_n )
                o_hready <= 1'd0;
        else
                o_hready <= $random;
end

endmodule

