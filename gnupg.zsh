#!/bin/zsh
# $Id: mkinitramfs-ll/gnupg.zsh,v 0.12.0 2013/04/11 11:00:35 -tclover Exp $

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${(%):-%1x} [-d|--usrdir=usr] [options]

  -d|-usrdir [usr]       copy binary and options.skel files to usr/
  -W|-wokdir  [<dir>]    working directory where to create initramfs directory
  -U|-useflag <flags>    extra USE flags to append to USE="nls static"
  -v|-version <str>      build gpg-<str> version instead of gpg-1.4.x
  -u|-usage              print this help/uage and exit
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { print -P " %B%F{red}*%b%f $@" }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   { error $@; exit 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

zmodload zsh/zutil
zparseopts -E -D -K -A opts U:: useflag:: v:: version:: d:: usrdir:: \
	u usage W:: workdir:: || usage

if [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }

if [[ $# < 1 ]] { typeset -A opts }

if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf 
} else { die "no mkinitramfs-ll.conf found" }

# @VARIABLE: opts[-workdir]
# @DESCRIPTION: initial working directory, where to build everythng
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
:	${opts[-usrdir]:=${opts[-B]:-${opts[-workdir]}/usr}}
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
:	${opts[-version]:-${opts[-v]:-1.4*}}
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: GnuPG version to build
opts[-gpg]=$(emerge -pvO "=app-crypt/gnupg-${opts[-version]}" |
	grep -o "gnupg-[-0-9.r]*")

mkdir -p ${opts[-usrdir]}/{bin,share/gnupg}
pushd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
ebuild ${opts[-gpg]}.ebuild clean
USE="nls static ${=opts[-useflag]:-$opts[-U]}" ebuild ${opts[-gpg]}.ebuild compile || die
pushd ${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/${opts[-gpg]}/work/${opts[-gpg]} || die

cp -a gpg ${opts[-usrdir]}/bin/ || die
cp g10/options.skel ${opts[-usrdir]}/share/gnupg/ || die

popd || die
ebuild ${opts[-gpg]}.ebuild clean || die
popd || die

unset opts[-v] opts[-version] opts[-U] opts[-useflag] opts[-gpg]

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
