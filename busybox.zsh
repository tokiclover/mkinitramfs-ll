#!/bin/zsh
# $Id: mkinitramfs-ll/busybox.zsh,v 0.8.1 2012/06/05 15:36:12 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-m|-minimal] [-U|-ucl-archi386] 
  -i|-instal              install busybox with symliks to \${opts[-bindir]}, require -B
  -n|-minimal             build busybox with minimal applets, default is full applets
  -U|-ucl-arch i386       ARCH string needed to build busybox against uClibc	
  -B|-bindir [<bin>]      copy builded binary to <bin> directory
  -v|-version 1.20.0      use 1.20.0 instead of latest version
  -u|-usage               print the usage/help and exit
EOF
exit $?
}
error() { print -P " %B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
zmodload zsh/zutil
zparseopts -E -D -K -A opts n minimal i install B: bindir: M: miscdir: \
	U: ucl-arch: u usage v: version: || usage
if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -z ${(k)opts[*]} ]] { typeset -A opts }
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-bindir]:=${opts[-B]:-$opts[-workdir]/bin}}
:	${opts[-U]:-$opts[-ucl-arch]}
:	${opts[-y]:-$opts[-keymap]}
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf }
mkdir -p ${opts[-bindir]}
cd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die
if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] { 
	opts[-pkg]="=busybox-${opts[-version]:-${opts[-v]}}"
} else { opts[-pkg]=busybox }
opts[bbt]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
cd ${PORTAGE_TMPDIR:-/var/tmp}/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die
if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-minimal]} ]] { make allnoconfig || die
	for cfg ($(< ${opts[-workdir]}/busybox.cfg))
	sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
} else {
	make defconfig || die "defconfig failed" 
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
}
if [[ -n ${opts[-U]} ]] || [[ -n ${opts[-ucl-arch]} ]] {
sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-U]}\"|" \
	-i .config || die "setting uClib ARCH failed"
}
make && make busybox.links || die "failed to build busybox"
if [[ -n ${(k)opts[-i]} ]] || [[ -n ${(k)opts[-install]} ]] { 
	if [[ -e ${opts[-tmpdir]} ]] { make install CONFIG_PREFIX=${opts[-tmpdir]}/busybox
		rm -rf ${opts[-tmpdir]}/busybox
	}
	applets/install.sh ${opts[-bindir]} --symlinks
}
cp -a busybox ${opts[-bindir]}/ || die "failed to copy busybox binary"
cp busybox.links ${opts[-bindir]}/applets || die "failed to copy applets"
cd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die
ebuild ${opts[bbt]}.ebuild clean || die
cd ${opts[-worddir]} || die
unset opts[bbt] opts[-n] opts[-minimal] opts[-i] opts[-install] opts[-U] opts[-ucl-arch]
# vim:fenc=utf-8ft=zsh:ci:pi:sts=0:sw=4:ts=4:
