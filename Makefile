#  Copyright (C) 2017-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
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

.PHONY: sim clean lint runlint runsim

MAKE_THREADS := $(shell getconf _NPROCESSORS_ONLN)
SHELL := /bin/bash -o pipefail
PWD   := $(shell pwd)
TAG   := archlinux/freeahb
DLOAD := "FROM archlinux:latest\n\
          RUN pacman -Syyu --noconfirm cargo make verilator\n\
          RUN cargo install svlint"

DOCKER		 := docker run --interactive --tty --volume $(PWD):$(PWD) --workdir $(PWD) $(TAG)
LOAD_DOCKER  := docker image ls | grep $(TAG) || echo -e $(DLOAD) | docker build --no-cache --rm --tag $(TAG) -

###############################################################################
# User Accessible Targets
###############################################################################

.DEFAULT_GOAL = sim

clean:
	$(LOAD_DOCKER)
	$(DOCKER) rm -rfv obj/ obj_dir/ || exit 10

lint:
	$(LOAD_DOCKER)
	$(DOCKER) $(MAKE) -j $(MAKE_THREADS) runlint || exit 10

sim:
	$(LOAD_DOCKER)
	$(DOCKER) $(MAKE) runsim || exit 10

reset: clean
	docker image ls | grep $(TAG) && docker image rmi -- force $(TAG)

###############################################################################
# Internal Targets
###############################################################################

runlint: lt0 lt1 lt2 lt3 lt4 lt5 lt6 lt7 lt8

lt0:
	verilator -GDATA_WDT=8 --lint-only src/rtl/ahb_manager.sv 

lt1:
	verilator -GDATA_WDT=16 --lint-only src/rtl/ahb_manager.sv 

lt2:
	verilator -GDATA_WDT=32 --lint-only src/rtl/ahb_manager.sv 

lt3:
	verilator -GDATA_WDT=64 --lint-only src/rtl/ahb_manager.sv 

lt4:
	verilator -GDATA_WDT=128 --lint-only src/rtl/ahb_manager.sv 

lt5:
	verilator -GDATA_WDT=256 --lint-only src/rtl/ahb_manager.sv 

lt6:
	verilator -GDATA_WDT=512 --lint-only src/rtl/ahb_manager.sv 

lt7:
	verilator -GDATA_WDT=1024 --lint-only src/rtl/ahb_manager.sv 

lt8:
	/root/.cargo/bin/svlint src/rtl/ahb_manager.sv 

runsim: runcompile
	mkdir -p obj/
	cd obj ; ./Vahb_manager_test

runcompile:
	mkdir -p obj/
	verilator -O3 -j $(MAKE_THREADS) --threads $(MAKE_THREADS) --cc --Wno-lint --cc --exe \
    --assert --build ../src/testbench/ahb_manager_test.cpp --Mdir obj/ --top \
    ahb_manager_test -Isrc/rtl src/rtl/*.sv -Iobj/ src/testbench/*.sv --trace --x-assign unique \
	--x-initial unique --error-limit 1 

