#!/bin/zsh
#
# $Header: mkinitramfs-ll/busybox.zsh                    Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.6 2014/09/09 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name busybox
	shell zsh
	version 0.13.6
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  $PKG[name].$PKG[shell]-$PKG[version]
  usage: ${PKG[name]}.${PKG[shell]} [options]

  -u, --usrdir=usr       copy busybox binary file to usr/bin
  -n, --minimal          build busybox with minimal applets, default is all applets
  -a, --abi=i386         ABI string needed to build busybox against uClibc	
  -v, --version=1.20.0   use 1.20.0 instead of latest version of busybox
  -h, --help, -?         print the usage/help and exit
EOH
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	print -P " %B%F{red}*%b %1x: %F{yellow}%U%I%u%f: $@" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error $@
	exit $ret
}

typeset -A opts
typeset -a opt

opt=(
	"-o" "?a:hnu::v:"
	"-l" "abi:,help,minimal,usrdir::,version:"
	"-n" ${PKG[name]}.${PKG[shell]}
)
opt=($(getopt ${opt} -- ${argv} || usage))
eval set -- ${opt}

for (( ; $# > 0; ))
	case $1 {
		(-n|--minimal)
			opts[-minimal]=true
			shift;;
		(-a|--abi)
			opts[-abi]=$2
			shift 2;;
		(-u|--usrdir)
			opts[-usrdir]=$2
			shift 2;;
		(-v|--version)
			opts[-version]=$2
			shift 2;;
		(--)
			shift
			break;;
		(-?|-h|--help|*)
			usage;;
	}

if [[ -f /etc/portage/make.conf ]] {
	source /etc/portage/make.conf 
} else {
	die "no /etc/portage/make.conf found"
}

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path where to get extra files
:	${opts[-usrdir]:=${opts[-d]:-"${PWD}"/usr}}
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
#
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: busybox package to build
opts[-pkg]=busybox

if (( ${+opts[-version]} )) {
	opts[-pkg]=${opts[-pkg]-${opts[-version]:-${opts[-v]}}
} else {
	opts[-pkg]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
}

mkdir -p ${opts[-usrdir]}/bin

pushd ${PORTDIR:-/usr/portage}/sys-apps/busybox || die

ebuild ${opts[-pkg]}.ebuild clean || die "clean failed"
ebuild ${opts[-pkg]}.ebuild unpack || die "unpack failed"
pushd ${PORTAGE_TMPDIR:-/var/tmp}/portage/sys-apps/${opts[-pkg]}/work/${opts[-pkg]} || die

if (( ${+opts[-minimal]} )) {
	make allnoconfig || die
	for cfg ($(< ${0:h}/busybox-minimal.config))
        sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
} else {
	make defconfig || die "defconfig failed" 
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
}

if (( ${+opts[-abi]} )) {
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-abi]}\"|" \
	-i .config || die "setting uClib ARCH failed"
}

make || die "failed to build busybox"
cp -a busybox ${opts[-usrdir]}/bin || die
popd || die

ebuild ${opts[-pkg]}.ebuild clean || die

unset opts PKG

#
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
#
