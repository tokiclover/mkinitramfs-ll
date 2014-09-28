#!/bin/bash
#
# $Header: mkinitramfs-ll/gnupg.bash                     Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.6 2014/09/26 12:33:03                   Exp $
#

declare -A PKG
PKG=(
	[name]=gnupg
	[shell]=bash
	[version]=0.13.6
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  $${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options]

  -u, --usrdir=[usr]     copy binary and options.skel files to usr/
  -U, --useflag=flags    extra USE flags to append to USE="nls static"
  -v, --version=<str>    build gpg-<str> version instead of gpg-1.4.x
  -h, --help, -?         print this help/uage and exit
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
	"-o" "?hu::U::v::"
	"-l" "help,useflag::,usrdir::,version::"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

for (( ; $# > 0; )); do
	case $1 in
		(-u|--usrdir)
			opts[-usrdir]="$2"
			shift 2;;
		(-U|--useflag)
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
