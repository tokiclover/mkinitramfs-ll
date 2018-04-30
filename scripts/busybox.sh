#!/bin/sh
#
# $Header: mkinitramfs-ll/busybox.sh                     Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.22.0 2016/11/06 12:33:03                   Exp $

name=busybox
shell=sh
version=0.20.0

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${name}.${shell} version ${version}
  usage: ${name}.${shell} [OPTIONS]

  -d, --usrdir=usr       USRDIR to use (where to copy BusyBox binary)
  -v, --version=1.20.0   Set version to build instead of latest
  -h, --help, -?         Print the help message and exit
EOH
exit $?
}

die() {
	local ret="${?}"; error "${@}"; exit ${ret}
}

opt="$(getopt \
	-o \?hd:v: \
	-l help,usrdir:,version: \
	-n ${name}.${shell} -s sh -- "${@}" || usage)"
[ ${?} = 0 ] || exit 1
eval set -- ${opt}
while true; do
	case "${1}" in
		(-d|--usrdir) usrdir="${2}"; shift;;
		(-v|--version) vsn="${2}"; shift;;
		(--) shift; break;;
		(-?|-h|--help|*) usage;;
	esac
	shift
done

:	${usrdir:=${PWD}/usr}
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

cd ${PORTDIR:-/usr/portage}/sys-apps/busybox
mkdir -p "${usrdir}"/bin
USE="-pam static" ebuild ${pkg}.ebuild clean || die "clean failed"
USE=static ebuild ${pkg}.ebuild configure || die "configure failed"
# Small modprobe is not able to properly resolve dependencies, though it should
sed -e "s/CONFIG_MODPROBE_SMALL=y/# CONFIG_MODPROBE_SMALL is not set/" \
	-i "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${pkg}/work/${pkg}/.config
USE="-pam static" ebuild ${pkg}.ebuild compile || die "compile failed"
cp "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${pkg}/work/${pkg}/busybox \
	"${usrdir}"/bin/ || die
ebuild ${pkg}.ebuild clean || die
cd "${OLDPWD}"

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
