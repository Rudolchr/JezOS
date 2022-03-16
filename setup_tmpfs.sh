#!/bin/sh
if [[ "$USER" != "root" ]]
then
	if which sudo > /dev/null 2>&1
	then
		SU=sudo
	elif which doas > /dev/null 2>&1
	then
		SU=doas
	fi
else
	echo "Root access needed to mount tmpfs on ./bin"
	exit 1
fi

if mountpoint -q ./bin
then
	echo "Already mounted tmpfs at ./bin"
else
	$SU mount -t tmpfs -o size=256m noatime ./bin
fi
