#!/bin/zsh
# $Id: mkinitramfs-ll/mkifs-ll.zsh,v 0.7.0 2012/06/07 12:14:34 -tclover Exp $
revision=0.7.0
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [OPTIONS...]
  -a|-all                 short forme/hand of '-sqfsd -lvm -gpg -toi'
  -f|-font [ter-v14n]     append colon separated list of fonts to in include
  -e|-eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k|-kversion 3.3.2-git  build an initramfs for '3.3.2-git' kernel, else for \$(uname -r)
  -c|-comp ['gzip -9']    compression command to use to build initramfs, default is 'xz -9..'
  -g|-gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p|-prefix initramfs-   prefix scheme to name the initramfs image default is 'initrd-'
  -y|-keymap :fr-latin1   append colon separated list of keymaps to include in the initramfs
  -L|-luks                adds LUKS support, require a sys-fs/cryptsetup[static] binary
  -l|-lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
  -B|-bindir [bin]        try to include binaries from bin dir {busybox,applets,gpg} first
  -M|-miscdir [misc]      use msc dir for {.gnupg/gpg.conf,share/gnupg/options.skel} files,
                          one can add manpages {gpg,lvm,cryptsetup} and user scripts as well
  -W|-workdir [<dir>]     working directory where to create initramfs dir, default is PWD
  -b|-bin :<bin>          append colon separated list of binar-y-ies to include
  -m|-mdep [:<mod>]       colon separated list of kernel module-s to include
  -s|-splash [:<theme>]   colon ':' separated list of splash themes to include
     -mgpg [:<mod>]       colon separated list of kernel modules to add to gpg group
     -mboot [:<mod>]      colon separated list of kernel modules to add to boot group
     -msqfsd [:<mod>]     colon separated list of kernel modules to add to sqfsd group
     -mremdev [:<mod>]    colon separated list of kernel modules to add to remdev group
     -mtuxonice [:<mod>]  colon separated list of kernel modules to add to tuxonice group
  -t|-toi                 adds tuxonice support for splash, require tuxoniceui_text binary
  -q|-sqfsd               adds aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -r|-raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -u|-usage               print this help/usage and exit
  -v|-version             print version string and exit

  # usage: without an argument, build an initramfs for \$(uname -r) with only LUKS support
  # build with LUKS/GPG/LVM2/AUFS2 support for 3.0.3-git kernel with an extra 'd' version
  ${(%):-%1x} -all -ed -k3.0.3-git
EOF
exit 0
}
error() { print -P " %B%F{red}*%b%f $@"; }
info()  { print -P " %B%F{green}*%b%f $@"; }
warn()  { print -P " %B%F{red}*%b%f $@"; }
die()   { error $@; exit 1; }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
addnodes() {
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod dev/mem     c 1 1 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod dev/zero    c 1 5 || die
	for nod ($(seq 0 6)) [[ -c dev/tty${nod} ]] || mknod -m 620 dev/tty${nod} c 4 ${nod} || die
}
zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q sqfsd g gpg l lvm t toi c:: comp:: r raid \
	e: eversion: k: kversion: m+:: mdep+:: f+:: font+:: M:: miscdir:: s:: splash:: \
	u usage v version W:: workdir::  b:: bin:: p:: prefix:: y:: keymap:: B:: bindir:: \
	mboot+:: mgpg+:: mremdev+:: msqfsd+:: mtuxonice+:: L luks || usage
if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
	print "${(%):-%1x}-$revision"; exit 0 }
if [[ -z ${opts[*]} ]] { typeset -A opts }
setopt EXTENDED_GLOB NULL_GLOB
:	${opts[-kversion]:=${opts[-k]:-$(uname -r)}}
:	${opts[-eversion]:=$opts[-e]}
:	${opts[-prefix]:=${opts[-p]:-initramfs-}}
:	${opts[-workdir]:=${opts[-W]:-$(pwd)}}
:	${opts[-miscdir]:=${opts[-M]:-$opts[-workdir]/misc}}
:	${opts[-bindir]:=${opts[-B]:-$opts[-workdir]/bin}}
:	${opts[-comp]:=${opts[-c]:-xz -9 --check=crc32}}
:	${opts[-initdir]:=${opts[-workdir]}/${opts[-prefix]}${opts[-kversion]}${opts[-eversion]}}
:	${opts[-initrd]:=/boot/${opts[-prefix]}${opts[-kversion]}${opts[-eversion]}}
:	${opts[-arch]:=$(uname -m)}
if [[ -n ${(k)opts[-y]} ]] || [[ -n ${(k)opts[-keymap]} ]] {
: 	${opts[-keymap]:=${opts[-y]:-:$(grep -E '^keymap' /etc/conf.d/keymaps | cut -d'"' -f2)}}
}
if [[ -n ${(k)opts[-f]} ]] || [[ -n ${(k)opts[-font]} ]] {
:	${opts[-font]:=${opts[-f]:-:$(grep -E '^consolefont' /etc/conf.d/consolefont \
		| cut -d'"' -f2):ter-v14n:ter-g12n}}
}
if [[ -n $(uname -m | grep 64) ]] { opts[-lib]=64 } else { opts[-lib]=32 }
if [[ -f mkifs-ll.conf.zsh ]] { source mkifs-ll.conf.zsh }
if [[ -n ${(k)opts[-a]} ]] || [[ -n ${(k)opts[-all]} ]] { 
	opts[-g]=; opts[-l]=; opts[-s]=; opts[-t]=; opts[-q]=; 
}
case ${opts[-comp][(w)1]} in
	bzip2)	opts[-initrd]+=.ibz2;;
	gzip) 	opts[-initrd]+=.igz;;
	xz) 	opts[-initrd]+=.ixz;;
	lzma)	opts[-initrd]+=.ilzma;;
	lzop)	opts[-initrd]+=.ilzo;;
esac
print -P "%F{green}>>> building ${opts[-initrd]}...%f"
rm -rf ${opts[-initdir]} || die "eek!"
mkdir -p ${opts[-initdir]} && cd ${opts[-initdir]} || die
mkdir -p {,s}bin usr/{{,s}bin,share/{consolefonts,keymaps}} || die
mkdir -p dev proc root sys newroot mnt/tok etc/{modules,splash,local.d} || die
mkdir -p lib${opts[-lib]}/{splash/cache,modules/${opts[-kversion]}} || die
ln -sf lib${opts[-lib]} lib || die
cp -a /dev/{console,random,urandom,mem,null,tty,tty[0-6],zero} dev/ || addnodes
if [[ ${${(pws:.:)opts[-kversion]}[1]} -eq 3 ]] && [[ ${${(pws:.:)opts[-kversion]}[2]} -ge 1 ]] {
	cp -a {/,}dev/loop-control &>/dev/null || mknod dev/loop-control c 10 237 || die
}
cp -af ${opts[-workdir]}/init . && chmod 775 init || die "failed to copy init"
cp -ar {/,}lib/modules/${opts[-kversion]}/modules.dep || die "failed to copy modules.dep"
cp -r ${opts[-miscdir]}/share usr/ || die "failed to copy ${opts[-miscdir]}/share"
if [[ -e ${opts[-miscdir]}/imsg ]] { cp ${opts[-miscdir]}/imsg etc/ }
for scr (${opts[-miscdir]}/*(.).sh) cp ${scr} etc/local.d/
if [[ -x ${opts[-bindir]}/busybox ]] { cp -a ${opts[-bindir]}/busybox bin/
} elif [[ $(which busybox) != "busybox not found" && \
	$(ldd $(which busybox)) == *"not a dynamic executable" ]] {
	cp -a $(which busybox) bin/
} elif [[ $(which bb) != "bb not found" ]] { 
	cp -a $(which bb) bin/busybox
	warn "unexpected behaviour may happen using $(which bb) because of missing applets" 
} else { die "no busybox/bb binary found" }
if [[ -e ${opts[-bindir]}/applets ]] { cp -a ${opts[-bindir]}/applets etc/
} else { bin/busybox --list-full > etc/applets || die }
for app ($(< etc/applets)) ln -fs /bin/busybox ${app}
if [[ -n ${(k)opts[-L]} ]] || [[ -n ${(k)opts[-luks]} ]] {
	[[ -n ${(pws,:,)opts[(rw)cryptsetup,-bin]} ]] || opts[-bin]+=:cryptsetup
}
if [[ -n ${(k)opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] { 
	if [[ -x ${opts[-bindir]}/gpg ]] { opts[-bin]+=:usr/bin/gpg
	} elif [[ $($(which gpg) -version | grep 'gpg (GnuPG)' | cut -c13) = 1 ]] {
		opts[-bin]+=:$(which gpg)
	} else { die "there's no usable gpg/gnupg-1.4.x" }
	cp -r ${opts[-miscdir]}/.gnupg . || die "failed to copy ${opts[-miscdir]}/.gnupg"
	chmod 700 .gnupg; chmod 600 .gnupg/gpg.conf
}
if [[ -n ${(k)opts[-lvm]} ]] || [[ -n ${(k)opts[-l]} ]] { opts[-bin]+=:lvm.static
	pushd sbin
	for lpv ({vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge) ln -sf lvm ${lpv} || die
	pushd
}
if [[ -n ${(k)opts[-sqfsd]} ]] || [[ -n ${(k)opts[-q]} ]] { 
	opts[-bin]+=:mount.aufs:umount.aufs
	for fs ({au,squash}fs) 
		[[ -n ${(pws,:,)opts[(rw)${fs},-msqfsd]} ]] || opts[-msqfsd]+=:${fs}
}
if [[ -n ${(k)opts[-raid]} ]] || [[ -n ${(k)opts[-r]} ]] { 
	opts[-bin]+=:mdadm.static:mdadm
	cp /etc/mdadm.conf etc/ &>/dev/null || warn "failed to copy /etc/mdadm.conf"
}
addmodule() {
	local ret
	for mod (/lib/modules/${opts[-kversion]}/**/$@.(ko|o))
		if [[ -e ${mod} ]] { mkdir -p .${mod:h} 
			cp -ar ${mod} .${mod} || die "failed to copy ${mod} module" 
		} else { warn "${mod} does not exist"; ((ret=${ret}+1)) }
	return ${ret}
}
for module (${(pws,:,)opts[-mdep]} ${(pws,:,)opts[-m]}) addmodule ${module}
for grp (boot gpg remdev sqfsd tuxonice)
	for module (${(pws,:,)opts[-m${grp}]}) 
		addmodule ${module} && echo ${module} >> etc/modules/${grp}
for keymap (${(pws,:,)opts[-keymap]} ${(pws,:,)opts[-y]}) {
	if [[ -e ${keymap} ]] { cp -a ${keymap} usr/share/keymaps/
	} elif [[ -e ${opts[-miscdir]}/share/keymaps/${keymap}-${opts[-arch]}.bin ]] { 
		cp -a ${opts[-miscdir]}/share/keymaps/${keymap}-${opts[-arch]}.bin usr/share/keymaps/
	} else { opts[-genkm]+=:${keymap} }
}
for keymap (${(pws,:,)opts[-genkm]}) loadkeys -b -u ${keymap} > \
	usr/share/keymaps/${keymap}-${opts[-arch]}.bin \
	|| die "failed to build ${keymap} keymap"
for font (${(pws,:,)opts[-font]} ${(pws,:,)opts[-f]}) {
	if [[ -e ${opts[-miscdir]}/share/consolefonts/${font} ]] { 
		cp -a ${opts[-miscdir]}/share/consolefonts/${font} usr/share/consolefonts/ 
	} elif [[ -e ${font} ]] { cp -a ${font} usr/share/consolefonts/
	} else {
		for file (/usr/share/consolefonts/${font}*.gz) { cp ${file} . 
			gzip -d ${file:t}
			mv ${font}* usr/share/consolefonts/
		}
	}
}
if [[ -n ${opts[-splash]} ]] || [[ -n ${opts[-s]} ]] { opts[-bin]+=:splash_util.static
	if [[ -n ${(k)opts[-tuxonice]} ]] || [[ -n ${(k)opts[-t]} ]] { opts[-bin]+=:tuxoniceui_text }
	for theme (${(pws,:,)opts[-splash]} ${(pws,:,)opts[-s]})
		if [[ -d ${theme} ]] { cp -r ${theme} etc/splash/ 
		} elif [[ -d ${opts[-miscdir]}/${theme} ]] { cp -r ${opts[-miscdir]}/${theme} etc/splash/  
		} elif [[ -d /etc/splash/${theme} ]] { cp -r {/,}etc/splash/${theme}
			info "copied the whole /etc/splash/${theme} theme"
		} else { warn "splash themes does not exist" }
}
bcp() {
	for bin ($@)
	if [[ -x ${bin}  ]] { 
		cp -aL ${bin} .${bin/%.static}
		if [[ $(ldd ${bin}) != *"not a dynamic executable" ]] {
			for lib ($(ldd ${bin} | tail -n+2 | sed -e 's:li.*=>\ ::g' -e 's:\ (.*)::g'))
			cp -adH ${lib} lib/ || die "failed to copy $lib library" 
		} else { info "${bin} is a static binary." }
	} else {  warn "${bin} binary doesn't exist" }
}
for bin (${(pws,:,)opts[-bin]} ${(pws,:,)opts[-b]})
	if [[ -x ${opts[-bindir]}/${bin:t} ]] { 
		cp ${opts[-bindir]}/${bin:t} ./${bin} || die "failed to copy ${bin}"
	} elif [[ -x /${bin} ]] { bcp /${bin}
	} else { bcp $(which ${bin:t}) }
find . -print0 | cpio --null -ov --format=newc | ${=opts[-comp]} > ${opts[-initrd]} || die
print -P "%F{green}>>> ${opts[-initrd]} initramfs built%f"
unset opts
# vim:fenc=utf-8ft=zsh:ci:pi:sts=0:sw=4:ts=4:
