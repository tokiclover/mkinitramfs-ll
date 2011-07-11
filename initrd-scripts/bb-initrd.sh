#!/bin/sh
#Busybox compilation stuff
INIYRD=~/initrd-ll
cd /usr/portage/sys-apps/busybox
BBT=`emerge -pvO busybox | grep -o "busybox-[-0-9.r]*"`
ebuild $BBT.ebuild clean
ebuild $BBT.ebuild unpack
cd /var/tmp/portage/sys-apps/$BBT/work/busybox*

make defconfig
sed -i -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" .config
sed -i -e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" .config

make && make busybox.links

# comment in this if necessary, if you don't get the right busybox stuff in the initrd dir
#make install CONFIG_PREFIX=/tmp/busybox ; rm -rf /tmp/busybox
./applets/install.sh $INITDIR --symlinks

# now keymap: look at or run... `find /usr/share/keymaps -type f -name'*fr*'' for easy search fr keymap
loadkeys fr-latin1
# convert keymap to unicode if need be
dumpkeys > loadkeys -u
# Now use BusyBox's dumpkmap applet to obtain the kmap from the current loaded keymap.
# Substitue <x86_64> with your architecture
./busybox dumpkmap > fr_l1-x86_64.bin
# Load the default_keymap
loadkeys default_keymap
