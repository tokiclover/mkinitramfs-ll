#!/bin/zsh
# $Id: mkinitramfs-ll/autogen.zsh,v 0.8.1 2012/06/12 13:10:16 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [OPTIONS] [OPTIONS...]
  -a|-all                 short forme/hand of '-sqfsd -lvm -gpg -toi'
  -f|-font [:<font>]      append colon separated list of fonts to in include
  -e|-eversion d          append an extra 'd' version to the initramfs image
  -k|-kversion 3.3.2-git  build an initramfs for '3.3.2-git' kernel, else for \$(uname -r)
  -c|-comp                compression command to use to build initramfs, default is 'xz -9..'
  -g|-gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p|-prefix initramfs-   prefix scheme to name the initramfs image default is 'initrd-'
  -y|-keymap [:fr-lati1]  append colon separated list of keymaps to include in the initramfs
  -l|-lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
  -B|-bindir [bin]        try to include binaries from bin dir (busybox/applets/gpg) first
  -M|-miscdir [misc]      use msc dir for {.gnupg/gpg.conf,share/gnupg/options.skel} files,
                          one can add manpages {gpg,lvm,cryptsetup} and user scripts as well
  -W|-wokdir [dir]        working directory where to create initramfs dir, default is PWD
  -b|-bin :<bin>          append colon separated list of binar-y-ies to include
  -C|-confdir <dir>       copy gpg.conf, GnuPG configuration file, from dir
  -m|-mdep [:<mod>]       colon separated list of kernel module-s to include
  -s|-splash [:<theme>]   colon ':' separated list of splash themes to include
     -mgpg [:<mod>]       colon separated list of kernel modules to add to gpg group
     -mboot [:<mod>]      colon separated list of kernel modules to add to boot group
     -msqfsd [:<mod>]     colon separated list of kernel modules to add to sqfsd group
     -mremdev [:<mod>]    colon separated list of kernel modules to add to remdev group
     -mtuxonice [:<mod>]  colon separated list of kernel modules to add to tuxonice group
  -t|-toi                 adds tuxonice support for splash, require tuxoniceui_text binary
  -q|-sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -i|-install             install busybox with symliks to \${opts[-bindir]}, require -b
  -n|-minimal             build busybox with minimal applets, default is full applets
  -r|-raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -U|-ucl-arch i386       ARCH string needed to build busybox linked uClibc
  -u|-usage               print this help/usage and exit

  usage: runned without arguments, build an initramfs for kernel \$(uname -r)
  # build an initramfs after building gnupg/busybox (AUFS2/LVM2/GPG support)
  ${(%):-%1x} -build -sqfsd -lvm
EOF
exit 0
}
error() { print -P "%B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q sqfsd g gpg l lvm t toi c:: comp:: \
	C: confdir: e: eversion: k: kversion:: m+: mdep+: f+: font+: M: miscdir: \
	s: splash: u usage W: workdir:  b: bin: p: prefix: y: keymap: B: bindir: \
	mboot+: mgpg+: mremdev+: msqfsd+: mtuxonice+: r raid i install n minimal \
	y: keymap: U: ucl-arch: || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -z ${(k)opts[*]} ]] { typeset -A opts }
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-miscdir]:=${opts[-M]:-${opts[-workdir]}/misc}}
:	${opts[-bindir]:=${opts[-B]:-${opts[-workdir]}/bin}}
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf }
mkdir -p ${opts[-workdir]}
mkdir -p ${opts[-bindir]}
busybox.zsh
if [[ -n ${(k}opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] { gnupg.zsh
	if [[ -d ${opts[-confdir]} ]] || [[ -d ${opts[-C]} ]] { 
		mkdir -p ${opts[-miscdir]}/.gnupg/
		cp ${opts[-confdir]}/gpg.conf ${opts[-miscdir]}/.gnupg/ || die
	}
}
./mkifs-ll.zsh
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
