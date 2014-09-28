#!/bin/zsh
#
# $Header: mkinitramfs-ll/gnupg.zsh                      Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.6 2014/09/26 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name gnupg
	shell zsh
	version 0.13.6
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  $${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options]

  -d, --usrdir=[usr]     copy binary and options.skel files to usr/
  -u, --useflag=flags    extra USE flags to append to USE="nls static"
  -v, --version=<str>    build gpg-<str> version instead of gpg-1.4.x
  -h, --help, -?         print this help/uage and exit
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

opt=$(getopt -l help,useflag::,usrdir::,version:: -o ?d::u::v:: \
	-n ${PKG[name]}.${PKG[shell]} -- "$@" || usage)
eval set -- "$opt"

declare -A opts
for (( ; $# > 0; ))
	case $1 {
		(-d|--usrdir)
			opts[-usrdir]="$2"
			shift 2;;
		(-u|--useflag)
			opts[-useflag]="$2"
			shift 2;;
		(-v|--version)
			opts[-version]="$2"
			shift 2;;
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
:	${opts[-usrdir]:=${opts[-d]:-${PWD}/usr}}
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
:	${opts[-version]:=${opts[-v]:-1.4}}
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: GnuPG version to build
opts[-gpg]=$(emerge -pvO "=app-crypt/gnupg-${opts[-version]}*" |
	grep -o "gnupg-[-0-9.r]*")

mkdir -p ${opts[-usrdir]}/{bin,share/gnupg}
pushd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
ebuild ${opts[-gpg]}.ebuild clean
USE="nls static ${=opts[-useflag]:-$opts[-u]}" ebuild ${opts[-gpg]}.ebuild compile || die
pushd ${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/${opts[-gpg]}/work/${opts[-gpg]} || die

cp -a g10/gpg          ${opts[-usrdir]}/bin/ || die
cp -a g10/options.skel ${opts[-usrdir]}/share/gnupg/ || die

popd || die
ebuild ${opts[-gpg]}.ebuild clean || die

unset opts PKG

#
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
#
