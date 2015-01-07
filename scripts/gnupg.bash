#!/bin/bash
#
# $Header: mkinitramfs-ll/gnupg.bash                     Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.16.0 2015/01/01 12:33:03                   Exp $
#

declare -A PKG
PKG=(
	[name]=gnupg
	[shell]=bash
	[version]=0.16.0
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
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

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	echo -ne " \e[1;31m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error "$@"
	exit $ret
}

declare -A opts
declare -a opt

opt=(
	"-o" "?hd::u::v::"
	"-l" "help,useflag::,usrdir::,version::"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

for (( ; $# > 0; )); do
	case $1 in
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
	esac
done

[[ -f /etc/portage/make.conf ]] && source /etc/portage/make.conf ||
	die "no /etc/portage/make.conf found"

# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path where to get extra files
[[ "${opts[-usrdir]}" ]] || opts[-usrdir]="${PWD}"/usr
# @VARIABLE: opts[-version] | opts[-v]
# @DESCRIPTION: GnuPG version to build
[[ "${opts[-version]}" ]] || opts[-version]='1.4'
# @VARIABLE: opts[-pkg]
# @DESCRIPTION: GnuPG version to build
opts[-gpg]=$(emerge -pvO "=app-crypt/gnupg-${opts[-version]}*" |
	grep -o "gnupg-[-0-9.r]*")

mkdir -p "${opts[-usrdir]}"/{bin,share/gnupg}

pushd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die
ebuild ${opts[-gpg]}.ebuild clean || die
USE="nls static ${opts[-useflag]}" ebuild ${opts[-gpg]}.ebuild compile || die
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/app-crypt/${opts[-gpg]}/work/${opts[-gpg]} || die

cp -a g10/gpg          "${opts[-usrdir]}"/bin/ || die
cp -a g10/options.skel "${opts[-usrdir]}"/share/gnupg/ || die

popd || die
ebuild ${opts[-gpg]}.ebuild clean || die

unset -v opts PKG

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
