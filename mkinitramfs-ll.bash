#!/bin/bash
# $Id: mkinitramfs-ll/mkinitramfs-ll.bash,v 0.13.1 2014/08/08 12:33:03 -tclover Exp $
basename=${0##*/}
# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage()
{
  cat <<-EOF
  $basename-0.13.1
  usage: $basename [-a|-all] [-f|--font=[font]] [-y|--keymap=[keymap]] [options]

  -a, --all                 short hand or forme of '-f -l -L -g -M:zfs:zram -t -q -y'
  -f, --font [:ter-v14n]    include a colon separated list of fonts to the initramfs
  -F, --firmware [:file]    append firmware file or directory (relative to /lib/firmware),
                            or else full path, or the whole /lib/firmware dir if empty
  -k, --kv 3.4.4-git        build an initramfs for kernel 3.4.4-git or else \$(uname -r)
  -c, --comp ['gzip -9']    use 'gzip -9' command instead default compression command
  -L, --luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l, --lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b, --bin :<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d, --usrdir [usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -M, --module :<name>      include <name> module or script from modules directory
  -m, --kmod [:<mod>]       include a colon separated list of kernel modules to the initramfs
      --mtuxonice [:<mod>]  include a colon separated list of kernel modules to tuxonice group
      --mremdev [:<mod>]    include a colon separated list of kernel modules to remdev  group
      --msquashd [:<mod>]   include a colon separated list of kernel modules to squashd group
      --mgpg [:<mod>]       include a colon separated list of kernel modules to gpg     group
      --mboot [:<mod>]      include a colon separated list of kernel modules to boot   group
  -s, --splash [:<theme>]   include a colon separated list of splash themes to the initramfs
  -t, --toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q, --squashd             add AUFS+squashfs, {,u}mount.aufs, or squashed dir support
  -r, --regen               regenerate a new initramfs from an old dir with newer init
  -y, --keymap :fr-latin1   include a colon separated list of keymaps to the initramfs
  -K, --keeptmp             keep temporary files instead of removing the tmpdir
  -h, --help, -?            print this help or usage message and exit

  usage: build an initramfs for kernel \$(uname -r) if run without an argument
  usgae: generate an initramfs with LUKS, GnuPG, LVM2 and AUFS+squashfs support
  $basename -a -f -y -k$(uname -r)
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error()
{
	echo -ne " \e[1;31m* \e[0m$@\n"
}
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
function info() {
	echo -ne " \e[1;32m* \e[0m$@\n"
}
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
function warn()
{
	echo -ne " \e[1;33m* \e[0m$@\n"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die()
{
	local ret=$?
	error "$@"
	exit $ret
}

# @FUNCTION: mktmp
# @DESCRIPTION: make tmp dir or file in ${TMPDIR:-/tmp}
# @ARG: -d|-f [-m <mode>] [-o <owner[:group]>] [-g <group>] TEMPLATE
function mktmp()
{
	local tmp=${TMPDIR:-/tmp}/$1-XXXXXX
	mkdir -p ${mode:+-m$mode} $tmp ||
	die "mktmp: failed to make $tmp"
	echo "$tmp"
}

# @FUNCTION: adn
# @DESCRIPTION: ADd the essential Nodes to be able to boot
function adn()
{
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod -m 666 dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod -m 666 dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod -m 640 dev/mem     c 1 1 && chmod 0:9 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod -m 666 dev/zero    c 1 5 || die

	for n in $(seq 0 6); do 
		[[ -c dev/tty$n ]] || mknod -m600 dev/tty$n c 4 $n && chmod 0:5 || die
	done
}

opt=$(getopt  -l all,bin:,comp::,font::,gpg,mboot::,kmod::,mgpg::,msquashd::,mremdev:: \
	  -l keeptmp,module:,mtuxonice::,squashd,toi,help,usrdir:: \
	  -l firmware::,keymap::,luks,lvm,kv::,prefix::,splash::,regen \
	  -o ?ab:c::d::f::F::gk::lKLM:m::np::qrs::thy:: -n ${0##*/} -- "$@" || usage)
eval set -- "$opt"

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
declare -A opts

while [[ $# > 0 ]]; do
	case $1 in
		-a|--all) opts[-squashd]=y; opts[-gpg]=y; opts[-toi]=y;
			opts[-lvm]=y; opts[-luks]=y; opts[-module]+=:zfs:zram; shift;;
		-r|--regen) opts[-regen]=y; shift;;
		-q|--squashd) opts[-squashd]=y; shift;;
		-K|--keeptmp) opts[-keeptmp]=y; shift;;
		-b|--bin) opts[-bin]+=:${2}; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-d|--usrdir) opts[-usrdir]=${2}; shift 2;;
		-k|--kv) opts[-kv]=${2}; shift 2;;
		-g|--gpg) opts[-gpg]=y; shift;;
		-t|--toi) opts[-toi]=y; shift;;
		-l|--lvm) opts[-lvm]=y; shift;;
		-L|--luks) opts[-luks]=y; shift;;
		--mgpg) opts[-mgpg]+=:${2}; shift 2;;
		--mboot) opts[-mboot]+=:${2}; shift 2;;
		--msquashd) opts[-msquashd]+=:${2}; shift 2;;
		--mremdev) opts[-mremdev]+=:${2}; shift 2;;
		--mtuxonice) opts[-tuxonice]+=:${2}; shift 2;;
		-s|--splash) opts[-splash]+=":${2}"; shift 2;;
		-M|--module) opts[-module]+=":${2}"; shift 2;;
		-m|--kmod) opts[-kmod]+=":${2}"; shift 2;;
		-p|--prefix) opts[-prefix]=${2}; shift 2;;
		-y|--keymap) opts[-keymap]+=:"${2}"
			[[ ${2} ]] || [[ -e /etc/conf.d/keymaps ]] &&
			opts[-keymap]+=$(sed -nre 's,^keymap="([a-zA-Z].*)",\1,p' \
				/etc/conf.d/keymaps)
			shift 2;;
		-f|--font) opts[-font]+=":${2}"
			[[ ${2} ]] || [[ -e /etc/conf.d/consolefont ]] &&
			opts[-font]+=$(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' \
				/etc/conf.d/consolefont)
			shift 2;;
		-F|--firmware) opts[-firmware]+=:"${2:-/lib/firmware}"; shift 2;;
		--) shift; break;;
		-?|-h|--help|*) usage;;
	esac
done

[[ -f mkinitramfs-ll.conf ]] &&
	source mkinitramfs-ll.conf ||
	die "no mkinitramfs-ll.conf found"

# @VARIABLE: opts[-kv]
# @DESCRIPTION: kernel version to pick up
[[ "${opts[-kv]}" ]] || opts[-kv]="$(uname -r)"
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix-$kv.$ext>
[[ "${opts[-prefix]}" ]] || opts[-prefix]=initramfs-
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
[[ "${opts[-usrdir]}" ]] || opts[-usrdir]="${PWD}"/usr
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
opts[-initramfs]=${opts[-prefix]}${opts[-kv]}
[[ "${opts[-comp]}" ]] || opts[-comp]="xz -9 --check=crc32"
# @VARIABLE: opts[-arch]
# @DESCRIPTION: kernel architecture
[[ "${opts[-arch]}" ]] || opts[-arch]=$(uname -m)
# @VARIABLE: opts[-arc]
# @DESCRIPTION: kernel bit lenght supported
[[ "${opts[-arc]}" ]] || opts[-arc]=$(getconf LONG_BIT)
# @VARIABLE: opts[-tmpdir]
# @DESCRIPTION: tmp dir where to generate initramfs
# an initramfs compressed image
opts[-tmpdir]="$(mktmp ${opts[-initramfs]})"

case ${opts[-comp]%% *} in
	bzip2)	opts[-initramfs]+=.cpio.bz2;;
	gzip) 	opts[-initramfs]+=.cpio.gz;;
	xz) 	opts[-initramfs]+=.cpio.xz;;
	lzma)	opts[-initramfs]+=.cpio.lzma;;
	lzip)	opts[-initramfs]+=.cpio.lz;;
	lzop)	opts[-initramfs]+=.cpio.lzo;;
	lz4)    opts[-initramfs]+=.cpio.lz4;;
esac

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
function docpio()
{
	local initramfs=${1:-/boot/${opts[-initramfs]}}
	find . -print0 | cpio -0 -ov -Hnewc | ${opts[-comp]} > ${initramfs}
}

if [[ -f /boot/${opts[-initramfs]} ]]; then
	mv /boot/${opts[-initramfs]}{,.old}
fi

echo ">>> building ${opts[-initramfs]}..."
pushd "${opts[-tmpdir]}" || die "${opts[-tmpdir]} not found"

if [[ ${opts[-regen]} ]]; then
	cp -af ${opts[-usrdir]}/lib/mkinitramfs-ll/functions lib/mkinitramfs-ll &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio /boot/${opts[-initramfs]} || die
	echo ">>> regenerated ${opts[-initramfs]}..." && exit
else
	rm -fr *
fi

if [[ -d "${opts[-usrdir]}" ]]; then
	cp -ar "${opts[-usrdir]}" . &&
	mv -f {usr/,}root &&
	mv -f {usr/,}etc &&
	mv -f usr/lib lib${opts[-arc]} || die
else 
	die "${opts[-usrdir]} dir not found"
fi

mkdir -p usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} || die
mkdir -p {,s}bin dev proc sys newroot mnt/tok etc/{mkinitramfs-ll,splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kv]},mkinitramfs-ll} || die
ln -sf lib{${opts[-arc]},} &&
	pushd usr && ln -sf lib{${opts[-arc]},} && popd || die

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || adn
if [[ $(echo ${opts[-kv]} | cut -d'.' -f1 ) -eq 3 ]] &&
	[[ $(echo ${opts[-kv]} | cut -d'.' -f2) -ge 1 ]]; then
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
fi

cp -a "${opts[-usrdir]}"/../init . && chmod 775 init || die
[[ -d root ]] && chmod 0700 root || mkdir -m700 root || die
cp -af {/,}lib/modules/${opts[-kv]}/modules.dep ||
	die "failed to copy modules.dep"

if [[ ${opts[-firmware]} ]]; then
	mkdir -p lib/firmware
	for f in ${opts[-firmware]//:/ }; do
		if [[ -e $f ]] || [[ -d $f ]]; then
			cp -a $f lib/firmware/ || warn "failed to copy $f firmware"
		elif [[ -e /lib/firmware/$f ]] || [[ -d /lib/firmware/$f ]]; then
			cp -a {/,}lib/firmware/$f || warn "failed to copy $f firmware"
		else 
			warn "failed to copy $f firmware"
		fi
	done
fi

for bin in dmraid mdadm zfs; do
	[[ -n $(echo ${opts[-bin]} | grep $bin) ]] && opts[-mgrp]+=:$bin
done
opts[-mgrp]=${opts[-mgrp]/mdadm/raid}

for mod in ${opts[-module]//:/ }; do
	if [[ -e ${opts[-usrdir]}/..\/modules/*$mod* ]]; then
		warn "$mod module does not exist"
		continue
	fi
	cp -a ${opts[-usrdir]}/..\/modules/*$mod* lib/mkinitramfs-ll/
	opts[-bin]+=:${opts[-b$mod]}
	opts[-mgrp]+=:$mod
done

[[ -f /etc/issue.logo ]] && cp {/,}etc/issue.logo

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

if [[ ! -f etc/mkinitramfs-ll/busybox.app ]]; then
	bin/busybox --list-full >etc/mkinitramfs-ll/busybox.app || die
fi
while read line; do
	ln -fs /bin/busybox $line
done <etc/mkinitramfs-ll/busybox.app

if [[ ${opts[-luks]} ]]; then
	opts[-bin]+=:cryptsetup opts[-mgrp]+=:dm-crypt
fi

if [[ ${opts[-squashd]} ]]; then
	opts[-bin]+=:umount.aufs:mount.aufs opts[-mgrp]+=:squashd
fi

if [[ ${opts[-gpg]} ]]; then
	opts[-mgrp]+=:gpg
	if [[ -x usr/bin/gpg ]]; then :;
	elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) == 1 ]]; then
		opts[-bin]+=":$(which gpg)"
	else
		die "there's no usable gpg/gnupg-1.4.x binary"
	fi
fi

if [[ ${opts[-lvm]} ]]; then
	opts[-bin]+=:lvm opts[-mgrp]+=:device-mapper
	pushd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -sf lvm ${lpv} || die
	done
	popd
fi

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
function domod()
{
	local mod module ret
	for mod in "$@"; do
		module=$(find /lib/modules/${opts[-kv]} -name ${mod}.ko -or -name ${mod}.o)
		if [[ ${module} ]]; then
			mkdir -p .${module%/*} && cp -ar {,.}${module} ||
				die "failed to copy ${odulem} module"
		else
			warn "${mod} does not exist"
			((ret=${ret}+1))
		fi
	done
	return ${ret}
}

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

# @FUNCTION: docp
# @DESCRIPTION: follow and copy link until binary/library is copied
function docp()
{
	local link=${1} prefix
	[[ -n ${link} ]] || return
	cp -a {,.}${link}

	[[ -h ${link} ]] &&
	while true; do
	    prefix=${link%/*}
		link=$(readlink ${link})
		[[ ${link%/*} == ${link} ]] && link=${prefix}/${link}
		cp -a {,.}${link} || die
		[[ -h ${link} ]] || break
	done

	return 0
}

# @FUNCTION: dobin
# @DESCRIPTION: copy binary with libraries if not static
function dobin()
{
	local lib
	docp ${bin} || return

	[[ "$(ldd ${bin})" == "not a dynamic executable" ]] && return 0

	for lib in $(ldd ${bin} | sed -nre 's,.* ((/usr|)/lib.*/.*.so.*) .*,\1,p'); do
		mkdir -p .${lib%/*} && docp ${lib} || die
	done
}

for bin in ${opts[-bin]//:/ }; do
	for b in {usr/,}{,s}bin/${bin}; do
		[[ -x ${b} ]] && continue 2
	done

	[[ -x ${bin} ]] && dobin ${bin}
	bin=$(which ${bin} 2>/dev/null)
	dobin ${bin} || warn "no ${bin} binary found"
done

domod ${opts[-kmod]//:/ }

for grp in ${opts[-mgrp]//:/ }; do
	if [[ -n "${opts[-m${grp}]}" ]]; then
		for mod in ${opts[-m${grp}]//:/ }; do 
			domod ${mod} && echo ${mod} >>etc/mkinitramfs-ll/${grp}
		done
	fi
done

for lib in $(find usr/lib/gcc -iname 'lib*'); do
	ln -fs /$lib     lib/${lib##*/}
	ln -fs /$lib usr/lib/${lib##*/}
done

docpio /boot/${opts[-initramfs]} || die

[[ ${opts[-keeptmp]} ]] || rm -rf ${opts[-dir]}

echo ">>> ${opts[-initramfs]} initramfs built"

unset -v opt opts

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
