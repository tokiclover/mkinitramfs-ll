#!/bin/bash
# $Id: mkinitramfs-ll/autogen.bash,v 0.12.0 2013/04/10 22:13:40 -tclover Exp $

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${0##*/} [-a|-all] [-f|-font [font]] [-y|-keymap [keymap]] [options]

  -a, --all                 short hand or forme of '-sqfsd -luks -lvm -gpg -toi'
  -f, --font [:ter-v14n]    include a colon separated list of fonts to the initramfs
  -k, --kversion 3.3.2-git  build an initramfs for kernel 3.4.3-git or else \$(uname -r)
  -c, --comp ['gzip -9']    use 'gzip -9' command instead default compression command
  -L, --luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l, --lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b, --bin :<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d, --usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -n, --minimal             build a minimal busybox binary insead of including all applets
  -p, --prefix initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -W, --workdir [<dir>]     use <dir> as a work directory to create initramfs instead of \$PWD
  -m, --mdep [:<mod>]       include a colon separated list of kernel modules to the initramfs
      --mtuxonice [:<mod>]  include a colon separated list of kernel modules to tuxonice group
      --mremdev [:<mod>]    include a colon separated list of kernel modules to remdev  group
      --msqfsd [:<mod>]     include a colon separated list of kernel modules to sqfsd   group
      --mgpg [:<mod>]       include a colon separated list of kernel modules to gpg     group
      --mboot [:<mod>]      include a colon separated list of kernel modules to boot   group
  -s, --splash [:<theme>]   include a colon separated list of splash themes to the initramfs
  -t, --toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q, --sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -r, --regen               regenerate a new initramfs from an old dir with newer init
  -y, --keymap :fr-latin1   include a colon separated list of keymaps to the initramfs
  -C, --confdir <dir>       use <dir> copy gpg.conf, GnuPG configuration file
  -u, --usage               print this help or usage message and exit

 usage: without additional arguments, generate an initramfs for kernel \$(uname -r)
 usgae: generate an initramfs with LUKS, GnuPG, LVM2 and aufs+squashfs support
 ${0##*/} --all --font --keymap --gpg
EOF
exit $?
}

opt=$(getopt  -l all,bin:,comp::,font::,gpg,mboot::,mdep::,mgpg::,msqfsd::,mremdev:: \
	  -l mtuxonice::,sqfsd,toi,usage,usrdir::,version,confdir:,minimal \
	  -l keymap::,luks,lvm,workdir::,kversion::,prefix::,splash::,regen \
	  -o ab:c::d::f::gk::lLm::p::rs::tuvy::W::C:n -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"

declare -A opts

while [[ $# > 0 ]]; do
	case $1 in
		-t|--toi) opts[-toi]=y; shift;;
		-g|--gpg) opts[-gpg]=y; shift;;
		-r|--regen) opts[-regen]=y; shift;;
		-q|--sqfsd) opts[-sqfsd]=y; shift;;
		-a|--all) opts[-sqfsd]=y; opts[-gpg]=y; 
		 opts[-lvm]=y; opts[-toi]=y; shift;;
		-s|--sqfsd) opts[-sqfsd]=y; shift;;
		-b|--bin) opts[-bin]+=:${2}; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-d|--usrdir) opts[-usrdir]=${2}; shift 2;;
		-f|--font) opts[-font]+=":${2}"; shift 2;;
		-m|--mdep) opts[-mdep]+=":${2}"; shift 2;;
		-n|--minimal) opts[-minimal]=y; shift 2;;
		--mgpg) opts[-mgpg]+=:${2}; shift 2;;
		--mboot) opts[-mboot]+=:${2}; shift 2;;
		--msqfsd) opts[-msqfsd]+=:${2}; shift 2;;
		--mremdev) opts[-mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[-tuxonice]+=:${2}; shift 2;;
		-C|--confdir) opts[-confdir]="${2}"; shift 2;;
		-s|--splash) opts[-splash]+=":${2}"; shift 2;;
		-W|--workdir) opts[-workdir]="${2}"; shift 2;;
		-k|--kversion) opts[-kversion]=${2}; shift 2;;
		-y|--keymap) opts[-keymap]="${2}"; shift 2;;
		-p|--prefix) opts[-prefix]=${2}; shift 2;;
		-l|--lvm) opts[-lvm]=y; shift;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done

[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf ||
	die "no mkinitramfs-ll.conf found"

[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr

mkdir -p "${opts[-workdir]}"

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() {
	echo -ne "\e[1;31m* \e[0m$@\n"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   { 
	error "$@"
	exit 1
}

which bb &>/dev/null || ./busybox.bash

if [[ -n "${opts[-gpg]}" ]]; then
	./gnupg.bash
	if [[ -f "${opts[-confdir]}"/gpg.conf ]]; then
		mkdir -pm700 "${opts[-usrdir]}"/root/.gnupg/
		cp "${opts[-confdir]}"/gpg.conf "${opts[-usrdir]}"/root/.gnupg/ || die
	fi
fi

./mkinitramfs-ll.bash

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
