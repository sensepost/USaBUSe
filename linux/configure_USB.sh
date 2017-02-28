#!/bin/bash

# based on hidonly.sh by 
# 
# Collin Mulliner <collin AT mulliner.org>
#

# Check if the hardware has USB Device Controller capabilty
UDC=`ls /sys/class/udc/`
if [ -z "$UDC" ] ; then
	echo "No USB Device Controller hardware found, cannot continue!"
	exit 1
fi

modprobe -r g_ether usb_f_ecm usb_f_rndis u_ether
modprobe usb_f_hid

cd /sys/kernel/config/
# Create a gadget
mkdir usb_gadget/g1
cd usb_gadget/g1

# define basic device properties, and corresponding strings
echo 0x1209 > idVendor
echo 0x6667 > idProduct
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2

# 0x0409 is English (United States)
mkdir strings/0x409
# echo "fedcba9876543210" > strings/0x409/serialnumber
echo "SensePost" > strings/0x409/manufacturer
echo "USaBUSe" > strings/0x409/product

# define how many configurations the device has. Most will just have one
mkdir configs/c.1
# define Max power consumption for Config 1
echo 120 > configs/c.1/MaxPower

# define Strings related to Config 1
mkdir configs/c.1/strings/0x409
echo "Default" > configs/c.1/strings/0x409/configuration

# define the available functions that the device supports

# Set up the combined keyboard and mouse
mkdir functions/hid.usb0
cd functions/hid.usb0
# Non-boot protocol == 0, Keyboard Boot Protocol == 1, Mouse Boot Protocol == 2
echo 0 > protocol
# Non-boot subclass == 0, Boot subclass == 1
echo 0 > subclass

# Report length is 9 rather than 8, because we include the report identifier before the keyboard report
# This must correspond closely with the report descriptor that follows
echo 9 > report_length
echo -ne "\x05\x01\x09\x02\xA1\x01\x85\x01\x09\x01\xA1\x00\x05\x09\x19\x01\x29\x03\x15\x00\x25\x01\x95\x03\x75\x01\x81\x02\x95\x01\x75\x05\x81\x01\x05\x01\x09\x30\x09\x31\x15\x81\x25\x7F\x35\x81\x45\x7F\x95\x02\x75\x08\x81\x06\xC0\xC0\x05\x01\x09\x06\xA1\x01\x85\x02\x05\x07\x19\xE0\x29\xE7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x01\x05\x08\x19\x01\x29\x05\x95\x05\x75\x01\x91\x02\x95\x01\x75\x03\x91\x01\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x95\x06\x75\x08\x81\x00\xC0" > report_desc
cd ../..

# Set up the raw HID interface
mkdir functions/hid.usb1
cd functions/hid.usb1
# Non-boot protocol == 0, Keyboard Boot Protocol == 1, Mouse Boot Protocol == 2
echo 0 > protocol
# Non-boot subclass == 0, Boot subclass == 1
echo 0 > subclass

# Report length is 9 rather than 8, because we include the report identifier before the keyboard report
# This must correspond closely with the report descriptor that follows
echo 64 > report_length
echo -ne "\x06\x00\xFF\x09\x01\xA1\x01\x09\x02\x15\x00\x25\xFF\x75\x08\x95\x40\x81\x02\x09\x03\x15\x00\x25\xFF\x75\x08\x95\x40\x91\x02\xC0" > report_desc
cd ../..

# make the functions available in the defined configuration
ln -s functions/hid.usb0 configs/c.1
ln -s functions/hid.usb1 configs/c.1

# enable the device
echo "$UDC" > UDC

