#!/bin/bash
# $Id: mkinitramfs-ll/busybox.bash,v 0.8.1 2012/06/12 16:00:15 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${0##*/} [-m|--minimal] [OPTIONS]
  -i, --install             install busybox with symliks to \${opts[-bindir]}, require -b
  -n, --minimal             build busybox with minimal applets, default is full applets
  -U, --ucl-arch i386       ARCH string needed to build busybox against uClibc	
  -B, --bindir [<bin>]      copy builded binary to <bin> directory
  -v, --version 1.20.0      use 1.20.0 instead of latest version
  -u, --usage               print the usage/help and exit
EOF
exit $?
}
opt=$(getopt -l bindir:,install,keymap:,minimal,ucl-arch,usage,version: \
	-o inuDU:B:Y:v: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-i|--install) opts[-install]=y; shift;;
		-n|--minimal) opts[-minimal]=y; shift;;
		-U|--ucl-arch) opts[-U]=${2}; shift 2;;
		-B|--bindir) opts[-bindir]="${2}"; shift 2;;
		-y|--keymap) opts[-keymap]="${2}"; shift 2;;
		-v|--version) opts[-pkg]="=busybox-${2}"; shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-bindir]}" ]] || opts[-bindir]="${opts[-workdir]}"/bin
[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf
mkdir -p "${opts[-bindir]}"
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
cd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
opts[bbt]=$(emerge -pvO "${opts[-pkg]:-busybox}" | grep -o "busybox-[-0-9.r]*")
ebuild ${opts[bbt]}.ebuild clean || die "clean failed"
ebuild ${opts[bbt]}.ebuild unpack || die "unpack failed"
cd "${PORTAGE_TMPDIR:-/var/tmp}"/portage/sys-apps/${opts[bbt]}/work/${opts[bbt]} || die
if [[ -n "${opts[-minimal]}" ]]; then make allnoconfig || die
	for cfg in $(< "${opts[-workdir]}"/busybox.cfg); do
		sed -e "s|# ${cfg%=y} is not set|${cfg}|" -i .config || die
	done
else
	make defconfig || die "defconfig failed"
	sed -e "s|# CONFIG_STATIC is not set|CONFIG_STATIC=y|" \
		-e "s|# CONFIG_INSTALL_NO_USR is not set|CONFIG_INSTALL_NO_USR=y|" \
		-i .config || die
fi
if [[ -n "${opts[-U]}" ]]; then
	sed -e "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${opts[-U]}\"|" \
		-i .config || die "setting uClib ARCH failed"
fi
make && make busybox.links || die "failed to build busybox"
if [[ -n "${opts[-install]}" ]]; then
	if [[ -e "${opts[tmpdir]}" ]]; then
		make install CONFIG_PREFIX="${opts[tmpdir]}"/busybox
		rm -rf "${opts[tmpdir]}"/busybox
	fi
	applets/install.sh "${opts[-bindir]}" --symlinks
fi
cp -a busybox "${opts[-bindir]}"/ || die "failed to copy busybox binary"
cp busybox.links "${opts[-bindir]}"/busybox.app || die "failed to copy applets"
cd "${PORTDIR:-/usr/portage}"/sys-apps/busybox || die
ebuild ${opts[bbt]}.ebuild clean || die
cd "${opts[-workdir]}" || die
unset -v opts[bbt] opts[-install] opts[-minimal] opts[-U] km_in km_out
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
