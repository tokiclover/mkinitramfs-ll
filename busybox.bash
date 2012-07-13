#!/bin/bash
# $Id: mkinitramfs-ll/busybox.bash,v 0.10.2 2012/07/13 19:20:41 -tclover Exp $
usage() {
  cat <<-EOF
 usage: ${0##*/}[-m|--minimal] [--ucl=i386]

  -d, --usrdir [usr]     copy busybox binary file to usr/bin
  -n, --minimal          build busybox with minimal applets, default is full applets
      --ucl i386         arch string needed to build busybox against uClibc	
  -v, --version 1.20.0   use 1.20.0 instead of latest version of busybox
  -u, --usage            print the usage/help and exit
EOF
exit $?
}
opt=$(getopt -l usrdir:,minimal,ucl:,usage,version: -o nud::v: \
	-n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-n|--minimal) opts[-minimal]=y; shift;;
		--ucl-arch) opts[-ucl]=${2}; shift 2;;
		-d|--usrdir) opts[-usrdir]="${2}"; shift 2;;
		-y|--keymap) opts[-keymap]="${2}"; shift 2;;
		-v|--version) opts[-pkg]="=busybox-${2}"; shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr
mkdir -p "${opts[-usrdir]}"/bin
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
pushd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
opts[bbt]=$(emerge -pvO "${opts[-pkg]:-busybox}" | grep -o "busybox-[-0-9.r]*")
ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
pushd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die
if [[ -n "${opts[-minimal]}" ]]; then make allnoconfig || die
	while read cfg; do
		sed -e "s|# ${cfg%'=y'} is not set|${cfg}|" -i .config || die 
	done < "${opts[-workdir]}"/busybox.cfg
else
	make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
fi
if [[ -n "${opts[-ucl]}" ]]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-ucl]}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi
make || die "failed to build busybox"
cp -a busybox "${opts[-usrdir]}"/bin/ || die
popd || die
ebuild ${opts[bbt]}.ebuild clean || die
popd || die
unset -v opts[bbt] opts[-minimal] opts[-ucl]
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
