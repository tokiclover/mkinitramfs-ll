#!/bin/sh
echo "<<< minimal busybox build or not? type in 'minimal' if so"
read args
build/busybox $args
echo "<<< which kernel and extra version--two strings seperated by a space--? [$(uname -r)]"
read args
build/initramfs-ll $args
unset args
