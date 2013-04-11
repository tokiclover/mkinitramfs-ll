#!/bin/zsh
# $Id: mkinitramfs-ll/autogen.zsh,v 0.12.0 2013/04/10 22:13:37 -tclover Exp $

# @FUNCTION: usage
# @DESCRIPTION: print usages message
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
  -C|-confdir <dir>       use <dir> copy gpg.conf, GnuPG configuration file
  -u|-usage               print this help or usage message and exit

 usage: runned without arguments, build an initramfs for kernel \$(uname -r)
 usgae: generate an initramfs with LUKS, GnuPG, LVM2 and aufs+squashfs support
 ${(%):-%1x} -all -font -keymap -gpg
EOF
exit 0
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { print -P "%B%F{red}*%b%f $@" }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   { 
	error $@
	exit 1
}
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q sqfsd g gpg l lvm t toi c:: comp:: \
	k: kversion: m+:: mdep+:: f+:: font+:: s:: splash:: u usage C: confdir: n minimal \
	v version W:: workdir::  b:: bin:: p:: prefix:: y:: keymap:: d:: usrdir:: \
	mboot+:: mgpg+:: mremdev+:: msqfsd+:: mtuxonice+:: L luks r regen || usage

if [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }

if [[ $# < 1 ]] { typeset -A opts }

if [[ -f mkinitramfs-ll.conf ]] { source mkinitramfs-ll.conf 
} else { die "no mkinitramfs-ll.conf found" }

# @VARIABLE: opts[-workdir]
# @DESCRIPTION: initial working directory, where to build everythng
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
:	${opts[-usrdir]:=${opts[-d]:-${opts[-workdir]}/usr}}

mkdir -p ${opts[-workdir]}

which bb &>/dev/null || ./busybox.zsh

if [[ -n ${(k}opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] {
	./gnupg.zsh
	if [[ -f ${opts[-confdir]:-${opts[-C]}}/gpg.conf ]] ]] { 
		mkdir -pm700 ${opts[-usrdir]}/root/.gnupg/
		cp ${opts[-confdir]}/gpg.conf ${opts[-usrdir]}/root/.gnupg/ || die
	}
}

./mkinitramfs-ll.zsh

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
