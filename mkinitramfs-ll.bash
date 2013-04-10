#!/bin/bash
# $Id: mkinitramfs-ll/mkinitramfs-ll.bash,v 0.12.0 2012/11/05 23:51:55 -tclover Exp $
revision=0.12.0

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${1##*/} [-a|-all] [-f|--font=[font]] [-y|--keymap=[keymap]] [options]

  -a, --all                 short hand or forme of '-sqfsd -luks -lvm -gpg -toi'
  -f, --font [:ter-v14n]    include a colon separated list of fonts to the initramfs
  -k, --kversion 3.4.4-git  build an initramfs for kernel 3.4.4-git or else \$(uname -r)
  -c, --comp ['gzip -9']    use 'gzip -9' command instead default compression command
  -L, --luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l, --lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b, --bin :<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d, --usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -W, --workdir [<dir>]     use <dir> as a work directory to create initramfs instead of \$PWD
  -M, --module <name>       include <name> module from [..\/]mkinitramfs-ll.d module directory
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
  -u, --usage               print this help or usage message and exit
  -v, --version             print version string and exit

 usage: without an argument, generate an default initramfs for kernel \$(uname -r)
 usgae: generate an initramfs with LUKS, GnuPG, LVM2 and aufs+squashfs support
 ${0##*/} -a -f -y -k$(uname -r)
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
info() 	{ echo -ne " \e[1;32m* \e[0m$@\n"; }
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
warn() 	{ echo -ne " \e[1;33m* \e[0m$@\n"; }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   { error "$@"; exit 1; }

# @FUNCTION: adn
# @DESCRIPTION: ADd the essential Nodes to be able to boot
adn() {
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod -m 666 dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod -m 666 dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod -m 640 dev/mem     c 1 1 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod -m 666 dev/zero    c 1 5 || die
	for nod in $(seq 0 6); do 
		[[ -c dev/tty${nod} ]] || mknod -m 600 dev/tty${nod} c 4 ${nod} || die
	done
}

opt=$(getopt  -l all,bin:,comp::,font::,gpg,mboot::,mdep::,mgpg::,msqfsd::,mremdev:: \
	  -l module:,mtuxonice::,sqfsd,toi,usage,usrdir::,version \
	  -l keymap::,luks,lvm,workdir::,kversion::,prefix::,splash::,regen \
	  -o ab:c::d::f::gk::lLM:m::p::rs::tuvy::W:: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
declare -A opts

while [[ $# > 0 ]]; do
	case $1 in
		-v|--version) echo "${0##*/}-$revision"; exit 0;;
		-a|--all) opts[-sqfsd]=y; opts[-gpg]=y;
			opts[-lvm]=y; opts[-luks]=y; shift;;
		-R|--regen) opts[-regen]=y; shift;;
		-q|--sqfsd) opts[-sqfsd]=y; shift;;
		-b|--bin) opts[-bin]+=:${2}; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-d|--usrdir) opts[-usrdir]=${2}; shift 2;;
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
		-M|--module) opts[-module]+=":${2}"; shift 2;;
		-m|--mdep) opts[-mdep]+=":${2}"; shift 2;;
		-p|--prefix) opts[-prefix]=${2}; shift 2;;
		-y|--keymap) 
			opts[-keymap]+=:"${2:-$(grep -E '^keymap' /etc/conf.d/keymaps|cut -d'"' -f2)}"
			shift 2;;
		-f|--font) 
			opts[-font]+=":${2:-$(grep -E '^consolefont' /etc/conf.d/consolefont|cut -d'"' -f2)}"
			shift 2;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done

[[ -f mkinitramfs-ll.conf ]] && source mkinitramfs-ll.conf ||
	die "no mkinitramfs-ll.conf found"

# @VARIABLE: opts[-kversion]
# @DESCRIPTION: kernel version to pick up
[[ -n "${opts[-kversion]}" ]] || opts[-kversion]="$(uname -r)"
# @VARIABLE: opts[-workdir]
# @DESCRIPTION: initial working directory, where to build everythng
[[ -n "${opts[-workdir]}" ]] || opts[-workdir]="$(pwd)"
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix.$kversion.$ext>
[[ -n "${opts[-prefix]}" ]] || opts[-prefix]=initramfs-
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
[[ -n "${opts[-usrdir]}" ]] || opts[-usrdir]="${opts[-workdir]}"/usr
# @VARIABLE: opts[-initdir]
# @DESCRIPTION: initramfs dir, where to put everythng before actualy generating
# an initramfs compressed image
opts[-initdir]="${opts[-workdir]}"/${opts[-prefix]}${opts[-kversion]}
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
opts[-initramfs]=/boot/${opts[-prefix]}${opts[-kversion]}
[[ -n "${opts[-comp]}" ]] || opts[-comp]="xz -9 --check=crc32"
[[ -n "$(uname -m | grep 64)" ]] && opts[-arc]=64 || opts[-arc]=32
# @VARIABLE: opts[-arch]
# @DESCRIPTION: kernel architecture
[[ -n "${opts[-arch]}" ]] || opts[-arch]=$(uname -m)

case ${opts[-comp]%% *} in
	bzip2)	opts[-initramfs]+=.cpio.bz2;;
	gzip) 	opts[-initramfs]+=.cpio.gz;;
	xz) 	opts[-initramfs]+=.cpio.xz;;
	lzma)	opts[-initramfs]+=.cpio.lzma;;
	lzip)	opts[-initramfs]+=.cpio.lz;;
	lzop)	opts[-initramfs]+=.cpio.lzo;;
esac

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
docpio() { 
	find . -print0 | cpio -0 -ov -Hnewc | ${opts[-comp]} > ${opts[-initramfs]}
}

if [[ -n ${opts[-regen]} ]]; then
	[[ -d ${opts[-initdir]} ]] || die "${opts[-initdir]}: no old initramfs dir"
	echo ">>> regenerating ${opts[-initramfs]}..."
	pushd ${opts[-initdir]} || die
	cp -af ${opts[-workdir]}/init . && chmod 775 init || die
	docpio || die
	echo ">>> regenerated ${opts[-initramfs]}..." && exit
fi

echo ">>> building ${opts[-initramfs]}..."

rm -rf "${opts[-initdir]}" || die
mkdir -p "${opts[-initdir]}" && pushd "${opts[-initdir]}" || die
if [[ -d "${opts[-usrdir]}" ]]; then
	cp -ar "${opts[-usrdir]}" . && rm -f usr/README* || die
	mv -f {usr/,}root 1>/dev/null 2>&1 && mv -f {usr/,}etc 1>/dev/null 2>&1 &&
	mv -f usr/lib lib${opts[-arc]} || die
else 
	die "${opts[-usrdir]} not found"
fi

mkdir -p {,s}bin usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} || die
mkdir -p dev proc sys newroot mnt/tok etc/{mkinitramfs-ll{,.d},splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kversion]},mkinitramfs-ll} || die
ln -sf lib{${opts[-arc]},} &&
	pushd usr && ln -sf lib{${opts[-arc]},} && popd || die

cp -a /dev/{console,random,urandom,mem,null,tty,tty[0-6],zero} dev/ || adn
if [[ $(echo ${opts[-kversion]} | cut -d'.' -f1 ) -eq 3 ]] && \
	[[ $(echo ${opts[-kversion]} | cut -d'.' -f2) -ge 1 ]]; then
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
fi

cp -a "${opts[-workdir]}"/init . && chmod 775 init && mkdir -pm700 root || die
cp -af {/,}lib/modules/${opts[-kversion]}/modules.dep ||
	die "failed to copy modules.dep"

for mod in ${opts[-module]//:/ }; do
	cp -a ${opts[-usrdir]}/..\/mkinitramfs-ll.d/*$mod* etc/mkinitramfs-ll.d/
done

[ -f /etc/issue.logo ] && cp {/,}etc/issue.logo

if [[ -x usr/bin/busybox ]]; then
	mv -f {usr/,}bin/busybox
elif which busybox 1>/dev/null 2>&1 &&
	[[ $(ldd $(which busybox)) == *"not a dynamic executable" ]]; then
	cp -a $(which busybox) bin/
elif which bb 1>/dev/null 2>&1; then
	cp -a $(which bb) bin/busybox
else
	die "there's no suitable busybox/bb binary"
fi

if [[ -f etc/mkinitramfs-ll/busybox.app ]]; then :;
else
	bin/busybox --list-full >etc/mkinitramfs-ll/busybox.app || die
fi
for app in $(< etc/mkinitramfs-ll/busybox.app); do	
	ln -fs /bin/busybox ${app}
done

if [[ -n "${opts[-luks]}" ]]; then
	opts[-bin]+=:cryptsetup opts[-kmodule]+=:dm-crypt
fi
if [[ -n "${opts[-sqfsd]}" ]]; then
	opts[-bin]+=:umount.aufs:mount.aufs opts[-kmodule]+=:sqfsd
fi
if [[ -n "${opts[-gpg]}" ]]; then
	opts[-kmodule]+=:gpg
	if [[ -x usr/bin/gpg ]]; then :;
	elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) == 1 ]]; then
		opts[-bin]+=":$(which gpg)"
	else
		die "there's no usable gpg/gnupg-1.4.x binary"
	fi
	[[ -f root/.gnupg/gpg.conf ]] &&
		ln -sf {root/,}.gnupg && chmod 700 root/.gnupg/gpg.conf ||
		warn "no gpg.conf was found"
fi
if [[ -n "${opts[-lvm]}" ]]; then
	opts[-bin]+=:lvm:lvm.static opts[-kmodule]+=:device-mapper
	pushd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -sf lvm ${lpv} || die
	done
	popd
fi

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
domod() {
	local mod module ret
	for mod in "$@"; do
		module=$(find /lib/modules/${opts[-kversion]} -name ${mod}.ko -or -name ${mod}.o)
		if [ -n "${module}" ]; then
			mkdir -p .${module%/*} && cp -ar {,.}${module} ||
				die "failed to copy ${odulem} module"
		else
			warn "${mod} does not exist"
			((ret=${ret}+1))
		fi
	done
	return ${ret}
}

for bin in dmraid mdadm zfs; do
	[[ -n $(echo ${opts[-bin]} | grep $bin) ]] && opts[-kmodule]+=:$bin
done

opts[-kmodule]=${opts[-kmodule]/mdadm/raid}

for keymap in ${opts[-keymap]//:/ }; do
	if [[ -f usr/share/keymaps/"${keymap}" ]]; then :;
	elif [[ -f "${keymap}" ]]; then
		cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} >usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	fi
done

for font in ${opts[-font]//:/ }; do
	if [[ -f usr/share/consolefonts/${font} ]]; then :;
	elif [[ -f ${font} ]]; then
		cp -a ${font} usr/share/consolefonts/ 
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

if [[ -n "${opts[-splash]}" ]]; then
	opts[-bin]+=:splash_util.static:fbcondecor_helper
	
	[[ -n "${opts[-toi]}" ]] &&
		opts[-bin]+=:tuxoniceui_text && opts[-kmodule]+=:tuxonice
	
	for theme in ${opts[-splash]//:/ }; do 
		if [[ -d etc/splash/${theme} ]]; then :; 
		elif [[ -d /etc/splash/${theme} ]]; then
			cp -r {/,}etc/splash/${theme}
		elif [[ -d ${theme} ]]; then
			cp -ar ${theme} etc/splash/ 
		else
			warn "failed to copy ${theme} theme"
		fi
	done
fi

# @FUNCTION: dobin
# @DESCRIPTION: copy binary with libraries if not static
dobin() {
	for bin in $@; do
		if [[ -x ${bin} ]]; then
			cp -a ${bin} .${bin/%.static}
			if [[ -L ${bin} ]]; then
				bin=$(which $(readlink ${bin})) && cp -au {,.}${bin} || die
			fi
			if [[ "$(ldd ${bin})" != *"not a dynamic executable"* ]]; then
				for lib in $(ldd ${bin} | tail -n+2 | sed -e 's:li.*=>\ ::g' -e 's:\ (.*)::g')
				do mkdir -p .${lib%/*} && cp -adH {,.}${lib} || die
				done
				warn "${bin} is not a static binary."
			fi
		else
			warn "${bin} binary doesn't exist"
		fi
	done
}

for bin in ${opts[-bin]//:/ }; do
	if [[ -x usr/bin/${bin##*/} ]] || [[ -x usr/sbin/${bin##*/} ]] ||
	[[ -x bin/${bin##*/} ]] || [[ -x sbin/${bin##*/} ]]; then :;
	elif [[ -x ${bin} ]]; then
		dobin ${bin}
	else
		which ${bin##*/} 1>/dev/null 2>&1 && dobin $(which ${bin##*/}) ||
		warn "no ${bin} binary found"
	fi
done

domod ${opts[-mdep]//:/ }

for grp in ${opts[-kmodule]//:/ }; do
	if [[ -n "${opts[-m${grp}]}" ]]; then
		for mod in ${opts[-m${grp}]//:/ }; do 
			domod ${mod} && echo ${mod} >>etc/mkinitramfs-ll/module.${grp}
		done
	fi
done

docpio || die

echo ">>> ${opts[-initramfs]} initramfs built"

unset -v opt opts

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
