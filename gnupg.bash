#!/bin/bash
# $Id: mkinitramfs-ll/gnupg.bash,v 0.10.0 2012/07/08 11:45:24 -tclover Exp $
usage() {
  cat <<-EOF
 usage: ${0##*/} [-d|--usrdir=usr] [options]

  -d, --usrdir [usr]     copy binary and options.skel files to usr/
  -W, --wokdir [<dir>]   working directory where to create initramfs directory
  -U, --useflag flags    extra USE flags to append to USE="nls static"
  -v, --version <str>    build gpg-<str> version instead of gpg-1.4.x
  -u, --usage            print this help/uage and exit
EOF
exit $?
}
opt=$(getopt -l usage,useflag::,usrdir::,workdir::,version:: -o ud::U::v::W:: \
	-n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in 
		-d|--usrdir)  opts[-usrdir]=${2}; shift 2;;
		-U|--useflag) opts[-useflag]=${2}; shift 2;;
		-v|--version) opts[-version]=${2}; shift 2;;
		-W|--workdir) opts[-workdir]="${2}"; shift 2;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr
[[ -n "${opts[-version]}" ]] || opts[-version]='1.4*'
[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf
mkdir -p "${opts[-usrdir]}"/{bin,share/gnupg}
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die() { error "$@"; exit 1; }
pushd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
opts[gpg]=$(emerge -pvO =app-crypt/gnupg-${opts[-version]} | grep -o "gnupg-[-0-9.r]*")
ebuild ${opts[gpg]}.ebuild clean || die
USE="nls static ${opts[-useflag]}" ebuild ${opts[gpg]}.ebuild compile || die
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/app-crypt/${opts[gpg]}/work/${opts[gpg]} || die
cp -a gpg "${opts[-usrdir]}"/bin/ || die
cp g10/options.skel "${opts[-usrdir]}"/share/gnupg/ || die
popd || die
ebuild ${opts[gpg]}.ebuild clean || die
popd || die
unset -v opts[-useflag] opts[-version] opts[gpg]
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
