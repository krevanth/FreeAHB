//
// (C) 2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//

#include <memory>
#include <verilated.h>
#include "Vahb_manager_test.h"
#include <stdio.h>
#include <string.h>

int err = 0;

// Just a standard Verilator template to drive clock.
int main(int argc, char **argv, char** env) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    contextp->debug(0);
    contextp->randReset(2);
    contextp->traceEverOn(true);

	const std::unique_ptr<Vahb_manager_test> ahb_manager_test{new Vahb_manager_test{contextp.get(), "AHB_MANAGER_TEST"}};

	while(!contextp->gotFinish()) {
        contextp->timeInc(1);
		ahb_manager_test->i_hclk = !ahb_manager_test->i_hclk;
		ahb_manager_test->eval();

        if(ahb_manager_test->sim_ok) {
            err = 0;
            printf("Simulation passed!\n");
        }
        else if(ahb_manager_test->sim_err || ahb_manager_test->sim_err1) {
            err = 1;
            printf("Simulation failed!\n");
        }
	}

    ahb_manager_test->final();

    if(err == 0) {
        exit(EXIT_SUCCESS);
    }
    else {
        exit(EXIT_FAILURE);
    }
}
