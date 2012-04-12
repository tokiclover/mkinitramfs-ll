#!/bin/bash
# $Id: mkinitramfs-ll/mkifs-ll_gpg.bash,v 0.5.0.5 2012/04/11 -tclover Exp $
usage() {
   cat <<-EOF
   usage: ${0##*/} [OPTINS]...
   -B|--bindir <bin>      where to copy builded binary, default is \${PWD}/bin
   -M|--miscdir <misc>    where to copy {.gnupg/gpg.conf,share/gnupg/options.skel}
   -W|--wokdir <dir>      working directory where to create initramfs directory
   -U|--useflag  flags    extra USE flags to append to USE="nls static"
   -v|--version  <str>    build gpg-<str> version instead of gpg-1.4.x
   -u|--usage             print this help/uage and exit
EOF
exit 0
}
opt=$(getopt -l usage,useflag::,bindir::,miscidr::,workdir::,version:: \
	  -o uB::M::U::v::W:: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in 
		-u|--usage) usage;;
		-B|--bindir) opts[bindir]=${2}; shift 2;;
		-U|--useflag) opts[useflag]=${2}; shift 2;;
		-v|--version) opts[version]=${2}; shift 2;;
		-M|--miscdir) opts[miscdir]="${2}"; shift 2;;
		-W|--workdir) opts[workdir]="${2}"; shift 2;;
	esac
done
[[ -n "${opts[workdir]}" ]] || opts[workdir]="$(pwd)"
[[ -n "${opts[bindir]}" ]] || opts[bindir]="${opts[workdir]}"/bin
[[ -n "${opts[miscdir]}" ]] || opts[miscdir]="${opts[workdir]}"/misc
[[ -n "${opts[version]}" ]] || opts[version]='1.4*'
[[ -f mkifs-ll.conf.bash ]] && source mkifs-ll.conf.bash
mkdir -p "${opts[misdir]}"/share/gnupg/
mkdir -p "${opts[bindir]}"
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die() { error "$@"; exit 1; }
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die "eek"
opts[gpg]=$(emerge -pvO =app-crypt/gnupg-${opts[version]} | grep -o "gnupg-[-0-9.r]*")
ebuild ${opts[gpg]}.ebuild clean || die "eek!"
USE="nls static ${opts[useflag]}" ebuild ${opts[gpg]}.ebuild compile || die "eek!"
cd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/app-crypt/${opts[gpg]}/work/${opts[gpg]} || die "eek!"
cp -a gpg "${opts[bindir]}"/ || die "eek!"
cp g10/options.skel "${opts[miscdir]}"/share/gnupg/ || die "eek!"
cd "${PORTDIR:-/usr/portage}"/app-crypt/gnupg || die "eek"
ebuild ${opts[gpg]}.ebuild clean || die "eek!"
cd "${opts[workdir]}" || die "eek!"
opts[gpg]=y
unset -v opts[useflag] opts[version]
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
