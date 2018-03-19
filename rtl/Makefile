###############################################################################
#                                                                             #
# Copyright 2016 myStorm Copyright and related                                #
# rights are licensed under the Solderpad Hardware License, Version 0.51      #
# (the “License”); you may not use this file except in compliance with        #
# the License. You may obtain a copy of the License at                        #
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable       #
# law or agreed to in writing, software, hardware and materials               #
# distributed under this License is distributed on an “AS IS” BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or             #
# implied. See the License for the specific language governing                #
# permissions and limitations under the License.                              #
#                                                                             #
###############################################################################

VERILOG_FILES = top.v uart_tx.v sync_reset.v sync_dd_c.v
PCF_FILE = blackice-ii.pcf

output/chip.bin: output/chip.blif
	arachne-pnr -d 8k -P tq144:4k -p $(PCF_FILE) output/chip.blif -o output/chip.txt
	icepack output/chip.txt output/chip.bin

output/chip.blif: $(VERILOG_FILES) $(PCF_FILE)
	mkdir -p output
	yosys -q -p "synth_ice40 -blif output/chip.blif" $(VERILOG_FILES)

.PHONY: upload
upload:
	cat output/chip.bin >/dev/ttyACM0

.PHONY: clean
clean:
	$(RM) -r output


flash: 
	dfu-util -d 0483:df11 --alt 0 --dfuse-address 0x0801F000 -D output/chip.bin

run:
	stty -F /dev/ttyUSB0 115200 raw -echo
	cat /dev/ttyUSB0

output/tb: tb.v $(VERILOG_FILES)
	mkdir -p output
	iverilog -o output/tb tb.v $(VERILOG_FILES)

sim: output/tb
	./output/tb

help:
	@echo "Makefile options:"
	@echo "    chip.bin (default): Create iCE40 bitstream"
	@echo "    upload:             Upload chip.bin as volatible bitstream to FPGA. Run as root."
	@echo "    flash:              Flash chip.bin into STM32 internal flash. STM32 must be in DFU mode. Run as root."
	@echo "    sim:                Simulate the design. Create .vcd file to use with GTKwave."
	@echo "    run:                Check results on USB2 port."
	@echo "    clean:              Clean up directory"

