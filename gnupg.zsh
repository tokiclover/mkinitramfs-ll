#!/bin/zsh
# $Id: mkinitramfs-ll/gnupg.zsh,v 0.8.1 2012/06/12 13:10:24 -tclover Exp $
usage() {
   cat <<-EOF
   usage: ${(%):-%1x} [-U|-useflag'falgs'] [-V|-Version'<str>'] [OPTIONS]
   -B|-bindir  [bin]    where to copy builded binary, default is \${PWD}/bin
   -C|-confdir <dir>    copy gpg.conf, GnuPG configuration file, from dir
   -M|-miscdir [misc]   where to copy {.gnupg/gpg.conf,share/gnupg/options.skel}
   -W|-wokdir  [<dir>]  working directory where to create initramfs directory
   -U|-useflag <flags>  extra USE flags to append to USE="nls static"
   -v|-version <str>    build gpg-<str> version instead of gpg-1.4.x
   -u|-usage            print this help/uage and exit
EOF
}
error() { print -P " %B%F{red}*%b%f $@" }
die()   { error $@; exit 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
zmodload zsh/zutil
zparseopts -E -D -K -A opts U:: useflag:: v:: version:: \
	B:: bindir:: C: confdir: M:: miscdir:: u usage W:: workdir:: || usage
if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -z ${(k)opts[*]} ]] { typeset -A opts }
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-bindir]:=${opts[-B]:-${opts[-workdir]}/bin}}
:	${opts[-bindir]:=${opts[-M]:-${opts[-workdir]}/misc}}
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf }
mkdir -p ${opts[-bindir]}
mkdir -p ${opts[-miscdir]}/share/gnupg
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
opts[gpg]=$(emerge -pvO =app-crypt/gnupg-${opts[-version]:-${opts[-v]:-1.4*}} | grep -o "gnupg-[-0-9.r]*")
ebuild ${opts[gpg]}.ebuild clean
USE="nls static ${=opts[-useflag]:-$opts[-U]}" ebuild ${opts[gpg]}.ebuild compile || die
cd ${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/${opts[gpg]}/work/${opts[gpg]} || die
cp -a gpg ${opts[-bindir]}/ || die
cp g10/options.skel ${opts[-miscdir]}/share/gnupg/ || die
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
ebuild ${opts[gpg]}.ebuild clean || die
cd $opts[-worddir] || die
unset opts[-v] opts[-version] opts[-U] opts[-useflag]
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
