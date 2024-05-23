# FreeAHB : An AHB 2.0 Manager

## Authors

### RTL Design

All of the FreeAHB RTL is **Copyright (C) 2017-2024 by [Revanth Kamaraj](https://github.com/krevanth) <<revanth91kamaraj@gmail.com>>**

### Verification

All of the FreeAHB test code is **Copyright (C) 2017-2024 by [Revanth Kamaraj](https://github.com/krevanth) <<revanth91kamaraj@gmail.com>>**

## Notice

The repo https://github.com/krevanth/FreeAHB is the official FreeAHB repo. The repository provides an AHB 2.0 Manager.

### What happened to the repo and it's forks ?

The repo https://github.com/krevanth/FreeAHB was detached from its forks (as
an unintended consequence) when the repo was made private and was then deleted
from GitHub. The repo has now been restored from a combination of local backups
and downstream forks (i.e., online backups) and is now at the same URL as
before i.e., https://github.com/krevanth/FreeAHB and those who have forked the
repo before are encouraged to make a new fork based on
https://github.com/krevanth/FreeAHB. Apologies for the inconvenience caused.

Unfortunately, the issue history and the list of the repo's forks could not be
restored.

## Compatibility

Other than WRAP transfers, all features of the AHB 2.0 specification are supported including
SPLIT/RETRY capability.

## Limitations

- No support for SPLIT/RETRY capability.
- Maximum burst command sequence length per burst is limited to 64K beats.

## License

**Copyright (C) 2017-2024 by [Revanth Kamaraj](https://github.com/krevanth) <<revanth91kamaraj@gmail.com>>**

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

## System Integration

- The file `ahb_manager_top.sv` is the top level AHB manager module.
- Please compile all the files in `src/rtl` in order to use the AHB manager.
- Instructions to use the UI are included in the `ahb_manager_top.sv` file near the UI ports itself.
- Running the provided testcase will provide a sample illustration of how the UI should be used.

### Parameters

`DATA_WDT` specifies the width of the data busses. This is 32 by default. You
can specify upto 1024 here. Valid values are 32, 64, 128, 256, 512 and 1024.

### Ports

#### AHB Interface

|  Port    |  IO| Width  | Description            |
|----------|----|--------|------------------------|
|i_hclk    |I   |1       |Standard AHB 2.0 signal.|
|i_hreset_n|I   |1       |Standard AHB 2.0 signal.|
|o_haddr   |I   |32      |Standard AHB 2.0 signal.|
|o_hburst  |O   |3       |Standard AHB 2.0 signal.|
|o_htrans  |O   |2       |Standard AHB 2.0 signal.|
|o_hwdata  |O   |DATA_WDT|Standard AHB 2.0 signal.|
|o_hwrite  |O   |1       |Standard AHB 2.0 signal.|
|o_hsize   |O   |3       |Standard AHB 2.0 signal.|
|i_hrdata  |I   |DATA_WDT|Standard AHB 2.0 signal.|
|i_hready  |I   |1       |Standard AHB 2.0 signal.|
|i_hresp   |I   |2       |Standard AHB 2.0 signal.|
|i_hgrant  |I   |1       |Standard AHB 2.0 signal.|
|o_hbusreq |O   |1       |Standard AHB 2.0 signal.|

#### User Interface

|Port         |IO   |Width   |Description                                                                                                                                                                                                    |
|-------------|-----|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|o_stall      |O    |1       |No UI signals (i_\*) are allowed to change when this is 1.                                                                                                                                                      |
|i_idle       |I    |1       |Use this to the signal to the UI that no burst is going on. Do not assert during an ongoing burst command sequence. Expected to be 1 after entire burst command sequence has been sent to the AHB manager. Out of reset, keep i_idle=1 for atleast 1 cycle.     |
|i_wr_data    |I    |DATA_WDT|Data to be written. May change every cycle during the burst command sequence.                                                                                                                                  |
|i_addr       |I    |32      |Supply base address of the burst here. Should be held constant throughout the burst command sequence.                                                                                                          |
|i_size       |I    |3       |Plays a similar role to HSIZE. Should be held constant through the burst command sequence.                                                                                                                     |
|i_wr         |I    |1       |Indicates a write burst command sequnce. Can be gapped in the middle of the write burst command sequence to throttle i_wr_data getting into the AHB master.                                                    |
|i_rd         |I    |1       |Indicates a read burst command sequence. Can be gapped in the middle of the read burst command sequence to pause read data coming out the AHB master.                                                          |
|i_min_len    |I    |16      |Specify the minimum number of beats in the burst command sequence. The actual burst command sequence can be longer but cannot be shorter than this. Hold throughout the burst command sequence.                |
|i_first_xfer |I    |1       |When new UI signals are setup for a new burst, make this 1 for the first beat. Make it 0 for the rest of the burst command sequence. When 1, ensure i_rd=1 or i_wr=1.                                          |
|o_data       |O    |DATA_WDT|Requested read data is present out in an in-order sequence decoupled from the command: it can come after the read command sequence has been fed into the AHB master completely and i_idle=1 after the sequence.|
|o_addr       |O    |32      |Associated address corresponding to the read data presented on the above port.                                                                                                                                 |
|o_dav        |O    |1       |Qualifies the above two signals when 1.                                                                                                                                                                        |

## Project Environment

### Installing Tools

The FreeAHB project requires several tools to be installed locally at your site.
Please execute the following commands to install the required tools. The project
assumes you are using a Linux based system.

`sudo apt install iverilog verilator cargo gtkwave`

`cargo install svlint`

### Make Targets

Enter the project's root directory and enter one of the following commands:

`make sim` will run the included test and open the VCD in GTKWave. Simulation 
files are created in the `obj` directory.

`make clean` will remove the `obj` directory created due to the above.

`make lint` will run linting on the RTL.


