#!/bin/zsh
#
# $Header: mkinitramfs-ll/gnupg.zsh                      Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.4 2014/09/09 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name gnupg
	shell zsh
	version 0.13.4
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOF
  $PKG[name].$PKG[shell]-$PKG[version]
  usage: $PKG[name].$PKG[shell] -d|--usrdir[usr] [options]

  -d, -usrdir[usr]       copy binary and options.skel files to usr/
  -u, -useflag<flags>    extra USE flags to append to USE="nls static"
  -v, -version<str>      build gpg-<str> version instead of gpg-1.4.x
  -h, -help              print this help/uage and exit
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
zparseopts -E -D -K -A opts u:: useflag:: v:: version:: d:: usrdir:: h help || usage

if [[ -n ${(k)opts[-h]} ]] || [[ -n ${(k)opts[-help]} ]] { usage }
if [[ $# < 1 ]] { typeset -A opts }

if [[ -f /etc/portage/make.conf ]] { source /etc/portage/make.conf 
} else { die "no /etc/portage/make.conf found" }

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

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4: