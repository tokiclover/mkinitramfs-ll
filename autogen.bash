#!/bin/bash
# $Id: mkinitramfs-ll/autogen.bash,v 0.9.0 2012/06/17 18:27:23 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${0##*/} OPTIONS [OPTIONS...]
  -a, --all                 short forme/hand of '--sqfsd --lvm --gpg --toi'
  -f, --font [:<font>]      append colon separated list of fonts to in include
  -e, --eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k, --kversion 3.3.2-git  build an initramfs for '3.1.4-git' kernel, else for \$(uname -r)
  -c, --comp                compression command to use to build initramfs, default is 'xz -9..'
  -d, --usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix initramfs-   prefix scheme to name the initramfs image default is 'initrd-'
  -y, --keymap :fr-latin1   append colon separated list of keymaps to include in the initramfs
  -l, --lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
  -W, --workdir [dir]       working directory where to create initramfs dir, default is PWD
  -b, --bin :<bin>          append colon separated list of binar-y-ies to include
  -C, --confdir <dir>       copy gpg.conf, GnuPG configuration file, from dir
  -m, --mdep [:<mod>]       colon separated list of kernel module-s to include
  -s, --splash :<theme>     colon ':' separated list of splash themes to include
      --mgpg [:<mod>]       colon separated list of kernel modules to add to gpg group
      --mboot [:<mod>]      colon separated list of kernel modules to add to boot group
      --msqfsd [:<mod>]     colon separated list of kernel modules to add to sqfsd group
      --mremdev [:<mod>]    colon separated list of kernel modules to add to remdev group
      --mtuxonice [:<mod>]  colon separated list of kernel modules to add to tuxonice group
  -t, --toi                 adds tuxonice support for splash, require tuxoniceui_text binary
  -q, --sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -n, --minimal	            build busybox with minimal applets, default is full applets
  -r, --raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -U, --ucl-arch i386       ARCH string needed to build busybox linked uClibc
  -u, --usage               print this help/usage and exit

  usage: runned without arguments, build an initramfs for kernel \$(uname -r)
  # build an initramfs after building gnupg/busybox (AUFS2/LVM2/GPG support)
  ${0##*/} --all --gpg
EOF
exit $?
}
opt=$(getopt -o ab:c::d::e:f::gk::lm::p::rs::tuvy::W::nC:U:y:: -l all,bin:,usrdir::,eversion: \
	  -l gpg,mboot::,mdep::,mgpg::,msqfsd::,mremdev::,mtuxonice::,sqfsd,toi,usage,raid,font:: \
	  -l lvm,workdir:,kversion::,confdir:,minimal,ucl-arch:,keymap::,comp::,prefix::,splash:: \
	  -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-t|--toi) opts[-toi]=y; shift;;
		-g|--gpg) opts[-gpg]=y; shift;;
		-r|--raid) opts[-raid]=y; shift;;
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
		-U|--ucl-arch) opts[-ucl-arch]=${2}; shift 2;;
		-e|--eversion) opts[-eversion]=${2}; shift 2;;
		-k|--kversion) opts[-kversion]=${2}; shift 2;;
		-y|--keymap) opts[-keymap]="${2}"; shift 2;;
		-p|--prefix) opts[-prefix]=${2}; shift 2;;
		-l|--lvm) opts[-lvm]=y; shift;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr
[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf
mkdir -p "${opts[-workdir]}"
error() { echo -ne "\e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
busybox.bash
if [[ -n "${opts[-gpg]}" ]]; then gnupg.bash
	if [[ -f "${opts[-confdir]}"/gpg.conf ]]; then
		mkdir -pm700 "${opts[-usrdir]}"/root/.gnupg/
		cp "${opts[-confdir]}"/gpg.conf "${opts[-usrdir]}"/root/.gnupg/ || die
	fi
fi
./mkinitramfs-ll.bash
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
