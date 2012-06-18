#!/bin/bash
# $Id: mkinitramfs-ll/mkinitramfs-ll.bash,v 0.9.0 2012/06/18 10:55:35 -tclover Exp $
revision=0.9.0
usage() {
  cat <<-EOF
  usage: ${1##*/} [OPTIONS...]
  -a, --all                 short forme/hand of '--sqfsd --luks --lvm --gpg --toi'
  -f, --font [:ter-v14n]    append colon separated list of fonts to in include
  -e, --eversion d          append an extra 'd' version after \$kv to the initramfs image
  -k, --kversion 3.3.2-git  build an initramfs for '3.1.4-git' kernel, else for \$(uname -r)
  -c, --comp ['gzip -9']    compression command to use to build initramfs, default is 'xz -9..'
  -d, --usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 adds GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix initrd-      prefix scheme to name the initramfs image default is 'initramfs-'
  -y, --keymap :fr-latin1   append colon separated list of keymaps to include in the initramfs
  -L, --luks                adds LUKS support, require a sys-fs/cryptsetup[static] binary
  -l, --lvm                 adds LVM2 support, require a static sys-fs/lvm2[static] binary
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
opt=$(getopt -o ab:c::d::e:f::gk::lLm::p::rs::tuvy::W:: -l all,bin:,usrdir::,comp::,eversion: \
	  -l font::,gpg,mboot::,mdep::,mgpg::,msqfsd::,mremdev::,mtuxonice::,sqfsd,toi,usage,version \
	  -l keymap::,luks,lvm,workdir::,kversion::,prefix::,splash::,raid -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"
[[ -z "${opts[*]}" ]] && declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-v|--version) echo "${0##*/}-$revision"; exit 0;;
		-a|--all) opts[-sqfsd]=y; opts[-gpg]=y; opts[-toi]=y;
			opts[-lvm]=y; opts[-luks]=y; shift;;
		-r|--raid) opts[-raid]=y; shift;;
		-q|--sqfsd) opts[-sqfsd]=y; shift;;
		-b|--bin) opts[-bin]+=:${2}; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-d|--usrdir) opts[-usrdir]=${2}; shift 2;;
		-e|--eversion) opts[-eversion]=${2}; shift 2;;
		-k|--kversion) opts[-kversion]=${2}; shift 2;;
		-g|--gpg) opts[-gpg]=y; shift;;
		-t|--toi) opts[-toi]=y; shift;;
		-l|--lvm) opts[-lvm]=y; shift;;
		-L|--luks) opts[-luks]=y; shift;;
		--mgpg) opts[-mgpg]+=:${2}; shift 2;;
		--mboot) opts[-mboot]+=:${2}; shift 2;;
		--msqfsd) opts[-msqfsd]+=:${2}; shift 2;;
		--mremdev) opts[-mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[-tuxonice]+=:${2}; shift 2;;
		-s|--splash) opts[-splash]+=":${2}"; shift 2;;
		-W|--workdir) opts[-workdir]="${2}"; shift 2;;
		-m|--mdep) opts[-mdep]+=":${2}"; shift 2;;
		-p|--prefix) opts[-prefix]=${2}; shift 2;;
		-y|--keymap) 
			if [[ -n "${2}" ]]; then opts[-keymap]+=:"${2}"
			else opts[-keymap]+=:$(grep -E '^keymap' /etc/conf.d/keymaps \
				| cut -d'"' -f2)
			fi
			shift 2;;
		-f|--font) 
			if [[ -n "${2}" ]] ;then opts[-font]+=":${2}"
			else opts[-font]+=:$(grep -E '^consolefont' /etc/conf.d/consolefont \
				| cut -d'"' -f2):ter-v14n:ter-g12n
			fi
			shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
[[ -n "${opts[-kversion]}" ]] || opts[-kversion]="$(uname -r)"
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
[[ -n "${opts[-prefix]}" ]] || opts[-prefix]=initramfs-
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr
opts[-initramfsdir]="${opts[-workdir]}"/${opts[-prefix]}${opts[-kversion]}${opts[-eversion]}
opts[-initramfs]=/boot/${opts[-prefix]}${opts[-kversion]}${opts[-eversion]}
[[ -n "${opts[-comp]}" ]] || opts[-comp]="xz -9 --check=crc32"
[[ -n "$(uname -m | grep 64)" ]] && opts[-lib]=64 || opts[-lib]=32
[[ -n "${opts[-arch]}" ]] || opts[-arch]=$(uname -m)
[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf
case ${opts[-comp]%% *} in
	bzip2)	opts[-initramfs]+=.cpio.bz2;;
	gzip) 	opts[-initramfs]+=.cpio.gz;;
	xz) 	opts[-initramfs]+=.cpio.xz;;
	lzma)	opts[-initramfs]+=.cpio.lzma;;
	lzip)	opts[-initramfs]+=.cpio.lz;;
	lzop)	opts[-initramfs]+=.cpio.lzo;;
esac
echo ">>> building ${opts[-initramfs]}..."
rm -rf "${opts[-initramfsdir]}" || die
mkdir -p "${opts[-initramfsdir]}" && pushd "${opts[-initramfsdir]}" || die
if [[ -d "${opts[-usrdir]}" ]]; then
	cp -ar "${opts[-usrdir]}" . && rm -f usr/README* || die
	mv -f {usr/,}root &>/dev/null; mv -f {usr/,}etc &>/dev/null || die
else mkdir -pm700 root; warn "${opts[-usrdir]} does not exist"; fi
mkdir -p run {,s}bin usr/{{,s}bin,share/{consolefonts,keymaps}} || die
mkdir -p dev proc sys newroot mnt/tok etc/{mkinitramfs-ll,splash,local.d} || die
mkdir -p lib${opts[-lib]}/{splash/cache,modules/${opts[-kversion]}} || die
ln -sf lib${opts[-lib]} lib || die
cp -a /dev/{console,random,urandom,mem,null,tty,tty[0-6],zero} dev/ || addnodes
if [[ $(echo ${opts[-kversion]} | cut -d'.' -f1 ) -eq 3 ]] && \
	[[ $(echo ${opts[-kversion]} | cut -d'.' -f2) -ge 1 ]]; then
	cp -a {/,}dev/loop-control &>/dev/null || mknod dev/loop-control c 10 237 || die
fi
cp -a "${opts[-workdir]}"/init . && chmod 775 init && mkdir -pm700 root || die
cp -af {/,}lib/modules/${opts[-kversion]}/modules.dep || die "failed to copy modules.dep"
if [[ -x usr/bin/busybox ]]; then mv -f {usr/,}bin/busybox
elif which busybox &> /dev/null &&
	[[ $(ldd $(which busybox)) == *"not a dynamic executable" ]]; then
	cp -a $(which busybox) bin/
elif which bb &>/dev/null; then cp -a $(which bb) bin/busybox
else die "there's no busybox nor bb binary"; fi
if [[ -f etc/mkinitramfs-ll/busybox.app ]]; then continue
else bin/busybox --list-full > etc/mkinitramfs-ll/busybox.app || die; fi
for app in $(< etc/mkinitramfs-ll/busybox.app); do	
	ln -fs /bin/busybox ${app}
done
if [[ -n "${opts[-luks]}" ]]; then
	[[ -n "$(echo ${opts[-bin]} | grep cryptsetup)" ]] || opts[-bin]+=:cryptsetup
fi
if [[ -n "${opts[-sqfsd]}" ]]; then opts[-bin]+=:umount.aufs:mount.aufs
	for fs in {au,squash}fs; do 
		[[ -n "$(echo ${opts[-msqfsd]} | grep ${fs})" ]] || opts[-msqfsd]+=:${fs}
	done
fi
if [[ -n "${opts[-gpg]}" ]]; then
	if [[ -x usr/bin/gpg ]]; then continue
	elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) == 1 ]]; then
		opts[-bin]+=":$(which gpg)"
	else die "there's no usable gpg/gnupg-1.4.x binary"; fi
	[[ -f root/.gnupg/gpg.conf ]] && ln -sf {root/,}.gnupg ||
		warn "no gpg.conf was found"
fi
if [[ -n "${opts[-lvm]}" ]]; then opts[-bin]+=:lvm.static
	pushd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -sf lvm ${lpv} || die
	done
	popd
fi
if [[ -n "${opts[-raid]}" ]]; then opts[-bin]+=:mdadm.static:mdadm
	cp /etc/mdadm.conf etc/ &>/dev/null || warn "failed to copy /etc/mdadm.conf"
fi
addmodule() {
	local ret
	for mod in $@; do
		local module=$(find /lib/modules/${opts[-kversion]} -name ${mod}.ko -or -name ${mod}.o)
		if [ -n "${module}" ]; then mkdir -p .${module%/*}
			cp -ar ${module} .${module} || die "failed to copy ${module} module"
		else warn "${mod} does not exist"; ((ret=${ret}+1)); fi
	done
	return ${ret}
}
addmodule ${opts[-mdep]//:/ }
for grp in boot gpg sqfsd remdev tuxonice; do
	if [[ -n "${opts[-m${grp}]}" ]]; then
		for mod in ${opts[-m${grp}]//:/ }; do 
			addmodule ${mod} && echo ${mod} >> etc/mkinitramfs-ll/module.${grp}
		done
	fi
done
for keymap in ${opts[-keymap]//:/ }; do
	if [[ -f usr/share/keymaps/"${keymap}" ]]; then continue
	elif [[ -f "${keymap}" ]]; then cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} > usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	fi
done
for font in ${opts[-font]//:/ }; do
	if [[ -f usr/share/consolefonts/${font} ]]; then continue
	elif [[ -f ${font} ]]; then cp -a ${font} usr/share/consolefonts/ 
	else 
		for file in $(ls /usr/share/consolefonts/${font}*.gz); do
			if [[ -f ${file} ]]; then
				cp ${file} . 
				gzip -d ${file##*/}
			fi
		done
		mv ${font}* usr/share/consolefonts/
	fi
done
if [[ -n "${opts[-splash]}" ]]; then opts[-bin]+=:splash_util.static
	[[ -n "${opts[-toi]}" ]] && opts[-bin]+=:tuxoniceui_text
	for theme in ${opts[-splash]//:/ }; do 
		if [[ -d etc/splash/${theme} ]]; then continue 
		elif [[ -d /etc/splash/${theme} ]]; then cp -r {/,}etc/splash/${theme}
		elif [[ -d ${theme} ]]; then cp -ar ${theme} etc/splash/ 
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
for bin in ${opts[-bin]//:/ }; do
	if [[ -x usr/bin/${bin##*/} ]] || [[ -x usr/sbin/${bin##*/} ]] ||
	[[ -x bin/${bin##*/} ]] || [[ -x sbin/${bin##*/} ]]; then continue
	elif [[ -x ${bin} ]]; then bcp ${bin}
	else bcp $(which ${bin##*/}); fi
done
find . -print0 | cpio --null -ov --format=newc | ${opts[-comp]} > "${opts[-initramfs]}" || die
echo ">>> ${opts[-initramfs]} initramfs built"
unset -v opt opts
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
