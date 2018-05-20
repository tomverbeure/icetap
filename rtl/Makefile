
ICETAP_SHARED_DESIGN_FILES = sync_pulse.v sync_reset.v sync_dd_c.v icetap.v icetap_scan.v icetap_mem.v
ICETAP_SPI_DESIGN_FILES  = icetap_spi.v icetap_top_spi.v 
ICETAP_JTAG_DESIGN_FILES = jtag_icetap.v icetap_top_jtag.v icetap_jtag_regs.v jtag_tap_generic.v

ICETAP_SPI_TB_FILES	    = icetap_tb_spi.v uart_tx.v
ICETAP_JTAG_TB_FILES	= icetap_tb_jtag.v uart_tx.v

ICETAP_FILES = $(ICETAP_SHARED_DESIGN_FILES) $(ICETAP_JTAG_DESIGN_FILES) $(ICETAP_JTAG_TB_FILES)

PCF_FILE = blackice-ii.pcf

output/icetap_tb: $(ICETAP_FILES) 
	mkdir -p output
	iverilog -DJTAG_TAP_GENERIC -I. -o output/icetap_tb $(ICETAP_FILES)

sim: output/icetap_tb
	./output/icetap_tb


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

help:
	@echo "Makefile options:"
	@echo "    chip.bin (default): Create iCE40 bitstream"
	@echo "    upload:             Upload chip.bin as volatible bitstream to FPGA. Run as root."
	@echo "    flash:              Flash chip.bin into STM32 internal flash. STM32 must be in DFU mode. Run as root."
	@echo "    sim:                Simulate the design. Create .vcd file to use with GTKwave."
	@echo "    run:                Check results on USB2 port."
	@echo "    clean:              Clean up directory"

