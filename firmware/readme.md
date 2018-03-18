
This firmware replaces the ```iceboot``` fimware that comes standard with the BlackIce-II board.

The original firmware does the following:

* Load a bitstream from the STM32 flash, if it's present 
* Go into an endless loop waiting for data from the USB bus.
* When there is data, and it's an ICE40 bitstream (recognizable by some magic number), then load this 
  new bitstream over SPI into the FPGA.

The goal of this new bitstream is to still support the same functionality, but also have expanded capabilities

Here's a shortlist of things it should be able to do:

* Load a bitstream from the STM32 flash, if it's present 
* Have some mechanism that supports multiple functions:

* Still support uploading a new FPGA bitstream over SPI

    I still want to be able to do fast iterations without having to reprogram the flash.

* Support flashing new data to the STM32 flash.

    The current DFU system requires unplugging the board, the removal of a jumper, plugging in the board, programming,
    unplugging the board, putting the jumper back, and plugging back in. It's annoying. DFU will always be an option
    because it's a part of the STM32 chip, but it should be a last resort thing.

* Have a multi-channel communication system between the STM32 and the ICE40 over SPI or QSPI. 

    I would like the BlackIce-II to be a board that is the basis for development and debug of ICE40 based FPGA. Once
    the design is ready, the design can then be moved to a simpler board such as an Upduino or one of the many
    other ICE40 based board like TinyFPGA etc.

    The SPI link between the STM32 and the FPGA can be used to things like controlling a signal capture tool, a debug
    link for GDB, debug console, loading new data into the SRAM etc.

The standard ```iceboot``` firmware looks like a serial interface to the PC to which the USB cable is plugged in.

It's possible to implement all the features above on top of this serial interface, but that means that you won't be able to
load a new bitstream by simply doing ```cat chip.bin > /dev/ttyACM0```, and you will need to use a dedicated (though still
simple) download tool.

The alternative is to make the USB port look like multiple virtual devices. That's definitely possible, but requires more
software.

For now, the first method will be used. 
