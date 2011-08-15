#!/bin/bash
# configuration option for busybox, set minimal for a minimat build
CONFIG=$1
# set ut your input keymap name
KEYMAP_IN=fr-latin1
# convert keymap to unicode if need be
UNICODE=yes
# set up your output keymap name with -<ARCH>
KEYMAP_OUT=fr_l1-x86_64.bin
PWD=$(pwd)
cd /var/portage/sys-apps/busybox
BBT=$(emerge -pvO busybox|grep -o "busybox-[-0-9.r]*")
ebuild $BBT.ebuild clean
ebuild $BBT.ebuild unpack
cd /var/tmp/portage/sys-apps/$BBT/work/busybox*

if [ "$CONFIG" = "minimal" ]; then
make allnoconfig
sed -e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
-e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
-e "s|CONFIG_FEATURE_SH_IS_NONE=y|# CONFIG_FEATURE_SH_IS_NONE is not set|" \
-e "s|# CONFIG_FEATURE_SH_IS_ASH is not set|CONFIG_FEATURE_SH_IS_ASH=y|" \
-e "s|# CONFIG_ASH is not set|CONFIG_ASH=y|" \
-e "s|# CONFIG_ASH_BUILTIN_ECHO is not set|CONFIG_ASH_BUILTIN_ECHO=y|" \
-e "s|# CONFIG_CAT is not set|CONFIG_CAT=y|" \
-e "s|# CONFIG_CP is not set|CONFIG_CP=y|" \
-e "s|# CONFIG_CUT is not set|CONFIG_CUT=y|" \
-e "s|# CONFIG_HEAD is not set|CONFIG_HEAD=y|" \
-e "s|# CONFIG_GREP is not set|CONFIG_GREP=y|" \
-e "s|# CONFIG_INIT is not set|CONFIG_INIT=y|" \
-e "s|# CONFIG_LN is not set|CONFIG_LN=y|" \
-e "s|# CONFIG_MKDIR is not set|CONFIG_MKDIR=y|" \
-e "s|# CONFIG_MKNOD is not set|CONFIG_MKNOD=y|" \
-e "s|# CONFIG_MODPROBE is not set|CONFIG_MODPROBE=y|" \
-e "s|# CONFIG_MOUNT is not set|CONFIG_MOUNT=y|" \
-e "s|# CONFIG_MV is not set|CONFIG_MV=y|" \
-e "s|# CONFIG_MDEV is not set|CONFIG_MDEV=y|" \
-e "s|# CONFIG_UMOUNT is not set|CONFIG_UMOUNT=y|" \
-e "s|# CONFIG_RM is not set|CONFIG_RM=y|" \
-e "s|# CONFIG_RMMOD is not set|CONFIG_RMMOD=y|" \
-e "s|# CONFIG_SED is not set|CONFIG_SED=y|" \
-e "s|# CONFIG_SLEEP is not set|CONFIG_SLEEP=y|" \
-e "s|# CONFIG_SWITCH_ROOT is not set|CONFIG_SWITCH_ROOT=y|" \
-e "s|# CONFIG_TEST is not set|CONFIG_TEST=y|" \
-e "s|# CONFIG_TR is not set|CONFIG_TR=y|" \
-e "s|# CONFIG_WHICH is not set|CONFIG_WHICH=y|" -i .config
else 
make defconfig
sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" -i .config
fi

# For uClibc users, you need to adjust the cross compiler prefix properly (i386-uclibc-)
#sed -i -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"i386-uclibc-\"|" .config

make && make busybox.links

# comment in this if need be--busybox/links are not installed in INITDIR
#make install CONFIG_PREFIX=/tmp/busybox; rm -rf /tmp/busybox
#./applets/install.sh $PWD/bin-amd64/ --symlinks
cp -a busybox $PWD/bin-amd64

# save the current keymap
dumpkeys > default_keymap
loadkeys $KEYMAP_IN
[ "$UNICODE" = "yes" ] && dumpkeys >(loadkeys -u)
./busybox dumpkmap > $KEYMAP_OUT
cp $KEYMAP_OUT $PWD/bin-amd64/
# load back your keymap
loadkeys default_keymap
cd $PWD
unset CONFIG
unset KEMAP_{IN,OUT}
unset UNICODE
unset PWD
unset BBT
exit 0
