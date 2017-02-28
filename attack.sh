#!/bin/sh

python vncdotool/vncdotool/command.py -s $1 \
	pause 2 \
	key meta-r \
	pause 2 \
	type "cmd" \
	key enter \
	pause 3 \
	type "powershell" \
	key enter \
	pastefile powershell/read_exec_long.ps1
