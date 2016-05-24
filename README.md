Instructions for building the Universal Serial aBuse firmwares and host software

First steps are to install the various compilers for the microprocessors.

OS X and Linux can install the ESP tools by following the instruction in the ESP Open SDK repo:

https://github.com/pfalcon/esp-open-sdk

OS X can also get the AVR compiler by installing the Arduino app, e.g. Caskroom/cask/arduino

Linux can install using apt-get: apt-get install gcc-avr avrdude

Once the avr tools are installed, and avr-gcc is in your PATH, compile the avr firmwares:

cd avr
make

This should build two firmwares, Program_ESP and KeyboardMouseGeneric. i.e you should have .hex files in each directory.

If the ESP sdk was successfully installed, you should also be able to compile the ESP firmware.

cd esp/esp-vnc
make

This should result in a user1.bin file in the firmware directory.

I found the following invocation to be useful in programming both firmwares:

avr/flash_avr avr/Program_ESP/Program_ESP.hex && \
esp/flash_esp esp/esp-vnc/firmware/user1.bin && \
avr/flash_avr avr/KeyboardMousegeneric/KeyboardMouseGeneric.hex


