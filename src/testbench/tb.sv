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

// THIS IS TESTBENCH CODE. NOT FOR SYNTHESIS.

module tb;

parameter DATA_WDT = 32;
parameter MAX_LEN  = 8; // > MIN_LEN
parameter MIN_LEN  = 4;

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
logic                  o_next;       // UI must change only if this is 1.
logic   [DATA_WDT-1:0] i_data;       // Data to write. Can change during burst if o_next = 1.
bit      [31:0]        i_addr;       // Base address of burst.
t_hsize                i_size = W8;  // Size of transfer. Like hsize.
bit      [31:0]        i_mask;
bit                    i_wr;         // Write to AHB bus.
bit                    i_rd;         // Read from AHB bus.
bit     [BEAT_WDT-1:0] i_min_len;    // Minimum guaranteed length of burst.
bit                    i_first_xfer; // First transfer.
bit                    i_idle;
logic[DATA_WDT-1:0]    o_data;       // Data got from AHB is presented here.
logic[31:0]            o_addr;       // Corresponding address is presented here.
logic                  o_dav;        // Used as o_data valid indicator.
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
assign hwdata0 = u_ahb_manager_top.o_hwdata[0];
assign hwdata1 = u_ahb_manager_top.o_hwdata[1];

ahb_manager_top #(.DATA_WDT(DATA_WDT)) u_ahb_manager_top
(
    .*,
    .i_wr_data(i_data), .o_stall(stall_tmp),
    .i_first_xfer(i_first_xfer)
);

ahb_subordinate_sim   #(.DATA_WDT(DATA_WDT), .MEM_SIZE(MEM_SIZE)) u_ahb_sub_sim (
    .i_hclk         (i_hclk),
    .i_hreset_n     (i_hreset_n),
    .i_hburst       (o_hburst),
    .i_htrans       (o_htrans),
    .i_hwdata       (o_hwdata),
    .i_haddr        (o_haddr),
    .i_hwrite       (o_hwrite),
    .i_hgrant       (i_hgrant),

    .o_hrdata       (i_hrdata),
    .o_hready       (i_hready),
    .o_hresp        (i_hresp)
);

always #10 i_hclk++;

always @ (negedge i_hclk)
begin
    if(o_dav)
    begin
        $display("Read Data = %x Read Address = %x", o_data, o_addr);
        assert(o_data == o_addr) else $fatal(2, "Sim failed.");
    end
end

always @ (posedge i_hclk) i_hgrant <= o_hbusreq ? $random : 'd0; // Simulation Only.

initial begin // Simulation Only.
        $dumpfile("ahb_manager.vcd");
        $dumpvars;

        // Set IDLE for some time.
        i_rd         <= 'd0;
        i_wr         <= 'd0;
        i_first_xfer <= 'd0;
        i_idle       <= 'd1;

        // Reset
        i_hreset_n <= 1'd0;
        d(1);
        i_hreset_n <= 1'd1;

        d(10);

        // Write, then read.
        for(int i=0;i<2;i++)
        begin
            wait_for_next;

            {dat, dav}     = 0;
            i_min_len     <= MIN_LEN;
            i_wr          <= i == 0 ? 1'd1 : 1'd0;
            i_rd          <= i == 0 ? 1'd0 : 1'd1;
            i_first_xfer  <= 1'd1; // First txn.
            i_data        <= i == 0 ? 0 : 'dx;     // First data is 0.
            i_idle        <= 1'd0;

            wait_for_next;

            // Write to the unit as if reading from a FIFO with intermittent
            // FIFO empty conditions shown as dav = 0.
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

            $display("Going to IDLE...");

            // Go to IDLE.
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

endmodule // tb

///////////////////////////////////////////////////////////////////////////////

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

output reg [31:0]       o_hrdata,
output reg              o_hready,
output reg [1:0]        o_hresp

);

reg [MEM_SIZE-1:0][7:0]      mem;
reg [7:0]                    mem_wr_data;
reg [MEM_SIZE-1:0]           mem_wr_en;
reg [$clog2(MEM_SIZE)-1:0]   mem_wr_addr;
reg                          write;
reg [31:0]                   addr;
reg [DATA_WDT-1:0]           data;
reg [2:0]                    rand_sel = 3'd0;
t_htrans                     mode = IDLE;
reg                          hready_int;
bit                          tmp, sub_sel;
t_htrans                     htrans;

wire [7:0] mem0 = mem[0];
wire [7:0] mem1 = mem[1];
wire [7:0] mem2 = mem[2];
wire [7:0] mem3 = mem[3];
wire [7:0] mem4 = mem[4];
wire [7:0] mem5 = mem[5];
wire [7:0] mem6 = mem[6];
wire [7:0] mem7 = mem[7];

assign htrans = i_htrans;

always @ (posedge i_hclk) rand_sel <= $random % 8; // Simulation Only.

always @ (posedge i_hclk) sub_sel  <=  ( i_hgrant & o_hready ) ? 1'd1 :
                                       (~i_hgrant & o_hready ) ? 1'd0 : sub_sel;

always @ (posedge i_hclk)
begin
    if ( sub_sel & (o_hready | ( !o_hready && (o_hresp == SPLIT || o_hresp == RETRY) ) ) )
    begin
        if ( (htrans == IDLE || htrans == BUSY) && o_hready )
        begin
            o_hresp <= OKAY; // Always give OK response.
            mode    <= htrans;
        end
        else if ( htrans == IDLE ) // o_hready == 1'd0
        begin
            o_hresp <= OKAY;
            tmp     <= 1'd0;
        end
        else if ( htrans == SEQ || htrans == NONSEQ )
        begin
            mode <= htrans;

            if ( (o_hresp == SPLIT || o_hresp == RETRY) && !o_hready )
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
            mem      <= 'x;
            o_hrdata <= 'x;
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
                            $display($time, ": %m :: Reading data %x from address %x",
                            mem[i_haddr], i_haddr);
                        end
                end
                else
                begin
                        write <= 1'd0;
                end
        end
end

always @ (posedge i_hclk)
    for(int i=0;i<MEM_SIZE;i++)
        if(mem_wr_en[i])
        begin
            mem[i] <= mem_wr_data;
            $display($time, ": %m :: Writing data %x to address %x", mem_wr_data, i);
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
                  ((o_hresp == SPLIT || o_hresp == RETRY) && tmp) ? 1'd0 :
                  hready_int;

endmodule // ahb_subordinate_sim

