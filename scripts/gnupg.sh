#!/bin/bash
#
# $Header: mkinitramfs-ll/gnupg.sh                       Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.20.0 2015/05/24 12:33:03                   Exp $
#

name=gnupg
shell=sh
version=0.20.0

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${name}.${shell} version ${version}
  usage: ${name}.${shell} [OPTIONS]

  -d, --usrdir=usr       USRDIR to use for binary/options.skel copy
  -u, --useflag=flags    Set extra USE flags to use
  -v, --version=<str>    Set version to use instead of latest 1.4.x
  -h, --help, -?         Print this help message and and exit
EOH
exit $?
}

opt="$(getopt \
	-o \?hd:u:v: \
	-l help,useflag:,usrdir:,version: \
	-n "${name}.${shell}" -s sh -- "$@" || usage)"
[ ${?} = 0 ] || exit 1
eval set -- ${opt}

while true; do
	case "${1}" in
		(-d|--usrdir) usrdir="${2}"; shift;;
		(-u|--useflag) useflag="${2}"; shift;;
		(-v|--version) vsn="${2}"; shift;;
		(--) shift; break;;
		(-?|-h|--help|*) usage;;
	esac
	shift
done

[ -f /etc/portage/make.conf ] && source /etc/portage/make.conf ||
	die "No /etc/portage/make.conf found"
source "${usrdir}"/lib/mkinitramfs-ll/functions || exit 1
eval_colors

:	${usrdir:=${PWD}/usr}
:	${vsn:=1.4}
# @VARIABLE: GnuPG version to use
pkg=$(emerge -pvO "=app-crypt/gnupg-${vsn}*" |
	grep -o "gnupg-[-0-9.r]*")

mkdir -p "${usrdir}"/{bin,share/gnupg}
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg
ebuild ${pkg}.ebuild clean || die
USE="nls static ${useflag}" ebuild ${pkg}.ebuild compile || die
tmp="${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/${pkg}/work/${pkg}"
cp -a ${tmp}/g10/gpg          "${usrdir}"/bin/ || die
cp -a ${tmp}/g10/options.skel "${usrdir}"/share/gnupg/ || die
ebuild ${pkg}.ebuild clean || die
cd "${OLDPWD}"

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
