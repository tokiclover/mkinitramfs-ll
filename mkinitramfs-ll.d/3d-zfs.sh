#!/bin/sh
# $Id: mkinitramfs-ll.d/3d-zfs.sh, 2012/07/12 11:43:11 -tclover Exp $
# to use zfs module one should build an initramfs with `mkinitramfs-ll.$shell ...
# -mdep spl:znvpair:zcommon:zavl:zunicode:zfs -b zpool:zfs and `-b :mount.zfs 
# for legacy support. and don't forget to append izfs=<arg>[,-f,...] cmdline arg.
set +e +x
. /lib/mkinitramfs-ll/functions.sh
[ "$eck" ] && for bin in zfs zpool; do 
	debug -d -- bck $bin
done
debug -d -- _modprobe spl znvpair zcommon zavl zunicode zfs
dev=${iroot%%:*}
if [ -n "$kmode" ]; then
	debug -d -- _getopt izfs
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
unset dev grp izfs vdev
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
