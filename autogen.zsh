#!/bin/zsh
# $Id: mkinitramfs-ll/autogen.zsh,v 0.9.1 2012/06/19 11:24:37 -tclover Exp $
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-a|-all] [-f|-font [font]] [-y|-keymap [keymap]] [options]
  -a|-all                 short hand or forme of '-sqfsd -luks -lvm -gpg -toi'
  -f|-font [:ter-v14n]    include a colon separated list of fonts to the initramfs
  -k|-kversion 3.3.2-git  build an initramfs for kernel 3.4.3-git or else \$(uname -r)
  -c|-comp ['gzip -9']    use 'gzip -9' command instead default compression command
  -L|-luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l|-lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b|-bin :<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d|-usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g|-gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -n|-minimal             build a minimal busybox binary insead of including all applets
  -U|-ucl-arch i386       use i386 arch to build busybox linked uClibc instead of glibc
  -p|-prefix initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -W|-workdir [<dir>]     use <dir> as a work directory to create initramfs instead of \$PWD
  -m|-mdep [:<mod>]       include a colon separated list of kernel modules to the initramfs
     -mtuxonice [:<mod>]  include a colon separated list of kernel modules to tuxonice group
     -mremdev [:<mod>]    include a colon separated list of kernel modules to remdev  group
     -msqfsd [:<mod>]     include a colon separated list of kernel modules to sqfsd   group
     -mgpg [:<mod>]       include a colon separated list of kernel modules to gpg     group
     -mboot [:<mod>]      include a colon separated list of kernel modules to boot   group
  -s|-splash [:<theme>]   include a colon separated list of splash themes to the initramfs
  -t|-toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q|-sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -R|-regen               regenerate a new initramfs from an old dir with newer init
  -y|-keymap :fr-latin1   include a colon separated list of keymaps to the initramfs
  -r|-raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -C|-confdir <dir>       use <dir> copy gpg.conf, GnuPG configuration file
  -u|-usage               print this help or usage message and exit

  usage: runned without arguments, build an initramfs for kernel \$(uname -r)
  build an initramfs after building gnupg/busybox binaries with AUFS/LVM/GPG support:
  ${(%):-%1x} -all -font -keymap -gpg
EOF
exit 0
}
error() { print -P "%B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q sqfsd g gpg l lvm t toi c:: comp:: r raid \
	k: kversion: m+:: mdep+:: f+:: font+:: s:: splash:: u usage C: confdir: n minimal \
	v version W:: workdir::  b:: bin:: p:: prefix:: y:: keymap:: d:: usrdir:: U: ucl-arch: \
	mboot+:: mgpg+:: mremdev+:: msqfsd+:: mtuxonice+:: L luks R regen || usage
if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -z ${(k)opts[*]} ]] { typeset -A opts }
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-usrdir]:=${opts[-d]:-${opts[-workdir]}/usr}}
if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf }
mkdir -p ${opts[-workdir]}
busybox.zsh
if [[ -n ${(k}opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] { gnupg.zsh
	if [[ -f ${opts[-confdir]:-${opts[-C]}}/gpg.conf ]] ]] { 
		mkdir -pm700 ${opts[-usrdir]}/root/.gnupg/
		cp ${opts[-confdir]}/gpg.conf ${opts[-usrdir]}/root/.gnupg/ || die
	}
}
./mkinitramfs-ll.zsh
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
