#!/bin/zsh
# $Id: mkinitramfs-ll/busybox.zsh,v 0.9.1 2012/06/19 21:44:15 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-m|-minimal] [-ucl i386]
  -d|-usrdir [usr]        copy busybox binary file to usr/bin
  -n|-minimal             build busybox with minimal applets, default is full applets
     -ucl i386            arch string needed to build busybox against uClibc	
  -v|-version 1.20.0      use 1.20.0 instead of latest version of busybox
  -u|-usage               print the usage/help and exit
EOF
exit $?
}
error() { print -P " %B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
zmodload zsh/zutil
zparseopts -E -D -K -A opts n minimal d:: usrdir:: ucl: u usage v: version: || usage
if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -z ${(k)opts[*]} ]] { typeset -A opts }
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-usrdir]:=${opts[-d]:-$opts[-workdir]/usr}}
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf }
mkdir -p ${opts[-usrdir]}/bin
pushd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die
if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] { 
	opts[-pkg]="=busybox-${opts[-version]:-${opts[-v]}}"
} else { opts[-pkg]=busybox }
opts[bbt]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
pushd ${PORTAGE_TMPDIR:-/var/tmp}/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die
if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-minimal]} ]] { make allnoconfig || die
	for cfg ($(< ${opts[-workdir]}/busybox.cfg))
	sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
} else {
	make defconfig || die "defconfig failed" 
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
}
if [[ -n ${opts[-ucl]} ]] {
sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-ucl]}\"|" \
	-i .config || die "setting uClib ARCH failed"
}
make || die "failed to build busybox"
cp -a busybox ${opts[-usrdir]}/bin || die
popd || die
ebuild ${opts[bbt]}.ebuild clean || die
popd || die
unset opts[bbt] opts[-n] opts[-minimal] opts[-ucl]
# vim:fenc=utf-8ft=zsh:ci:pi:sts=0:sw=4:ts=4:
