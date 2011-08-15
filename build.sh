#!/bin/bash
echo "minimal busybox build or not? type in 'minimal' if so."
read args
build/build-busybox-ll.sh $args
echo "which kernel and extra version [two strings seperated by a space]? [uname -r]"
read args
build/build-inird-ll.sh $args
unset args
