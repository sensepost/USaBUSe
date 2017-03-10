#!/bin/sh

python vncdotool/vncdotool/command.py -s $1 \
	pause 2 \
	key meta-r \
	pause 2 \
	type "powershell" \
	key enter \
	pause 2 \
	pastefile powershell/read_exec_long.ps1
