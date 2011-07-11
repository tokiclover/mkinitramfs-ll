#!/bin/sh
BBA=~/abs/applets
BBL=/usr/share/busybox/busybox-links.tar
INITDIR=~/abs/initrd-ll.38-pf8
INIT=~/abs/init
KEYMAP=~/abs/fr_l1-x86_64.bin
#rm -rf $INITDIR
mkdir -p $INITDIR && cd $INITDIR
mkdir -p {bin,lib64/splash/cache,dev,etc/{modules,splash},newroot,proc,root,sbin,sys,usr/{bin,sbin}} 
ln -sf lib64 lib 
mkdir -p lib/modules/$(uname -r)/{misc,kernel/{crypto,fs/nls}}
#mknod --mode=0660 dev/null c 1 3
#mknod --mode=0600 dev/console c 5 1
cp -a /dev/{console,mem,null,tty1,zero} dev/
cp -a $INIT . && chmod 755 init
cp -a $KEYMAP etc
cp -a $BBA etc/applets 
#cp -a /bin/bb bin/busybox
#tar -xvf $BBL
cp -a /sbin/{mount.aufs,umount.aufs,cryptsetup,fsck.ext4} sbin
cp -a /sbin/lvm.static sbin/lvm
cd sbin; for i in vgchange pvchange lvchange lvcreate vgcreate pvcreate lvreduce lvremove lvrename \
lvresize pvremove pvrename vgmerge vgreduce vgrename vgremove vgscan vgs pvscan pvs lvscan lvs
do ln -s lvm $i; done; cd ..
# those libraries are for fsck.ext4, comment 'em out if you don't need them or replace 'em with...
cp -a /lib/{ld-*,libc{-*,.so*}} lib/
cp -a /lib64/{libblkid.so.1*,libcom_err*,libe2p*,libext2fs*,libpthread*,libuuid*} lib
cp -a /lib/modules/$(uname -r)/misc/aufs.ko lib/modules/$(uname -r)/misc
echo aufs > etc/modules/sqfsd
cp -a /lib/modules/`uname -r`/kernel/crypto/blowfish.ko lib/modules/`uname -r`/kernel/crypto/
echo blowfish > etc/modules/boot
# booting from vfat fs require this if you did not built it in nls_cp437 codepage
#cp -a /lib/modules/`uname -r`/kernel/fs/nls/nls_cp437.ko lib/modules/`uname -r`/kernel/fs/nls/
#echo nls_cp437 >> etc/modules/remdev

find . -print0|cpio --null -ov --format=newc|xz -9 --check=crc32 >/boot/kernel-$(uname -r)-c9-ll-initrd.xz

