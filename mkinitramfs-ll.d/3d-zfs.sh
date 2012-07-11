#!/bin/sh
# $Id: mkinitramfs-ll.d/3d-zfs.sh, 2012/07/11 16:05:33 -tclover Exp $
# to use zfs module one should build an initramfs with `mkinitramfs-ll.$shell ...
# -mdep spl:znvpair:zcommon:zavl:zunicode:zfs -b zpool:zfs
# and `-b :mount.zfs for legacy support arguments.
set +e +x
debug -d -- . /lib/mkinitramfs-ll/functions.sh
[ "$eck" ] && for bin in zfs zpool; do 
	debug -d -- bck $bin
done
debug -d -- _modprobe spl znvpair zcommon zavl zunicode zfs
if [ -n "$kmode" ]; then
	debug _getopt vdev
	debug -d -- test -n $vdev
	for vdev in $(echo "$vdev" | sed 's/:/ /g'); do
		debug -d -- dmopen $vdev
	done
	kmode=
fi
debug -d -- zpool import -N -R /newroot ${dev%/*}
debug zfs mount $dev || debug -d -- mount.zfs $dev /newroot && export rootfs=mounted
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
