#  Copyright (C) 2017-2024 Revanth Kamaraj
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

.PHONY: sim clean lint

waves: obj/ahb_master.vcd 
	gtkwave obj/ahb_master.vcd	

sim: obj/ahb_master.vcd

clean:
	rm -rf obj

lint:
	verilator --lint-only src/rtl/ahb_master_pack.sv src/rtl/ahb_master.sv \
    src/rtl/ahb_master_top.sv src/rtl/ahb_master_skid_buffer.sv
	svlint src/rtl/ahb_master_pack.sv src/rtl/ahb_master.sv src/rtl/ahb_master_top.sv src/rtl/ahb_master_skid_buffer.sv 

obj/ahb_master.vcd: obj/ahb_master.out
	cd obj ; ./ahb_master.out

obj/ahb_master.out: src/rtl/ahb_master_pack.sv src/rtl/ahb_master.sv src/rtl/ahb_master_top.sv src/rtl/ahb_master_skid_buffer.sv src/testbench/tb.sv
	mkdir -p obj
	iverilog -g2012 src/rtl/ahb_master_pack.sv src/rtl/ahb_master.sv src/rtl/ahb_master_top.sv src/rtl/ahb_master_skid_buffer.sv \
    src/testbench/tb.sv -o obj/ahb_master.out

