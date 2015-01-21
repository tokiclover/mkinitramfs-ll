#!/bin/zsh
#
# $Header: mkinitramfs-ll/gnupg.zsh                      Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.18.0 2015/01/20 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name gnupg
	shell zsh
	version 0.18.0
)

# @FUNCTION: Print help message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options]

  -d, --usrdir=usr       USRDIR to use for binary/options.skel copy
  -u, --useflag=flags    Set extra USE flags to use
  -v, --version=<str>    Set version to use instead of latest 1.4.x
  -h, --help, -?         Print this help message and and exit
EOH
exit $?
}

# @FUNCTION: Print error message to stdout
function error {
	print -P " %B%F{red}*%b %1x: %F{yellow}%U%I%u%f: $@" >&2
}
# @FUNCPTION: Fatal error heler
function die {
	local ret=$?
	error $@
	exit $ret
}

declare -A opts
declare -a opt

opt=(
	"-o" "?hd::u::v::"
	"-l" "help,useflag::,usrdir::,version::"
	"-n" ${PKG[name]}.${PKG[shell]}
	"-s" ${PKG[shell]}
)
opt=($(getopt ${opt} -- ${argv} || usage))
eval set -- ${opt}

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

# @VARIABLE: USRDIR path to use
:	${opts[-usrdir]:=${opts[-d]:-"${PWD}"/usr}}
# @VARIABLE: GnuPG version to pick up
:	${opts[-version]:=${opts[-v]:-1.4}}
# @VARIABLE: GnuPG version to use
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
