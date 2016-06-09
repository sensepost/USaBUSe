#!/bin/sh

(S=`eval $(stat -s $1); echo $st_size`; printf "0: %02X%02X\n" $(($S >> 8)) $(($S & 255)) | xxd -r ; cat $1; cat) | nc -v $2 23

