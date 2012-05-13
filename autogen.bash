#!/bin/bash
# $Id: mkinitramfs-ll/mkifs-ll.gen.bash,v 0.5.0.7 2012/05/04 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${0##*/} OPTIONS [OPTIONS...]
  -a|--all                 short forme/hand of '--sqfsd --lvm --gpg --toi'
  -D|--build               build a static busybox and GnuPG-1.x binaries
  -f|--font :<font>        append colon separated list of fonts to in include
  -e|--eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k|--kversion 3.3.2-git  build an initramfs for '3.1.4-git' kernel, else for \$(uname -r)
  -c|--comp                compression command to use to build initramfs, default is 'xz -9..'
  -g|--gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p|--prefix vmlinuz.     prefix scheme to name the initramfs image default is 'initrd-'
  -y|--keymap kmx86.bin    append colon separated list of keymaps to include in the initramfs
  -l|--lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
  -B|--bindir <bin>        try to include binaries from bin dir {busybox,applets,gpg} first
  -M|--miscdir <misc>      use msc dir for {.gnupg/gpg.conf,share/gnupg/options.skel} files,
                           one can add manpages {gpg,lvm,cryptsetup} and user scripts as well
  -W|--workdir <dir>       working directory where to create initramfs dir, default is PWD
  -b|--bin :<bin>          append colon separated list of binar-y-ies to include
  -C|--confdir >dir>       copy gpg.conf, GnuPG configuration file, from dir
  -m|--mdep :<mod>         colon separated list of kernel module-s to include
  -s|--splash :<theme>     colon ':' separated list of splash themes to include
     --mgpg :<mod>         colon separated list of kernel modules to add to gpg group
     --mboot :<mod>        colon separated list of kernel modules to add to boot group
     --msqfsd :<mod>       colon separated list of kernel modules to add to sqfsd group
     --mremdev :<mod>      colon separated list of kernel modules to add to remdev group
     --mtuxonice :<mod>    colon separated list of kernel modules to add to tuxonice group
  -t|--toi                 adds tuxonice support for splash, require tuxoniceui_text binary
  -q|--sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -i|--install	           install busybox with symliks to \${opts[--bindir]}, require -b
  -n|--minimal	           build busybox with minimal applets, default is full applets
  -r|--raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -U|--ucl-arch i386       ARCH string needed to build busybox linked uClibc
  -y|--keymap <k:m>        generate <m> keymap using <k> as input keymap
  -u|--usage               print this help/usage and exit

  usage: runned without arguments, build an initramfs for kernel \$(uname -r)
  # build an initramfs after building gnupg/busybox (AUFS2/LVM2/GPG support)
  ${0##*/} --build-all --aufs --lvm
EOF
exit $?
}
opt=$(getopt -o ab:c:e:fgik:lm:p:rs:tuvy:B:M:W:nDC:U:y: -l all,bin:,bindir:,eversion: \
	  -l gpg,mboot:,mdep:,mgpg:,msqfsd:,mremdev:,mtuxonice:,sqfsd,toi,usage,raid,font: \
	  -l lvm,miscdir:,workdir:,kversion:,build,confdir:,minimal,ucl-arch:,keymap:,comp: \
	  -l install,prefix:,splash: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-t|--toi) opts[toi]=y; shift;;
		-g|--gpg) opts[gpg]=y; shift;;
		-r|--raid) opts[raid]=y; shift;;
		-q|--sqfsd) opts[sqfsd]=y; shift;;
		-a|--all) opts[sqfsd]=y; opts[gpg]=y; 
		 opts[lvm]=y; opts[toi]=y; shift;;
		-s|--sqfsd) opts[sqfsd]=y; shift;;
		-D|--build) opts[build]=y; shift 2;;
		-b|--bin) opts[bin]+=:${2}; shift 2;;
		-c|--comp) opts[comp]="${2}"; shift 2;;
		-B|--bindir) opts[bindir]=${2}; shift 2;;
		-f|--font) opts[font]+=":${2}"; shift 2;;
		-m|--mdep) opts[mdep]+=":${2}"; shift 2;;
		-i|--install) opts[install]=y; shift 2;;
		-n|--minimal) opts[minimal]=y; shift 2;;
		--mgpg) opts[mgpg]+=:${2}; shift 2;;
		--mboot) opts[mboot]+=:${2}; shift 2;;
		--msqfsd) opts[msqfsd]+=:${2}; shift 2;;
		--mremdev) opts[mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[tuxonice]+=:${2}; shift 2;;
		-C|--confdir) opts[confdir]="${2}"; shift 2;;
		-M|--miscdir) opts[miscdir]="${2}"; shift 2;;
		-s|--splash) opts[splash]+=":${2}"; shift 2;;
		-W|--workdir) opts[workdir]="${2}"; shift 2;;
		-U|--ucl-arch) opts[ucl-arch]=${2}; shift 2;;
		-e|--eversion) opts[eversion]=${2}; shift 2;;
		-k|--kversion) opts[kversion]=${2}; shift 2;;
		-y|--keymap) opts[keymap]="${2}"; shift 2;;
		-p|--prefix) opts[prefix]=${2}; shift 2;;
		-l|--lvm) opts[lvm]=y; shift;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[workdir]}" ]] || opts[workdir]="$(pwd)"
[[ -n "${opts[miscdir]}" ]] || opts[miscdir]="${opts[workdir]}"/misc
[[ -n "${opts[bindir]}" ]] || opts[bindir]="${opts[workdir]}"/bin
[[ -f mkifs-ll.conf.bash ]] && source mkifs-ll.conf.bash
mkdir -p "${opts[workdir]}"
mkdir -p "${opts[bindir]}"
error() { echo -ne "\e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
[[ -n "${opts[build]}" ]] && { ./mkifs-ll_bb.bash
	[[ -n "${opts[gpg]}" ]] && { ./mkifs-ll_gpg.bash
		[[ -d "${opts[confdir]}" ]] && { mkdir -p "${opts[miscdir]}"/.gnupg/
			cp "${opts[confdir]}"/gpg.conf "${opts[miscdir]}"/.gnupg/ || die "eek!"
		}
	}
}
./mkifs-ll.bash
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
