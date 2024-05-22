# FreeAHB

Copyright (C) 2017-2024 by Revanth Kamaraj (revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## About

This is the official FreeAHB repo. The repository provides an AHB 2.0 Master 
which supports the AHB protocol standard 2.0 including SPLIT/RETRY support. 
Please note that WRAP type transfer is not supported i.e., the AHB master 
cannot issue WRAP transfers.

## What happened to the repo and it's forks ?

The repo https://github.com/krevanth/freeahb was detached from its forks (as 
an unintended consequence) when the repo was made private and was then deleted 
from GitHub. The repo has now been restored at the same URL as before i.e., 
https://github.com/krevanth/freeahb and those who have forked the repo before 
are encouraged to make a new fork based on https://github.com/krevanth/freeahb. 
Apologies for the inconvenience caused.

Unfortunately, the issue history and the list of the repo's forks could not be 
restored.

## Installing Tools
`sudo apt install iverilog verilator cargo gtkwave`

`cargo install svlint`

## Make Targets
`make sim` will run the included test and open the VCD in GTKWave. Simulation 
files are created in the `obj` directory.

`make clean` will remove the `obj` directory created due to the above.

`make lint` will run linting on the RTL.

## How to Use
The file `ahb_master_top.sv` is the top level AHB master module. Please compile 
all the files in `src/rtl` in order to use the AHB master. Instructions to use 
the UI are included in the header comments of the top module.

