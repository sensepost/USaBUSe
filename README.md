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

cd esp-vnc
make

This should result in a user1.bin file in the firmware directory.

I found the following invocation to be useful in programming both firmwares:

avr/flash_avr avr/Program_ESP/Program_ESP.hex && sleep 2 && \
esp-vnc/flash_esp esp-vnc/firmware/user1.bin && \
avr/flash_avr avr/KeyboardMousegeneric/KeyboardMouseGeneric.hex

Alternatively, with a suitably updated flash_esp, you can do:

esp-vnc/flash_esp esp-vnc/firmware/user1.bin avr/KeyboardMousegeneric/KeyboardMouseGeneric.hex

which does the above for you.

To send vnc commands to it, use vncdotool, available in pip. Note, vncdotool is only compatible with Python2.7, not python 3+

$ vncdo -s esp-link.lan -p password type "echo hello" key enter

An updated vncdo is available at https://github.com/RoganDawes/vncdotool that includes the ability to type out a file.

The hard coded password for the VNC server is "password". Ideally, I should include DES routines in the ESP firmware, so that the password can be changed dynamically.

If esp-link.lan does not resolve, look for port 23 and 5900 on the local network, or check your DHCP server.
