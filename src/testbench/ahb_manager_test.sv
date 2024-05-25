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

package tb_pack;
typedef enum logic [2:0] {SINGLE, INCR=3'd1, INCR4=3'd3, INCR8=3'd5, INCR16=3'd7} t_hburst;
typedef enum logic [1:0] {IDLE, BUSY, NONSEQ, SEQ} t_htrans;
typedef enum logic [2:0] {W8, W16, W32, W64, W128, W256, W512, W1024} t_hsize;
typedef enum logic [1:0] {OKAY, ERROR, SPLIT, RETRY} t_hresp;
endpackage

module ahb_manager_test import tb_pack::*; (input  i_hclk, output logic sim_err = 1'd0, output logic sim_err1 = 1'd0,
                                            output logic sim_ok = 1'd0);

parameter DATA_WDT  = 32;
parameter MAX_LEN   = 8;
parameter MIN_LEN   = 4;
parameter BASE_ADDR = 'h100;

localparam MEM_SIZE = MAX_LEN;
localparam BEAT_WDT = 16;

bit                    i_hreset_n;
logic                  o_err;
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

ahb_manager #(
    .DATA_WDT(DATA_WDT),
    .t_hburst(t_hburst),
    .t_htrans(t_htrans),
    .t_hsize(t_hsize),
    .t_hresp(t_hresp)
) u_ahb_manager
(
    .*,
    .o_rd_data(o_data),
    .o_rd_data_dav(o_dav),
    .o_rd_data_addr(o_addr),
    .i_wr_data(i_data),
    .o_stall(stall_tmp),
    .i_first_xfer(i_first_xfer)
);

ahb_subordinate_sim #(
    .DATA_WDT(DATA_WDT),
    .MEM_SIZE(MEM_SIZE)
) u_ahb_sub_sim (
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

t_htrans             htrans0, htrans1, htrans2;
t_hsize              hsize0, hsize1, hsize2;
logic [DATA_WDT-1:0] hwdata0, hwdata1, hwdata2;
logic [31:0]         mask0, mask1, mask2;
logic [31:0]         haddr0, haddr1, haddr2;
enum {START, LIFT_RESET, DRV_FIRST_CMD, DRIVE_OTHER_CMD, WR_TO_IDLE, RD_TO_IDLE, FINISH} sequencer = START;
int ctr, ctr1, i, rd_cycles;

assign {htrans2, htrans1, htrans0} = {u_ahb_manager.htrans[2], u_ahb_manager.htrans[1], u_ahb_manager.htrans[0]};
assign {hsize2,  hsize1,  hsize0}  = {u_ahb_manager.hsize[2],  u_ahb_manager.hsize[1],  u_ahb_manager.hsize[0]};
assign {hwdata2, hwdata1, hwdata0} = {u_ahb_manager.hwdata[2], u_ahb_manager.hwdata[1], u_ahb_manager.hwdata[0]};
assign {mask2,   mask1,   mask0}   = {u_ahb_manager.mask[2],   u_ahb_manager.mask[1],   u_ahb_manager.mask[0]};
assign {haddr2,  haddr1,  haddr0}  = {u_ahb_manager.haddr[2],  u_ahb_manager.haddr[1],  u_ahb_manager.haddr[0]};

always @ (posedge i_hclk or negedge i_hreset_n)
begin
    if(i_hreset_n) // OK to do because this is an assertion.
    begin
        assert(!o_err) else $fatal(2, "Device internal error occured.");
    end

    if ( i_hreset_n && o_dav ) // OK to do because this is an assertion.
    begin
        rd_cycles <= rd_cycles + 'd1;

        assert(o_data + BASE_ADDR == o_addr)
            $display("OK! Data check passed! o_data=0x%x o_addr=0x%x BASE_ADDR=0x%x",
            o_data, o_addr, BASE_ADDR);
        else
        begin
            $display(2, "Data comparison mismatch. o_data=0x%x o_addr=0x%x BASE_ADDR=0x%x",
            o_data, o_addr, BASE_ADDR);

            sim_err <= 1'd1;
            $finish;
        end
    end

    if ( rd_cycles == MAX_LEN )
    begin
        sim_ok <= 1'd1;
        $finish;
    end
end

always @ (posedge i_hclk)
begin
    i_hgrant <= o_hbusreq ? $random : 'd0;
    rand_sel <= $random;
end

initial
begin
    $dumpfile("ahb_manager.vcd");
    $dumpvars;
end

always @ (posedge i_hclk)
begin
        case(sequencer)

        START:
        begin
            i_rd         <= 'd0;
            i_wr         <= 'd0;
            i_first_xfer <= 'd0;
            i_idle       <= 'd1;
            i_hreset_n   <= 'd0;
            sequencer    <= LIFT_RESET;
            ctr          <= 'd0;
        end

        LIFT_RESET:
        begin
            sequencer  <= DRV_FIRST_CMD;
            i_hreset_n <= 1'd1;
            i          <= 1'd0;
        end

        DRV_FIRST_CMD:
        begin
            if ( o_next )
            begin
                i_addr        <= BASE_ADDR;
                i_min_len     <= MIN_LEN;
                i_wr          <= i == 0 ? 1'd1 : 1'd0;
                i_rd          <= i == 0 ? 1'd0 : 1'd1;
                i_first_xfer  <= 1'd1;
                i_data        <= i == 0 ? 0 : 'dx;
                i_idle        <= 1'd0;
                sequencer     <= DRIVE_OTHER_CMD;
                dat           <= 'd1;
                dav           <= $random;
            end
        end

        DRIVE_OTHER_CMD:
        begin
            if ( o_next )
            begin
                if (dat < MAX_LEN)
                begin
                    dat <= dat + dav; // This is TB, so this is OK.
                    dav <= $random;   // This is TB, so this is OK.

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
                end
                else
                begin
                    sequencer     <= i == 0 ? WR_TO_IDLE : RD_TO_IDLE;
                    i_rd          <= 1'd0;
                    i_wr          <= 1'd0;
                    i_first_xfer  <= 1'd0;
                    i_idle        <= 1'd1;
                    ctr           <= 'd0;
                end
            end
        end

        WR_TO_IDLE:
        begin
            ctr         <= ctr + 'd1;
            sequencer   <= ctr == 'd100 ? DRV_FIRST_CMD : WR_TO_IDLE;
            i           <= 1'd1;
        end

        RD_TO_IDLE:
        begin
            ctr         <= ctr + 'd1;
            sequencer   <= ctr == 'd100 ? FINISH : RD_TO_IDLE;
        end

        FINISH:
        begin
            // Wait.
        end

        endcase
end

always @ (posedge i_hclk)
begin
    ctr1 <= ctr1 + 'd1;

    if(ctr1 == MAX_LEN * 1000)
    begin
        $display("Too many clock cycles elapsed!");
        sim_err1 <= 1'd1;
        $finish;
    end
end

endmodule

module ahb_subordinate_sim import tb_pack::*; #(
parameter DATA_WDT = 32,
parameter MEM_SIZE=256
)(
input                   i_hclk,
input                   i_hreset_n,
input t_hburst          i_hburst,
input t_htrans          i_htrans,
input [31:0]            i_hwdata,
input [31:0]            i_haddr,
input                   i_hwrite,
input                   i_hgrant,
input [2:0]             i_lfsr,

output logic [31:0]       o_hrdata,
output logic              o_hready,
output       t_hresp      o_hresp
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

