#!/bin/bash
# $Id: mkinitramfs-ll/busybox.bash,v 0.13.0 2014/08/08 11:40:18 -tclover Exp $
basename=${0##*/}

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
  $basename-0.13.0
  usage: $basename [-m|--minimal] [--ucl=i386]

  -d, --usrdir=usr     copy busybox binary file to usr/bin
  -n, --minimal          build busybox with minimal applets, default is full applets
      --ucl i386         arch string needed to build busybox against uClibc	
  -v, --version 1.20.0   use 1.20.0 instead of latest version of busybox
  -h, --help, -?         print the usage/help and exit
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error()
{
	echo -ne " \e[1;31m* \e[0m$@\n"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die()
{
	local ret=$?
	error "$@"
	exit $ret
}

opt=$(getopt -l usrdir:,minimal,ucl:,help,version: -o ?nd::v: \
	-n $basename -- "$@" || usage)
eval set -- "$opt"

declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-n|--minimal) opts[-minimal]=y; shift;;
		--ucl) opts[-ucl]=${2}; shift 2;;
		-d|--usrdir) opts[-usrdir]="${2}"; shift 2;;
		-y|--keymap) opts[-keymap]="${2}"; shift 2;;
		-v|--version) opts[-version]="${2}"; shift 2;;
		--) shift; break;;
		-?|-h|--help|*) usage;;
	esac
done

[[ -f /etc/portage/make.conf ]] && source /etc/portage/make.conf ||
	die "no /etc/portage/make.conf found"

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr directory, where to get extra files
[[ ${opts[-usrdir]} ]] || opts[-usrdir]="${PWD}"/usr
# @VARIABLE: opts[-version]
# @DESCRIPTION: GnuPG version to build
#
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: busybox version to build
opts[-pkg]=busybox

if [[ ${opts[-version]} ]]; then 
:	opts[-pkg]=${opts[-pkg]}-${opts[-version]}
else
	opts[-pkg]=$(emerge -pvO ${opts[-pkg]} | grep -o "busybox-[-0-9.r]*")
fi

mkdir -p "${opts[-usrdir]}"/bin

pushd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
ebuild ${opts[-pkg]}.ebuild clean || die "clean failed"
ebuild ${opts[-pkg]}.ebuild unpack || die "unpack failed"
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${opts[-pkg]}/work/${opts[-pkg]} || die

if [[ ${opts[-minimal]} ]]; then
	make allnoconfig || die
	while read cfg; do
		sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
	done <"${opts[-usrdir]}"/busybox.cfg
else
	make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
fi

if [[ ${opts[-ucl]} ]]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-ucl]}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi

make || die "failed to build busybox"
cp -a busybox "${opts[-usrdir]}"/bin/ || die

popd || die
ebuild ${opts[-pkg]}.ebuild clean || die

unset -v opts[-pkg] opts[-minimal] opts[-ucl]

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
