#!/bin/sh

cd /sys/kernel/config/usb_gadget/g1
echo "" > UDC
rm configs/c.1/hid.usb*
rmdir configs/c.1/strings/0x409/
rmdir configs/c.1/
rmdir functions/hid.usb*
rmdir strings/0x409/
cd ..
rmdir g1

