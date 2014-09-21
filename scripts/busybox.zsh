#!/bin/zsh
#
# $Header: mkinitramfs-ll/busybox.zsh                    Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.4 2014/09/09 12:33:03                   Exp $
#

typset -A PKG
PKG=(
	name busybox
	shell zsh
	version 0.13.4
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOF
  $PKG[name].$PKG[shell]-$PKG[version]
  usage: $PKG[name].$PKG[shell] [-m|-minimal] [-ucli386]

  -d, -usrdir[usr]        copy busybox binary file to usr/bin
  -n, -minimal            build busybox with minimal applets, default is full applets
      -ucli386            arch string needed to build busybox against uClibc	
  -v, -version1.20.0      use 1.20.0 instead of latest version of busybox
  -h, -help               print the usage/help and exit
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	print -P " %B%F{red}*%b%f $@" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error $@
	exit $ret
}
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

zmodload zsh/zutil
zparseopts -E -D -K -A opts n minimal d:: usrdir:: ucl: h help v: version: || usage

if [[ -n ${(k)opts[-h]} ]] || [[ -n ${(k)opts[-help]} ]] { usage }
if [[ $# < 1 ]] { typeset -A opts }

if [[ -f /etc/portage/make.conf ]] {
	source /etc/portage/make.conf 
} else {
	die "no /etc/portage/make.conf found"
}

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path where to get extra files
:	${opts[-usrdir]:=${opts[-d]:-${PWD}/usr}}
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
#
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: busybox package to build
opts[-pkg]=busybox

if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] { 
	opts[-pkg]=${opts[-pkg]-${opts[-version]:-${opts[-v]}}
} else {
	opts[-pkg]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
}

mkdir -p ${opts[-usrdir]}/bin

pushd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die

ebuild ${opts[-pkg]}.ebuild clean || die "clean failed"
ebuild ${opts[-pkg]}.ebuild unpack || die "unpack failed"
pushd ${PORTAGE_TMPDIR:-/var/tmp}/portage/sys-apps/${opts[-pkg]}/work/${opts[-pkg]} || die

if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-minimal]} ]] {
	make allnoconfig || die
	for cfg ($(< ${0:h}/busybox-minimal.config))
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

ebuild ${opts[-pkg]}.ebuild clean || die

unset opts PKG

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
