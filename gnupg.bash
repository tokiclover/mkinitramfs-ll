#!/bin/bash
# $Id: mkinitramfs-ll/gnupg.bash,v 0.12.8 2014/07/07 11:00:33 -tclover Exp $

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${0##*/} [-d|--usrdir=usr] [options]

  -d, --usrdir [usr]     copy binary and options.skel files to usr/
  -U, --useflag flags    extra USE flags to append to USE="nls static"
  -v, --version <str>    build gpg-<str> version instead of gpg-1.4.x
  -u, --usage, -?        print this help/uage and exit
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() {
	echo -ne " \e[1;31m* \e[0m$@\n"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die() {
	local ret=$?
	error "$@"
	exit $ret
}

opt=$(getopt -l usage,useflag::,usrdir::,version:: -o ud::U::v:: -n ${0##*/} \
	-- "$@" || usage)
eval set -- "$opt"

declare -A opts
while [[ $# > 0 ]]; do
	case $1 in 
		-d|--usrdir)  opts[-usrdir]=${2}; shift 2;;
		-U|--useflag) opts[-useflag]=${2}; shift 2;;
		-v|--version) opts[-version]=${2}; shift 2;;
		-?|-u|--usage|*) usage;;
	esac
done

[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf ||
	die "no mkinitramfs-ll.conf found"

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path where to get extra files
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]=./usr
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
[[ -n "${opts[-version]}" ]] || opts[-version]='1.4*'
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: GnuPG version to build
opts[-gpg]=$(emerge -pvO "=app-crypt/gnupg-${opts[-version]}" |
	grep -o "gnupg-[-0-9.r]*")

mkdir -p "${opts[-usrdir]}"/{bin,share/gnupg}

pushd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
ebuild ${opts[-gpg]}.ebuild clean || die
USE="nls static ${opts[-useflag]}" ebuild ${opts[-gpg]}.ebuild compile || die
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/app-crypt/${opts[-gpg]}/work/${opts[-gpg]} || die

cp -a gpg "${opts[-usrdir]}"/bin/ || die
cp g10/options.skel "${opts[-usrdir]}"/share/gnupg/ || die

popd || die
ebuild ${opts[-gpg]}.ebuild clean || die

unset -v opts[-useflag] opts[-version] opts[-gpg]

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
