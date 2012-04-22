#!/bin/zsh
# $Id: mkinitramfs-ll/mkifs-ll.gpg.zsh,v 0.5.0.6 2012/04/15 -tclover Exp $
usage() {
   cat <<-EOF
   usage: ${(%):-%1x} [-U|-useflag'falgs'] [-V|-Version'<str>'] [OPTIONS]
   -B|-bindir <bin>     where to copy builded binary, default is \${PWD}/bin
   -C|-confdir <dir>    copy gpg.conf, GnuPG configuration file, from dir
   -M|-miscdir <misc>   where to copy {.gnupg/gpg.conf,share/gnupg/options.skel}
   -W|-wokdir <dir>     working directory where to create initramfs directory
   -U|-useflag <flags>  extra USE flags to append to USE="nls static"
   -v|-version <str>    build gpg-<str> version instead of gpg-1.4.x
   -u|-usage            print this help/uage and exit
EOF
}
error() { print -P " %B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
if [[ $# = 0 ]] { typeset -A opts; info "building GnuPG..."
} else {
	zmodload zsh/zutil
	zparseopts -E -D -K -A opts U:: useflag:: v:: version:: \
		B:: bindir:: C: confdir: M:: miscdir:: u usage W:: workdir:: || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
}
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-bindir]:=${opts[-B]:-${opts[-workdir]}/bin}}
:	${opts[-bindir]:=${opts[-M]:-${opts[-workdir]}/misc}}
if [[ -f mkifs-ll.conf.zsh ]] { source mkifs-ll.conf.zsh }
mkdir -p ${opts[-bindir]}
mkdir -p ${opts[-miscdir]}/share/gnupg
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die "eek"
opts[gpg]=$(emerge -pvO =app-crypt/gnupg-${opts[-version]:-${opts[-v]:-1.4*}} | grep -o "gnupg-[-0-9.r]*")
ebuild ${opts[gpg]}.ebuild clean
USE="nls static ${=opts[-useflag]:-$opts[-U]}" ebuild ${opts[gpg]}.ebuild compile || die "eek!"
cd ${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/${opts[gpg]}/work/${opts[gpg]} || die "eek!"
cp -a gpg ${opts[-bindir]}/ || die "eek!"
cp g10/options.skel ${opts[-miscdir]}/share/gnupg/ || die "eek!"
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die "eek"
ebuild ${opts[gpg]}.ebuild clean || die "eek!"
cd $opts[-worddir] || die "eek!"
unset opts[-v] opts[-version] opts[-U] opts[-useflag]
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
