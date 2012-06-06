#!/bin/bash
# $Id: mkinitramfs-ll/mkifs-ll.bash,v 0.6.1 2012/05/23 01:20:28 -tclover Exp $
revision=0.6.0
usage() {
  cat <<-EOF
  usage: ${1##*/} [OPTIONS...]
  -a, --all                 short forme/hand of '--sqfsd --lvm --gpg --toi'
  -f, --font [:ter-v14n]    append colon separated list of fonts to in include
  -e, --eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k, --kversion 3.3.2-git  build an initramfs for '3.1.4-git' kernel, else for \$(uname -r)
  -c, --comp ['gzip -9']    compression command to use to build initramfs, default is 'xz -9..'
  -g, --gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix initramfs-   prefix scheme to name the initramfs image default is 'initrd-'
  -y, --keymap :fr-latin1   append colon separated list of keymaps to include in the initramfs
  -l, --lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
  -B, --bindir [bin]        try to include binaries from bin dir {busybox,applets,gpg} first
  -M, --miscdir [misc]      use msc dir for {.gnupg/gpg.conf,share/gnupg/options.skel} files,
                            one can add manpages {gpg,lvm,cryptsetup} and user scripts as well
  -W, --wokdir [<dir>]      working directory where to create initramfs dir, default is PWD
  -b, --bin :<bin>          append colon separated list of binar-y-ies to include
  -m, --mdep [:<mod>]       colon separated list of kernel module-s to include
  -s, --splash [:<theme>]   colon ':' separated list of splash themes to include
      --mgpg [:<mod>]       colon separated list of kernel modules to add to gpg group
      --mboot [:<mod>]      colon separated list of kernel modules to add to boot group
      --msqfsd [:<mod>]     colon separated list of kernel modules to add to sqfsd group
      --mremdev [:<mod>]    colon separated list of kernel modules to add to remdev group
      --mtuxonice [:<mod>]  colon separated list of kernel modules to add to tuxonice group
  -t, --toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q, --sqfsd               add aufs(+squashfs modules +{,u}mount.aufs binaries) support
  -r, --raid                add RAID support, copy /etc/mdadm.conf and mdadm binary
  -u, --usage               print this help/usage and exit
  -v, --version             print version string and exit

  # usage: without an argument, build an initramfs for \$(uname -r) with only LUKS support
  # build with LUKS/GPG/LVM2/AUFS2 support for 3.0.3-git kernel with an extra '-d' version
  ${0##*/} -a -e-d -k3.0.3-git
EOF
exit $?
}
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
info() 	{ echo -ne " \e[1;32m* \e[0m$@\n"; }
warn() 	{ echo -ne " \e[1;33m* \e[0m$@\n"; }
die()   { error "$@"; exit 1; }
addnodes() {
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod dev/mem     c 1 1 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod dev/zero    c 1 5 || die
	for nod in $(seq 0 6); do 
		[[ -c dev/tty${nod} ]] || mknod -m 620 dev/tty${nod} c 4 ${nod} || die
	done
}
opt=$(getopt -o ab:c::e:f::gk::lm::p::rs::tuvy::B::M::S::W:: -l all,bin:,bindir::,comp::,eversion: \
	  -l font::,gpg,mboot::,mdep::,mgpg::,msqfsd::,mremdev::,mtuxonice::,sqfsd,toi,usage,version \
	  -l keymap::,lvm,miscdir::,workdir::,kversion::,prefix::,splash::,raid -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
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
		-g|--gpg) opts[gpg]=y; shift;;
		-t|--toi) opts[toi]=y; shift;;
		-l|--lvm) opts[lvm]=y; shift;;
		--mgpg) opts[mgpg]+=:${2}; shift 2;;
		--mboot) opts[mboot]+=:${2}; shift 2;;
		--msqfsd) opts[msqfsd]+=:${2}; shift 2;;
		--mremdev) opts[mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[tuxonice]+=:${2}; shift 2;;
		-M|--miscdir) opts[miscdir]="${2}"; shift 2;;
		-s|--splash) opts[splash]+=":${2}"; shift 2;;
		-W|--workdir) opts[workdir]="${2}"; shift 2;;
		-m|--mdep) opts[mdep]+=":${2}"; shift 2;;
		-p|--prefix) opts[prefix]=${2}; shift 2;;
		-y|--keymap) 
			if [[ -n "${2}" ]]; then opts[keymap]+=:"${2}"
			else opts[keymap]+=:$(grep -E '^keymap' /etc/conf.d/keymaps \
				| cut -d'"' -f2)
			fi
			shift 2;;
		-f|--font) 
			if [[ -n "${2}" ]] ;then opts[font]+=":${2}"
			else opts[font]+=:$(grep -E '^consolefont' /etc/conf.d/consolefont \
				| cut -d'"' -f2):ter-v14n:ter-g12n
			fi
			shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[kversion]}" ]] || opts[kversion]="$(uname -r)"
[[ -n "${opts[workdir]}" ]] || opts[workdir]="$(pwd)"
[[ -n "${opts[miscdir]}" ]] || opts[miscdir]="${opts[workdir]}"/misc
[[ -n "${opts[prefix]}" ]] || opts[prefix]=initramfs-
[[ -n "${opts[bindir]}" ]] || opts[bindir]="${opts[workdir]}"/bin
opts[initdir]="${opts[workdir]}"/${opts[prefix]}${opts[kversion]}${opts[eversion]}
opts[initrd]=/boot/${opts[prefix]}${opts[kversion]}${opts[eversion]}
[[ -n "${opts[comp]}" ]] || opts[comp]="xz -9 --check=crc32"
[[ -n "$(uname -m | grep 64)" ]] && opts[lib]=64 || opts[lib]=32
[[ -n "${opts[arch]}" ]] || opts[arch]=$(uname -m)
[[ -f mkifs-ll.conf.bash ]] && source mkifs-ll.conf.bash
case ${opts[comp]%% *} in
	bzip2)	opts[initrd]+=.ibz2;;
	gzip) 	opts[initrd]+=.igz;;
	xz) 	opts[initrd]+=.ixz;;
	lzma)	opts[initrd]+=.ilzma;;
	lzop)	opts[initrd]+=.ilzo;;
esac
echo ">>> building ${opts[initrd]}..."
rm -rf "${opts[initdir]}" || die "eek!"
mkdir -p "${opts[initdir]}" && pushd "${opts[initdir]}" || die
mkdir -p {,s}bin usr/{{,s}bin,share/{consolefonts,keymaps}} || die
mkdir -p dev proc root sys newroot mnt/tok etc/{modules,splash,local.d} || die
mkdir -p lib${opts[lib]}/{splash/cache,modules/${opts[kversion]}} || die
ln -sf lib${opts[lib]} lib || die
cp -a /dev/{console,random,urandom,mem,null,tty,tty[0-6],zero} dev/ || addnodes
if [[ $(echo ${opts[kversion]} | cut -d'.' -f1 ) -eq 3 ]] && \
	[[ $(echo ${opts[kversion]} | cut -d'.' -f2) -ge 1 ]]; then
	cp -a {/,}dev/loop-control &>/dev/null || mknod dev/loop-control c 10 237 || die
fi
cp -a "${opts[workdir]}"/init . && chmod 775 init || die "failed to copy init"
cp -af {/,}lib/modules/${opts[kversion]}/modules.dep || die "failed to copy modules.dep"
cp -ar "${opts[miscdir]}"/share usr/ || die "failed to copy ${opts[miscdir]}/share"
[[ -e ${opts[miscdir]}/imsg ]] && cp ${opts[miscdir]}/imsg etc/
for scr in $(ls ${opts[miscdir]}/*.sh &>/dev/null); do 
	cp ${scr} etc/local.d/
done
if [[ -x "${opts[bindir]}"/busybox ]]; then cp ${opts[bindir]}/busybox bin/
elif which busybox &> /dev/null && \
	[[ $(ldd $(which busybox)) == *"not a dynamic executable" ]]; then
	cp -a $(which busybox) bin/
elif which bb &>/dev/null; then cp -a $(which bb) bin/busybox
	warn "unexpected behaviour may happen using $(which bb) because of missing applets" 
else die "there's no busybox nor bb binary"; fi
if [[ -e "${opts[bindir]}"/applets ]]; then
	cp -a "${opts[bindir]}"/applets etc/
else bin/busybox --list-full > etc/applets || die; fi
for app in $(< etc/applets); do	
	ln -fs /bin/busybox ${app}
done
if [[ -n "${opts[sqfsd]}" ]]; then opts[bin]+=:umount.aufs:mount.aufs
	for fs in {au,squash}fs; do 
		[[ -n "$(echo ${opts[sqfsd]} | grep ${fs})" ]] || opts[sqfsd]+=:${fs}
	done
fi
if [[ -n "${opts[gpg]}" ]]; then
	if [[ -x "${opts[bindir]}"/gpg ]]; then opts[bin]+=:usr/bin/gpg
	elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) == 1 ]]; then
		opts[bin]+=":$(which gpg)"
	else die "there's no usable gpg/gnupg-1.4.x binary"; fi
	cp -r "${opts[miscdir]}"/.gnupg . || die "failed to copy ${opts[miscdir]}/.gnupg"
	chmod 700 .gnupg
	chmod 600 .gnupg/gpg.conf
fi
if [[ -n "${opts[lvm]}" ]]; then opts[bin]+=:lvm.static
	pushd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -sf lvm ${lpv} || die
	done
	pushd
fi
if [[ -n "${opts[raid]}" ]]; then opts[bin]+=:mdadm.static:mdadm
	cp /etc/mdadm.conf etc/ &>/dev/null || warn "failed to copy /etc/mdadm.conf"
fi
addmodule() {
	local ret
	for mod in $@; do
		local module=$(find /lib/modules/${opts[kversion]} -name ${mod}.ko -or -name ${mod}.o)
		if [ -n "${module}" ]; then mkdir -p .${module%/*}
			cp -ar ${module} .${module} || die "failed to copy ${module} module"
		else warn "${mod} does not exist"; ((ret=${ret}+1)); fi
	done
	return ${ret}
}
addmodule ${opts[mdep]//:/ }
for grp in boot gpg sqfsd remdev tuxonice; do
	if [[ -n "${opts[m${grp}]}" ]]; then
		for mod in ${opts[m${grp}]//:/ }; do 
			addmodule ${mod} && echo ${mod} >> etc/modules/${grp}
		done
	fi
done
for keymap in ${opts[keymap]//:/ }; do
	if [[ -f "${keymap}" ]]; then cp -a "${keymap}" usr/share/keymaps/
	elif [[ -f "${opts[miscdir]}/share/keymaps/${keymap}" ]]; then 
		cp -a "${opts[miscdir]}/share/keymaps/${keymap}" usr/share/keymaps/
	else opts[genkm]+=:${keymap}; fi
done
for keymap in ${opts[genkm]//:/ }; do
	loadkeys -b -u ${keymap} > usr/share/keymaps/${keymap}-${opts[arch]}.bin \
		|| die "failed to build ${keymap} keymap"
done
for font in ${opts[font]//:/ }; do
	if [[ -f ${font} ]]; then cp -a ${font} usr/share/consolefonts/
	elif [[ -f "${opts[miscdir]}"/share/consolefonts/${font} ]]; then 
		cp -a "${opts[miscdir]}"/share/consolefonts/${font} usr/share/consolefonts/ 
	else 
		for file in $(ls /usr/share/consolefonts/${font}*.gz); do
			if [[ -f ${file} ]]; then cp ${file} . 
				gzip -d ${file##*/}
				mv ${font}* usr/share/consolefonts/
			fi
		done
	fi
done
if [[ -n "${opts[splash]}" ]]; then opts[bin]+=:splash_util.static
	[[ -n "${opts[toi]}" ]] && opts[bin]+=:tuxoniceui_text
	for theme in ${opts[splash]//:/ }; do 
		if [[ -d ${theme} ]]; then cp -r ${theme} etc/splash/ 
		elif [[ -d "${opts[miscdir]}"/${theme} ]]; then 
			cp -r "${opts[miscdir]}"/${theme} etc/splash/
		elif [[ -d /etc/splash/${theme} ]]; then cp -r {/,}etc/splash/${theme}
			info "copied the whole /etc/splash/${theme} theme"
		else warn "failed to copy ${theme} theme"; fi
	done
fi
bcp() {
	for bin in $@; do
		if [[ -x ${bin} ]]; then cp -aH ${bin} .${bin/%.static}
			if [[ "$(ldd ${bin})" != *"not a dynamic executable"* ]]; then
				for lib in $(ldd ${bin} | tail -n+2 | sed -e 's:li.*=>\ ::g' -e 's:\ (.*)::g')
				do cp -adH ${lib} lib/ || die "failed to copy ${lib} library"; done
			else  info "${bin} is a static binary."; fi
		else warn "${bin} binary doesn't exist"; fi
	done
}
for bin in ${opts[bin]//:/ }; do
	if [[ -x "${opts[bindir]}"/${bin##*/} ]]; then cp "${opts[bindir]}"/${bin##*/} ${bin%/*}
	elif [[ -x /${bin} ]]; then bcp /${bin}
	else bcp $(which ${bin##*/}); fi
done
find . -print0 | cpio --null -ov --format=newc | ${opts[comp]} > "${opts[initrd]}" || die "eek!"
echo ">>> ${opts[initrd]} initramfs built"
unset -v opt opts
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
