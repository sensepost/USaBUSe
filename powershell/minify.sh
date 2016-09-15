#!/bin/bash
infil=$1

data=$(cat $infil)
#Shorten var names
#vars="$(echo "$data"|grep -oi '\$[a-z]\{2\}[a-z]*'|sort -u)"
#for x in `echo $vars`; do
	#tmp="$(echo "$data"|sed 's/$x//g')"
	#data="$tmp"
#done


#Remove comments
tmp="$(echo "$data"|sed 's/#.*//g')"
data="$tmp"
#Remove spaces around = and +
tmp="$(echo "$data"|sed 's/ \([+=]\) /\1/g')"
data="$tmp"
#Remove spaces around ,
tmp="$(echo "$data"|sed 's/, /,/g')"
data="$tmp"
#Remove spaces around operators
tmp="$(echo "$data"|sed 's/ \(-[a-z][a-z]\) /\1/g')"
data="$tmp"
#Remove spaces around -and operators
tmp="$(echo "$data"|sed 's/ \(-and\) /\1/g')"
data="$tmp"
#Remove spaces around brackets
tmp="$(echo "$data"|sed 's/ (/(/g')"
data="$tmp"
#Remove spaces around brackets
tmp="$(echo "$data"|sed 's/) /)/g')"
data="$tmp"
#Remove spaces around brackets
tmp="$(echo "$data"|sed 's/ {/{/g')"
data="$tmp"
#Remove spaces around brackets
tmp="$(echo "$data"|sed 's/} /}/g')"
data="$tmp"
#Remove tabs
tmp="$(echo "$data"|sed 's/	/ /g')"
data="$tmp"
#Remove unnecessary spaces at start of line
tmp="$(echo "$data"|sed 's/^[ ]*//g')"
data="$tmp"
#Remove unnecessary spaces at end of line
tmp="$(echo "$data"|sed 's/[ ]*$//g')"
data="$tmp"
#Remove unnecessary line breaks
tmp="$(echo "$data"|gawk '{ RS = EOF } a = gensub(/}\r\n/, "}", "g") {print a}')"
data="$tmp"
#Remove unnecessary line breaks
tmp="$(echo "$data"|gawk '{ RS = EOF } a = gensub(/{\r\n/, "{", "g") {print a}')"
data="$tmp"
#Remove unnecessary line breaks
tmp="$(echo "$data"|gawk '{ RS = EOF } a = gensub(/\r\n}/, "}", "g") {print a}')"
data="$tmp"
#Remove unnecessary blank lines
#tmp="$(echo "$data"|gawk '{ RS = EOF } a = gensub(/\r\n\r\n/, "\r\n", "g") {print a}')"
#data="$tmp"

echo "$data"
