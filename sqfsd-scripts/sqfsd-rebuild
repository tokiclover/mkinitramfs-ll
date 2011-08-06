#!/bin/bash

BSIZE=131072
COMP=gzip
EXCL=$3
EXT=$2
sqfsd="`echo $1|tr ':' ' '`"
sqfsdir="/sqfsd"
FSTAB=n
[ -n "$EXCL" ] && EXCL="`echo $3|tr ':' ' '`" && e="-e $EXCL"
die() {
	echo "* $1"
	exit 1
}
for s in $sqfsd
do
   echo ">>> [re]building squashed $s..."
   mkdir -p "$sqfsdir/$s"/{ro,rw} || die "failed to create $s/{ro,rw} dirs."
   mksquashfs /$s $sqfsdir/$s.tmp.sfs -b $BSIZE -comp $COMP $e >/dev/null || die "failed to build $s.sfs img."
   [ "$s" = "lib64" ] && { # move rc-svcdir and cachedir.
	mkdir -p /var/{lib/init.d,cache/splash}
	mount --move "/$s/splash/cache" /var/cache/splash || die "fled to move cachedir."
	mount --move "/$s/rc/init.d" /var/lib/init.d || die "failed to move rc-svcdir."
	}
   [ -n "`mount -t aufs|grep -w $s`" ] && { umount -l /$s || die "failed to umount $s aufs branch."; }
   [ -n "`mount -t squashfs|grep $sqfsdir/$s/ro`" ] && { umount -l $sqfsdir/$s/ro || die "failed to umount sfs img."; }
   rm -rf "$sqfsdir/$s"/rw/* || die "failed to clean up $sqfdir/$s/rw."
   [ -e $sqfsdir/$s.sfs ] && rm -f $sqfsdir/$s.sfs 
   mv $sqfsdir/$s.tmp.sfs $sqfsdir/$s.sfs || die "failed to move $s.tmp.sfs img."
   # set FSTAB=y if you want localmount to take care of mounting instead of sqfsdmount initservice.
   if [ "$FSTAB" = "y" ]; then
   echo "$sqfsdir/$s.sfs   $sqfsdir/$s/ro   squashfs   nodev,loop,ro   0 0" >>/etc/fstab || die "..."
   echo "$s 	/$s 	aufs 	nodev,udba=reval,br:$sqfsdir/$s/rw:$sqfsdir/$s/ro  0 0" >>/etc/fstab || die "..."
   fi
   mount -t squashfs $sqfsdir/$s.sfs $sqfsdir/$s/ro -o nodev,loop,ro || die "failed to mount $s.sfs img."
   [ -n "$EXT" ] && { # now you can up[date] or rm squashed dir.
   	case $EXT in
		rm) rm -rf /$s/*;;
		up) cp -aru "$sqfsdir/$s"/ro/* /$s;;
		*) echo "* nothing to do; usage is [up|rm]."
	esac
	}
   mount -t aufs $s /$s -o nodev,udba=reval,br:$sqfsdir/$s/rw:$sqfsdir/$s/ro || die "failed to mount $s aufs branch."
   [ "$s" = "lib64" ] && { # move back rc-svcdir and cachedir.
	mount --move /var/cache/splash "/$s/splash/cache" || die "failed to move back cachedir."
	mount --move /var/lib/init.d "/$s/rc/init.d" || die "failed to move back rc-svcdir."
	}
  echo ">>> ...squashed $s sucessfully [re]build."
done
