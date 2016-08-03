#!/bin/sh

l16v() { 
	S=$(cat "$1" | wc -c) 
	echo "Sending $S bytes" >&2 
	printf "%b" $(printf "\\%03o" $(( ($S >>  8) & 255)) )
	printf "%b" $(printf "\\%03o" $(( ($S >>  0) & 255)) ) 
	cat "$1"
} 

l16v "$1"
sleep 5
socat - TCP:localhost:4444 

