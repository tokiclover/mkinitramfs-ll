#!/bin/sh
#
# $Header: mkinitramfs-ll/busybox.sh                     Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.20.0 2015/05/24 12:33:03                   Exp $

name=busybox
shell=sh
version=0.20.0

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${name}.${shell} version ${version}
  usage: ${name}.${shell} [OPTIONS]

  -d, --usrdir=usr       USRDIR to use (where to copy BusyBox binary)
  -n, --minimal          Build only with minimal applets support
  -a, --abi=i386         Set ABI to use when building against uClibc
  -v, --version=1.20.0   Set version to build instead of latest
  -h, --help, -?         Print the help message and exit
EOH
exit $?
}

die() {
	local ret="${?}"; error "${@}"; exit ${ret}
}

opt="$(getopt \
	-o \?a:hnd:v: \
	-l abi:,help,minimal,usrdir:,version: \
	-n ${name}.${shell} -s sh -- "${@}" || usage)"
[ ${?} = 0 ] || exit 1
eval set -- ${opt}
while true; do
	case "${1}" in
		(-n|--minimal) minimal=true;;
		(-a|--abi) abi="${2}"; shift;;
		(-d|--usrdir) usrdir="${2}"; shift;;
		(-v|--version) vsn="${2}"; shift;;
		(--) shift; break;;
		(-?|-h|--help|*) usage;;
	esac
	shift
done

:	${usrdir:="${PWD}"/usr}
pkg=busybox

[ -f /etc/portage/make.conf ] && source /etc/portage/make.conf ||
	die "No /etc/portage/make.conf found"
source "${usrdir}"/lib/mkinitramfs-ll/functions || exit 1
eval_colors

if [ -n "${vsn}" ]; then
	pkg=${pkg}-${vsn}
else
	pkg=$(emerge -pvO ${pkg} | grep -o "busybox-[-0-9.r]*")
fi

mkdir -p "${usrdir}"/bin
OLDPWD="${PORTDIR:-/usr/portage}/sys-apps/busybox"
cd "${oldpwd}" || die
ebuild ${pkg}.ebuild clean || die "clean failed"
ebuild ${pkg}.ebuild unpack || die "unpack failed"
cd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${pkg}/work/${pkg} || die

if [ -n "${minimal}" ]; then
	make allnoconfig || die
	while read cfg; do
		sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
	done <"${0%/*}"/minimal.config
else
	make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
fi
if [ -n "${abi}" ]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${abi}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi

make || die "failed to build busybox"
cp -a busybox "${usrdir}"/bin/ || die
cd "${oldpwd}" || die
ebuild ${pkg}.ebuild clean || die

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
