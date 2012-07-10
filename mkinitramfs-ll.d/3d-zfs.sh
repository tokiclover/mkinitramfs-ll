#!/bin/sh
# $Id: mkinitramfs-ll.d/3d-zfs.sh, 2012/07/09 -tclover Exp $
# to use zfs module one should build an initramfs with `mkinitramfs-ll.$shell ...
# -mdep spl:znvpair:zcommon:zavl:zunicode:zfs -b hostid:zpool:zfs:zpool_layout
# -b zpool_id:zvol_id' and `-b :mount.zfs for legacy support arguments.
set +e +x
debug -d -- source /lib/mkinitramfs-ll/functions.sh
debug _getopt zfs
[ "$eck" ] && for bin in ${zfs:+mount.zfs} zfs zpool; do 
	debug -d -- bck $bin
done
echo spl znvpair zcommon zavl zunicode zfs >/etc/mkinitramfs-ll/module.zfs
debug -d -- _modprobe zfs
if [ -n "$kmode" ]; then
	debug _getopt vdev
	debug -d -- test -n $vdev
	for vdev in $(echo "$vdev" | sed 's/:/ /g'); do
		debug -d -- dmopen $vdev
	done
	kmode=
fi
debug -d -- zpool import -N -R /newroot ${dev%/*}
if [ "$zfs" = "legacy" ]; then
	debug -d -- mount.zfs $dev /newroot
else debug -d -- zfs mount $dev; fi
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
