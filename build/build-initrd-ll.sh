#!/bin/bash
# if not called with a kernel and extra version, default xill be `uname -r'
E_VERSION=$2
K_VERSION=$1
:	${K_VERSION:-$(uname -r)}
if [ -n "$E_VERSION" ]; then
E_VERSION=-$E_VERSION
fi
INITRAMFS=/boot/kernel-$K_VERSION$E_VERSION-ll-initrd.xz
INITDIR=initrd-ll$(echo $K_VERSION|cut -b4-)
INIT=../init/init
BIN=../bin-amd64
BBB=$BIN/busybox
CMD="xz -9 --check=crc32"
GPG=$BIN/gpg
MISC=../misc/share
KEYMAP=$BIN/fr_l1-x86_64.bin
SPLASH=

rm -rf $INITDIR
mkdir -p $INITDIR && cd $INITDIR
mkdir -p {{,s}bin,dev,etc/{modules,splash},newroot,proc,root,sys,usr/{bin,sbin}} 
mkdir -p lib64/{splash/cache,modules/$K_VERSION/{misc,kernel/{crypto,fs/nls}}}
ln -sf lib64 lib 
#mknod --mode=0660 dev/null c 1 3
#mknod --mode=0600 dev/console c 5 1

cp -a /dev/{console,mem,null,tty1,zero} dev/
cp -a $INIT . && chmod 755 init
cp -a $BIN/applets etc/applets 
cp -a /sbin/{mount.aufs,umount.aufs,cryptsetup,fsck.ext4} sbin
cp -a $BBB bin/
for i in $(< $BIN/applets); do ln -s bin/busybox .$i; done
cp -a $GPG usr/bin/
cp -ar $MISC usr/
cp -a /sbin/lvm.static sbin/lvm
cd sbin; for i in {vg,pv,lv}{change,create,re{move,name},s{,can}} {lv,vg}reduce lvresize vgmerge
do ln -s lvm $i; done; cd ..
# fsck.ext4 related libraries, comment out if you don't need them or replace them with...
cp -a /lib/{ld-*,libc{-*,.so*}} lib/
cp -a /lib64/{libblkid.so.1*,libcom_err*,libe2p*,libext2fs*,libpthread*,libuuid*} lib
for i in kernel/{fs/{au,j,x}fs,crypto/blowfish.ko}
do 
	cp -ar /lib/modules/$K_VERSION/$i lib/modules/$K_VERSION/${i%*/}
done
if [ ! -d /lib/modules/$K_VERSION/kernel/fs/aufs ]; then
	cp -ar /lib/modules/$K_VERSION/misc/aufs.ko lib/modules/$K_VERSION/misc
fi
for i in reiser{fs,4}
do
	if [ -d /lib/modules/$K_VERSION/kernel/fs/$i ]; then
		cp -ar /lib/modules/$K_VERSION/$i lib/modules/$K_VERSION/${i%*/}
	fi
done
echo aufs > etc/modules/sqfsd
echo blowfish > etc/modules/boot
cp -a $KEYMAP etc/
#cp -a /lib/modules/$K_VERSION/kernel/fs/nls/nls_cp437.ko lib/modules/$K_VERSION/kernel/fs/nls/
#echo nls_cp437 > etc/modules/remdev
[ -n "$SPLASH" ] && cp -ar $SPASH etc/splash/

find . -print0|cpio --null -ov --format=newc|$CMD > $INITRAMFS

# clean up variables
unset K_MODULES
unset K_VERSION
unset E_VERSION
unset INITDIR
unset INIT
unset BBB
unset BIN
unset GPG
unset MISC
unset KEYMAP
unset CMD
unset INITRAMFS
unset SPLASH
