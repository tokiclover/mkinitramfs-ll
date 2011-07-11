#/bin/sh
sqfsd_mount() {
	if [ -n "`mount -t squashfs|grep "$1/$2"`" ]; then echo "$1/$2/ro already mounted."
	else	echo "mounting squashed $2.sfs image"
		mount -t squashfs $1/$2.sfs $1/$2/ro -o nodev,loop,ro &>/dev/null
       		[ "$?" ] || echo "mount squashed $2.sfs image failed."
	fi
	if [ -n "`mount -t aufs|grep /$2`" ]; then echo "$2 aufs branch already mounted"
	else	echo "mounting squashed $2 aufs branch"
		mount -t aufs $2 /$2 -o nodev,udba=reval,br:$1/$2/rw:$1/$2/ro &>/dev/null
		[ "$?" ] || echo "mount $2 aufs branch failed."
	fi
}

sqfsd_umount() {
        echo "umounting squashed $2 aufs branch"
	umount -lt aufs /$2 -O no_netdev &>/dev/null
	[ "$?" ] || echo "umount squashed $2 aufs branch failed."
	echo "umounting squashed $2.sfs image"
	umount -lt squashfs $1/$2/ro -O no_netdev &>/dev/null
	[ "$?" ] || echo "umount squashed $2.sfs image failed."
}

sqfsd_remountro() {
	echo "mounting in ro imode $2 aufs branch"
	mount -o remount,ro /$2
	[ "$?" ] || echo "failed to mount $2 aufs branch in ro mode."
}
