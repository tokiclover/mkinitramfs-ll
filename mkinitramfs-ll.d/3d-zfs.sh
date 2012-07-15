#!/bin/sh
# $Id: mkinitramfs-ll.d/3d-zfs.sh, 2012/07/15 16:37:20 -tclover Exp $
# to use zfs module one should build an initramfs with `mkinitramfs-ll.$shell ...
# -mdep spl:znvpair:zcommon:zavl:zunicode:zfs -b zpool:zfs and `-b :mount.zfs 
# for legacy support. and don't forget to append izfs=<arg>[,-f,...] cmdline arg.
set +x
echo $$ >/run/${0##*/}.pid
. /lib/mkinitramfs-ll/functions.sh
[ "${iroot##*:}" != "zfs" ] && exit
$eck && for bin in zfs zpool; do 
	debug -d -- bck $bin
done
debug -d -- _modprobe zfs
dev=${iroot%%:*}
debug -d -- _getopt izfs
if [ -n "$kmode" ]; then
	debug -d -- test -n "$izfs"
	for vdev in $(echo "${izfs%%,*}" | sed 's/:/ /g'); do
		debug -d -- dmopen $vdev
	done
fi
opt=$(echo "${izfs#*,}" | sed 's/,/ /g')
debug -d -- zpool import $opt -N -R /newroot ${dev%/*}
debug zfs mount $dev || debug -d -- mount.zfs $dev /newroot
echo unset kfile kmode     >>/run/env
echo export rootfs=mounted >>/run/env
rm -f /run/${0##*/}.pid
unset dev izfs vdev
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
