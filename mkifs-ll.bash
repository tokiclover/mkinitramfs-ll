#!/bin/bash
# $Id: mkinitramfs-ll/mkifs-ll.bash,v 0.5.0.5 2012/04/10 -tclover Exp $
revision=0.5.0.5
usage() {
  cat <<-EOF
  usage: ${1##*/} [OPTIONS...]
  -a|--all                 short forme/hand of '-sqfsd -lvm -gpg -toi'
  -f|--font :<font>        append colon separated list of fonts to in include
  -e|--eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k|--kversion 3.1.4-git  build an initramfs for '3.1.4-git' kernel, else for \$(uname -r)
  -c|--comp                compression command to use to build initramfs, default is 'xz -9..'
  -g|--gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p|--prefix vmlinuz.     prefix scheme to name the initramfs image default is 'initrd-'
  -y|--keymap kmx86.bin    append colon separated list of keymaps to include in the initramfs
  -l|--lvm                 adds LVM2 support, require a static sys-fs/lvm2[lvm.static] binary
  -B|--bindir bin          try to include binaries from bin dir (busybox/applets/gpg) first
  -M|--miscdir misc        use msc dir for {.gnupg/gpg.conf,share/gnupg/options.skel} files,
                           one can add manpages gpg/lvm/cryptsetup and user scripts as well
  -W|--wokdir dir          working directory where to create initramfs dir, default is PWD
  -b|--bin :<bin>          append colon separated list of binar-y-ies to include
  -m|--mdep :<mod>         colon separated list of kernel module-s to include
  -s|--splash :<theme>     colon ':' separated list of splash themes to include
     --mgpg :<mod>         colon separated list of kernel modules to add to gpg group
     --mboot :<mod>        colon separated list of kernel modules to add to boot group
     --msqfsd :<mod>       colon separated list of kernel modules to add to sqfsd group
     --mremdev :<mod>      colon separated list of kernel modules to add to remdev group
     --mtuxonice :<mod>    colon separated list of kernel modules to add to tuxonice group
  -t|--toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q|--sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -r|--raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -u|--usage               print this help/usage and exit
  -v|--version             print version string and exit

  # usage: without an argument, build an initramfs for \$(uname -r) with only LUKS support
  # build with LUKS/GPG/LVM2/AUFS2 support for 3.0.3-git kernel with an extra '-d' version
  ${0##*/} -a -e-d -k3.0.3-git
  # NOTE: <str>: string; <font>: fonts list; <theme>: theme list; <mod>: kernel modules...
EOF
}
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
info() 	{ echo -ne " \e[1;32m* \e[0m$@\n"; }
warn() 	{ echo -ne " \e[1;33m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
addnodes() {
	[ -c dev/console ] || mknod dev/console c 5 1 || die "eek!"
	[ -c dev/urandom ] || mknod dev/urandom c 1 9 || die "eek!"
	[ -c dev/random ] || mknod dev/random c 1 8 || die "eek!"
	[ -c dev/mem ] || mknod dev/mem c 1 1 || die "eek!"
	[ -c dev/null ] || mknod dev/null c 1 3 || die "eek!"
	[ -c dev/tty ] || mknod dev/tty c 5 0 	|| die "eek!"
	for i in $(seq 1 6); do [[ -c dev/tty$i ]] || mknod dev/tty$i c 4 $i || die "eek!"; done
	[ -c dev/zero ] || mknod dev/zero c 1 5 || die "eek!"
}
[[ $# = 0 ]] && info "initramfs will be build with only LUKS support."
opt=$(getopt -o ab:c:e:fgk:lm:rstuvy:B:M:S:W: --long all,bin:,bindir:comp:,eversion:,keymap: \
	  --long font:,gpg:,mboot:,mdep:,mgpg:msqfsd:,mremdev:,mtuxonice,sqfsd,toi,usage,version \
	  --long lvm,miscdir:,workdir:,kversion:,raid -n ${0##*/} -- "$@" || usage && exit 0)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-u|--usage) usage; exit 0;;
		-v|--version) echo "${0##*/}-$revision"; exit 0;;
		-a|--all) opts[sqfsd]=y; opts[gpg]=y; 
			opts[lvm]=y; opts[toi]=y; shift;;
		-r|--raid) opts[raid]=y; shift;;
		-q|--sqfsd) opts[sqfsd]=y; shift;;
		-b|--bin) opts[bin]+=:${2}; shift 2;;
		-c|--comp) opts[comp]="${2}"; shift 2;;
		-B|--bindir) opts[bindir]=${2}; shift 2;;
		-e|--eversion) opts[eversion]=${2}; shift 2;;
		-k|--kversion) opts[kversion]=${2}; shift 2;;
		-p|--prefix) opts[prefix]=${2}; shift 2;;
		-f|--font) opts[font]+=":${2}"; shift 2;;
		-m|--mdep) opts[mdep]+=":${2}"; shift 2;;
		-g|--gpg) opts[gpg]=y; shift;;
		-l|--lvm) opts[lvm]=y; shift;;
		--mgpg) opts[mgpg]+=:${2}; shift 2;;
		--mboot) opts[mboot]+=:${2}; shift 2;;
		--msqfsd) opts[msqfsd]+=:${2}; shift 2;;
		--mremdev) opts[mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[tuxonice]+=:${2}; shift 2;;
		-M|--miscdir) opts[miscdir]="${2}"; shift 2;;
		-s|--splash) opts[splash]+=":${2}"; shift 2;;
		-W|--workdir) opts[workdir]="${2}"; shift 2;;
		--) shift; break;;
	esac
done
[[ -n "${opts[kversion]}" ]] || opts[kversion]="$(uname -r)"
[[ -n "${opts[workdir]}" ]] || opts[workdir]="$(pwd)"
[[ -n "${opts[miscdir]}" ]] || opts[miscdir]="${opts[workdir]}"/misc
[[ -n "${opts[prefix]}" ]] || opts[prefix]=initrd-
[[ -n "${opts[bindir]}" ]] || opts[bindir]="${opts[workdir]}"/bin
opts[initdir]="${opts[workdir]}"/${opts[prefix]}${opts[kversion]}${opts[eversion]}
opts[initrd]=/boot/${opts[prefix]}${opts[kversion]}${opts[eversion]}
[[ -n "${opts[comp]}" ]] || opts[comp]="xz -9 --check=crc32"
if [[ -f mkifs-ll.conf.bash ]]; then source mkifs-ll.conf.bash
elif [[ -f /etc/mkifs-ll.conf.bash ]]; then sourse /etc/mkifs-ll.conf.bash; fi
case ${opts[comp]%% *} in
	bzip2)	opts[initrd]+=.ibz2;;
	gzip) 	opts[initrd]+=.igz;;
	xz) 	opts[initrd]+=.ixz;;
	lzma)	opts[initrd]+=.ilzma;;
	lzop)	opts[initrd]+=.ilzo;;
esac
echo ">>> building ${opts[initrd]}..."
rm -rf "${opts[initdir]}" || die "eek!"
mkdir -p "${opts[initdir]}" && cd "${opts[initdir]}" || die "eek!"
mkdir -p {,usr/}{,s}bin dev proc root sys mnt/tok newroot || die "eek!"
mkdir -p etc/{modules,splash,local.d} || die "eek!"
[[ -n "$(uname -a | grep x86_64)" ]] && opts[arch]=64 || opts[arch]=32
mkdir -p lib${opts[arch]}/{splash/cache,modules/${opts[kversion]}} || die "eek!"
ln -sf lib${opts[arch]} lib || die "eek!"
cp -a /dev/{console,random,urandom,mem,null,tty,tty[1-6],zero} dev/ || addnodes
[[ $(echo ${opts[kversion]} | cut -d'.' -f1 ) -eq 3 ]] && \
	[[ $(echo ${opts[kversion]} | cut -d'.' -f2) -ge 1 ]] && { 
	cp -a {/,}dev/loop-control &>/dev/null || mknod dev/loop-control c 10 237 || die "eek!"
}
cp -a "${opts[workdir]}"/init . && chmod 775 init || die "failed to copy init"
cp -a {/,}lib/modules/${opts[kversion]}/modules.dep || die "failed to copy modules.dep"
[[ -e ${opts[miscdir]}/msg ]] && cp ${opts[miscdir]}/msg etc/
for scr in $(ls ${opts[miscdir]}/*.sh &>/dev/null); do cp ${scr} etc/local.d/; done
if [[ -x "${opts[bindir]}"/busybox ]]; then opts[bin]+=:bin/busybox
elif which bb &>/dev/null; then 
	cp $(which bb) bin/busybox
else die "there's no busybox/bb binary"; fi
if [[ -e "${opts[bindir]}"/applets ]]; then
	cp -a "${opts[bindir]}"/applets etc/
	for app in $(< etc/applets); do	
		case ${app%/*} in
			/sbin) cd sbin && ln -s ../bin/busybox ${app##*/} && cd .. || die "eek!";;
			/bin) cd bin && ln -s busybox ${app##*/} && cd .. || die "eek!";;
			*) ln -s bin/busybox .${app} || die "eek!";;
		esac
	done
else sed -e 's|#\t/bin/busybox|\t/bin/busybox|' -i init || die "eek!"
	ln -sf bin/busybox linuxrc || die "eek!"
	cd bin && ln -sf busybox sh && cd .. || die "eek!"; fi

[[ -n "${opts[sqfsd]}" ]] && { opts[bin]+=:umount.aufs:mount.aufs
	for fs in {au,squash}fs
	do [[ -n "$(echo ${opts[sqfsd]} | grep ${fs})" ]] || opts[sqfsd]+=:${fs}; done
}
[[ -n "${opts[gpg]}" ]] && {
	if [[ -x "${opts[bindir]}"/gpg ]]; then opts[bin]+=:usr/bin/gpg
	elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) == 1 ]]; then
		opts[bin]+=":$(which gpg)"
	else die "there's no usable gpg/gnupg-1.4.x binary"; fi
	cp -r "${opts[miscdir]}"/share usr/ || die "failed to copy ${opts[miscdir]}/share"
	cp -r "${opts[miscdir]}"/.gnupg . || die "failed to copy ${opts[miscdir]}/.gnupg"
	chmod 700 .gnupg; chmod 600 .gnupg/gpg.conf
}
[[ -n "${opts[lvm]}" ]] && { opts[bin]+=:lvm.static
	cd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -sf lvm ${lpv} || die "eek!"
	done
	cd ..
}
[[ -n "${opts[raid]}" ]] && { opts[bin]+=:mdadm.static:mdadm
	cp /etc/mdadm.conf etc/ &>/dev/null || warn "failed to copy /etc/mdadm.conf"
}
addmodule() {
	local ret
	for mod in $@; do
		local module=$(find /lib/modules/${opts[kversion]} -name ${mod}.ko -or -name ${mod}.o)
		if [ -z ${module} ]; then warn "${mod} does not exist"; ((ret=${ret}+1))
		else mkdir -p .${module%/*}
			cp -ar ${module} .${module} || die "${module} copy failed"; fi
	done
	return ${ret}
}
addmodule ${opts[mdep]//:/ }
for grp in boot gpg sqfsd remdev tuxonice; do
	[[ -n "${opts[m${grp}]}" ]] && {
		for mod in ${opts[m${grp}]//:/ }
		do addmodule ${mod} && echo ${mod} >> etc/modules/${grp}; done
	}
done
for keymap in ${opts[keymap]//:/ }; do 
	if [[ -e "${keymap}" ]]; then cp -a "${keymap}" etc/
	elif [[ -e "${opts[bindir]}/${keymap}" ]]; then cp -a "${opts[bindir]}/${keymap}" etc/ 
	else warn "failed to copy ${keymap} keymap"; fi
done
for font in ${opts[font]//:/ }; do
	if [[ -e ${font} ]]; then cp -a ${font} etc/
	elif [[ -e "${opts[bindir]}"/${font} ]]; then cp -a "${opts[bindir]}"/${font} etc/ 
	elif [[ -e /usr/share/consolefonts/${font}.gz ]]; then
		cp /usr/share/consolefonts/${font}.gz . && gzip -d ${font}.gz && \
		mv ${font} etc/ || warn "failed to copy /usr/share/consolefonts/${font}.gz"
	else warn "failed to copy ${font} font"; fi
done
[[ -n "${opts[splash]}" ]] && { opts[bin]+=:splash_util.static
	[[ -n "${opts[toi]}" ]] && opts[bin]+=:tuxoniceui_text
	for theme in ${opts[splash]//:/ }; do 
		if [[ -d ${theme} ]]; then cp -r ${theme} etc/splash/ 
		elif [[ -d "${opts[miscdir]}"/${theme} ]]; then 
			cp -r "${opts[miscdir]}"/${theme} etc/splash/
		elif [[ -d /etc/splash/${theme} ]]; then cp -r {/,}etc/splash/${theme}
			info "copied the whole /etc/splash/${theme} theme"
		else warn "failed to copy ${theme} theme"; fi
	done
}
bincp() {
	for bin in $@; do
		if [[ -x ${bin} ]]; then cp -aH ${bin} .${bin/\.static}
			if [[ "$(ldd ${bin})" != *"not a dynamic executable"* ]]; then
				for lib in $(ldd ${bin} | sed -e "s:li.*=>\ ::g" -e "s:\ (.*)::g")
				do cp -adH ${lib} lib/ || die "failed to copy ${lib} library"; done
			else  info "${bin} is a static binary."; fi
		else warn "${bin} binary doesn't exist"; fi
	done
}
for bin in ${opts[bin]//:/ }; do
	if [[ -x "${opts[bindir]}"/${bin##*/} ]]; then cp "${opts[bindir]}"/${bin##*/} ${bin%/*}
	elif [[ -x /${bin} ]]; then bincp /${bin}
	else bincp $(which ${bin##*/}); fi
done
find . -print0 | cpio --null -ov --format=newc | ${opts[comp]} > "${opts[initrd]}" || die "eek!"
echo ">>> ${opts[initrd]} initramfs built"
unset opt opts
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
