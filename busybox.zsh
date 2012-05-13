#!/bin/zsh
# $Id: mkinitramfs-ll/busybox.zsh,v 0.5.2.0 2012/05/13 13:43:02 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-D|-build] [-m|-minimal] [-U|-ucl-archi386] ] [-y|-keymap<map:kmap>]
  -D|-build               build a [minimal|full] applets featured] static busybox binary 
  -i|-instal              install busybox with symliks to \${opts[-bindir]}, require -B
  -n|-minimal             build busybox with minimal applets, default is full applets
  -U|-ucl-arch i386       ARCH string needed to build busybox against uClibc	
  -B|-bindir <bin>        copy builded binary to <bin> directory
  -u|-usage               print the usage/help and exit
EOF
exit 0
}
error() { print -P " %B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
if [[ $# = 0 ]] { usage; exit 0
} else {
	zmodload zsh/zutil
	zparseopts -E -D -K -A opts D build n minimal i install \
		B: bindir: M: miscdir: U: ucl-arch: u usage || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
}
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-bindir]:=${opts[-B]:-$opts[-workdir]/bin}}
:	${opts[-U]:-$opts[-ucl-arch]}
:	${opts[-y]:-$opts[-keymap]}
if [[ -f mkifs-ll.conf.zsh ]] { source mkifs-ll.conf.zsh }
mkdir -p ${opts[-bindir]}
build() {
	cd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die "eek"
	opts[bbt]=$(emerge -pvO busybox | grep -o "busybox-[-0-9.r]*")
	ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
	ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
	cd ${PORTAGE_TMPDIR:-/var/tmp}/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die "eek!"
	if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-minimal]} ]] { make allnoconfig || die "eek!"
		sed -e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-e "s|CONFIG_FEATURE_SH_IS_NONE=y|# CONFIG_FEATURE_SH_IS_NONE is not set|" \
		-e "s|# CONFIG_FEATURE_SH_IS_ASH is not set|CONFIG_FEATURE_SH_IS_ASH=y|" \
		-e "s|# CONFIG_ASH_BUILTIN_ECHO is not set|CONFIG_ASH_BUILTIN_ECHO=y|" \
		-e "s|# CONFIG_BASENAME is not set|CONFIG_BASENAME=y|" \
		-e "s|# CONFIG_CAT is not set|CONFIG_CAT=y|" -e "s|# CONFIG_CP is not set|CONFIG_CP=y|" \
		-e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" -e "s|# CONFIG_MV is not set|CONFIG_MV=y|" \
		-e "s|# CONFIG_CUT is not set|CONFIG_CUT=y|" -e "s|# CONFIG_FDISK is not set|CONFIG_FDISK=y|" \
		-e "s|# CONFIG_MKDIR is not set|CONFIG_MKDIR=y|" -e "s|# CONFIG_MKNOD is not set|CONFIG_MKNOD=y|" \
		-e "s|# CONFIG_FINDFS is not set|CONFIG_FINDFS=y|" -e "s|# CONFIG_FSCK is not set|CONFIG_FSCK=y|" \
		-e "s|# CONFIG_KBD_MODE is not set|CONFIG_KBD_MODE=y|" -e "s|# CONFIG_ASH is not set|CONFIG_ASH=y|" \
		-e "s|# CONFIG_INIT is not set|CONFIG_INIT=y|" -e "s|# CONFIG_LOADFONT is not set|CONFIG_LOADFONT=y|" \
		-e "s|# CONFIG_MODPROBE is not set|CONFIG_MODPROBE=y|" -e "s|# CONFIG_BLKID is not set|CONFIG_BLKID=y|" \
		-e "s|# CONFIG_RM is not set|CONFIG_RM=y|" -e "s|# CONFIG_BLKID_TYPE is not set|CONFIG_BLKID_TYPE=y|" \
		-e "s|# CONFIG_MOUNT is not set|CONFIG_MOUNT=y|" -e "s|# CONFIG_RMMOD is not set|CONFIG_RMMOD=y|" \
		-e "s|# CONFIG_MDEV is not set|CONFIG_MDEV=y|" -e "s|# CONFIG_UMOUNT is not set|CONFIG_UMOUNT=y|" \
		-e "s|# CONFIG_SED is not set|CONFIG_SED=y|" -e "s|# CONFIG_SETFONT is not set|CONFIG_SETFONT=y|" \
		-e "s|# CONFIG_HEAD is not set|CONFIG_HEAD=y|" -e "s|# CONFIG_GREP is not set|CONFIG_GREP=y|" \
		-e "s|# CONFIG_SLEEP is not set|CONFIG_SLEEP=y|" -e "s|# CONFIG_TR is not set|CONFIG_TR=y|" \
		-e "s|# CONFIG_HEAD is not set|CONFIG_HEAD=y|" -e "s|# CONFIG_TEST is not set|CONFIG_TEST=y|" \
		-e "s|# CONFIG_TTY is not set|CONFIG_TTY=y|" -e "s|# CONFIG_WHICH is not set|CONFIG_WHICH=y|" \
		-e "s|# CONFIG_LOADKMAP is not set|CONFIG_LOADKMAP=y|" -e "s|# CONFIG_LN is not set|CONFIG_LN=y|" \
		-e "s|# CONFIG_SWITCH_ROOT is not set|CONFIG_SWITCH_ROOT=y|" -i .config || die "minimal cfg failed"
	} else { make defconfig || die "defcfg failed"
		sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" -i .config || die "cfg failed" 
	}
	if [[ -n ${opts[-U]} ]] || [[ -n ${opts[-ucl-arch]} ]] {
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-U]}\"|" \
		-i .config || die "setting uClib ARCH failed"
	}; make && make busybox.links || die "bb build failed"
}
if [[ -n ${(k)opts[-build]} ]] || [[ -n ${(k)opts[-D]} ]] { build
	if [[ -n ${(k)opts[-i]} ]] || [[ -n ${(k)opts[-install]} ]] { 
		if [[ -e ${opts[-tmpdir]} ]] { make install CONFIG_PREFIX=${opts[-tmpdir]}/busybox
			rm -rf ${opts[-tmpdir]}/busybox
		}; ./applets/install.sh ${opts[-bindir]} --symlinks
	}
	cp -a busybox ${opts[-bindir]}/ || die "failed to copy bb binary"
	cp busybox.links ${opts[-bindir]}/applets || die "failed to copy applets"
	cd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die "eek"
	ebuild ${opts[bbt]}.ebuild clean || die "eek"
	cd ${opts[-worddir]} || die "eek!"
}
unset opts[bbt] opts[-n] opts[-minimal] opts[-i] opts[-install] opts[-U] opts[-ucl-arch]
# vim:fenc=utf-8ft=zsh:ci:pi:sts=0:sw=4:ts=4:
