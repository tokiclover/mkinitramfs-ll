#!/bin/bash
#
# $Header: mkinitramfs-ll/mkinitramfs-ll.bash            Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.8 2014/10/01 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	[name]=mkinitramfs-ll
	[shell]=bash
	[version]=0.13.8
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [-a|-all] [-f|--font=[font]] [-y|--keymap=[keymap]] [options]

  -a, --all                 short hand or forme of '-l -L -g -M:zfs:zram -t -q'
  -f, --font=[:ter-v14n]    include a colon separated list of fonts to the initramfs
  -F, --firmware=[:file]    append firmware file or directory (relative to /lib/firmware),
                            or else full path, or the whole /lib/firmware dir if empty
  -k, --kv=3.4.4-git        build an initramfs for kernel 3.4.4-git or else \$(uname -r)
  -c, --compressor='gzip -9' use 'gzip -9' compressor instead of default, accept 'none'
  -L, --luks                add LUKS support, require a sys-fs/cryptsetup binary
  -l, --lvm                 add LVM support, require a static sys-fs/lvm2 binary
  -b, --bin=:<bin>          include a colon separated list of binar-y-ies to the initramfs
  -d, --usrdir=[usr]        use usr dir for user extra files, binaries, scripts, fonts...
  -g, --gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, --prefix=initrd-      use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -M, --module=:<name>      include <name> module or script from modules directory
  -m, --kmod=[:<mod>]       include a colon separated list of kernel modules to the initramfs
      --mtuxonice=[:<mod>]  include a colon separated list of kernel modules to tuxonice group
      --mremdev=[:<mod>]    include a colon separated list of kernel modules to remdev  group
      --msquashd=[:<mod>]   include a colon separated list of kernel modules to squashd group
      --mgpg=[:<mod>]       include a colon separated list of kernel modules to gpg     group
      --mboot=[:<mod>]      include a colon separated list of kernel modules to boot   group
  -s, --splash=[:<theme>]   include a colon separated list of splash themes to the initramfs
  -t, --toi                 add tuxonice support, require tuxoniceui_text binary for splash
  -q, --squashd             add AUFS+squashfs, {,u}mount.aufs, or squashed dir support
  -r, --rebuild             regenerate a new initramfs from an old dir with newer init
  -y, --keymap=:fr-latin1   include a colon separated list of keymaps to the initramfs
  -K, --keep-tmpdir         keep temporary the directory instead of removing it
  -h, --help, -?            print this help or usage message and exit

  usage: build an initramfs for kernel \$(uname -r) if run without an argument
  usgae: generate an initramfs with LUKS, GnuPG, LVM2 and AUFS+squashfs support
  ${PKG[name]}.${PKG[shell]} -a -f -y -k$(uname -r)
EOH
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	echo -ne " \e[1;31m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
function info {
	echo -ne " \e[1;32m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n"
}
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
function warn {
	echo -ne " \e[1;33m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error "$@"
	exit $ret
}

# @FUNCTION: mktmp
# @DESCRIPTION: make tmp dir or file in ${TMPDIR:-/tmp}
# @ARG: -d|-f [-m <mode>] [-o <owner[:group]>] [-g <group>] TEMPLATE
function mktmp {
	local tmp=${TMPDIR:-/tmp}/$1-XXXXXX
	mkdir -p $tmp || die "mktmp: failed to make $tmp"
	echo "$tmp"
}

# @FUNCTION: donod
# @DESCRIPTION: add the essential nodes to be able to boot
function donod {
	pushd dev || die
	[[ -c console ]] || mknod -m 600 console c 5 1 || die
	[[ -c urandom ]] || mknod -m 666 urandom c 1 9 || die
	[[ -c random ]]  || mknod -m 666 random  c 1 8 || die
	[[ -c mem ]]     || mknod -m 640 mem     c 1 1 && chmod 0:9 mem || die
	[[ -c null ]]    || mknod -m 666 null    c 1 3 || die
	[[ -c tty ]]     || mknod -m 666 tty     c 5 0 || die
	[[ -c zero ]]    || mknod -m 666 zero    c 1 5 || die

	for (( i=0; i<8; i++ )); do
		[[ -c tty${i} ]] || mknod -m 600 tty${i} c 4 ${i} || die
	done
	popd || die
}

shopt -qs extglob nullglob

declare -a opt
opt=(
	"-o" "ab:c::f::F::gk::lKLM:m::p::qrs::thu::y::?"
	"-l" "all,bin:,compressor::,firmware::,font::,gpg,help"
	"-l" "luks,lvm,keep-tmpdir,kmod::,keymap::,kv::"
	"-l" "mboot::,mgpg::,mremdev::,msquashd::,module:,mtuxonice::"
	"-l" "prefix::,rebuild,splash::,squashd,toi,usrdir::"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
declare -A opts

for (( ; $# > 0; )); do
	case $1 in
		(-[KLaglqrt]|--[aglrt]*|--sq*|--keep*)
			opts[${1/--/-}]=true
			shift;;
		(-[dkp]|--[pu]*|-kv)
			opts[${2/--/-}]="$2"
			shift 2;;
		(-[FMbcfmsy]|--[bcfkms]*)
			opts[${1/--/-}]+=":$2"
			shift 2;;
		(--)
			shift
			break;;
		(-?|-h|--help|*)
			usage;;
	esac
done

if [[ "${opts[-a]}" ]] || [[ "${opts[-all]}" ]]; then
	opts[-font]+=: opts[-gpg]=true opts[-lvm]=true opts[-squashd]=true
	opts[-toi]=true opts[-luks]=true opts[-keymap]+=:
	opts[-module]+=:zfs:zram
fi

for key in f{,ont}; do
if [[ "${opts[-$key]}" ]] && [[ "${opts[-$key]}" == ":" ]]; then
	if [[ -e /etc/conf.d/consolefont ]]; then
		opts[-font]+=$(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' \
			/etc/conf.d/consolefont)
	else
		warn "no console font found"
	fi
fi
done

for key in y keymap; do
if [[ "${opts[-$key]}" ]] && [[ "${opts[-$key]}" == ":" ]]; then
	if [[ -e /etc/conf.d/keymaps ]]; then
		opts[-keymap]+=:$(sed -nre 's,^keymap="([a-zA-Z].*)",\1,p' \
			/etc/conf.d/keymaps)
	else
		warn "no console keymap found"
	fi
fi
done

[[ -f "${PKG[name]}".conf ]] &&
	source "${PKG[name]}".conf ||
	die "no ${PKG[name]}.conf found"

# @VARIABLE: opts[-kv]
# @DESCRIPTION: kernel version to pick up
if [[ -z "${opts[-kv]}" ]]; then
	[[ "${opts[-k]}" ]] && opts[-kv]="${opts[-k]}" || opts[-kv]="$(uname -r)"
fi
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix-$kv.$ext>
if [[ -z "${opts[-prefix]}" ]]; then
	[[ "${opts[-p]}" ]] && opts[-prefix]="${opts[-p]}" ||
		opts[-prefix]=initramfs-
fi
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
if [[ -z "${opts[-usrdir]}" ]]; then
	[[ "${opts[-u]}" ]] && opts[-usrdir]="${opts[-u]}" ||
		opts[-usrdir]="${PWD}"/usr
fi
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
opts[-initramfs]=${opts[-prefix]}${opts[-kv]}
if [[ -z "${opts[-compressor]}" ]]; then
	[[ "${opts[-c]}" ]] && opts[-compressor]="${opts[-c]}" ||
		opts[-compressor]="xz -9 --check=crc32"
fi
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

declare -a compressor
compressor=(bzip2 gzip lzip lzop lz4 xz)

if [[ "${opts[-compressor]}" ]] && [[ "${opts[-compressor]}" != "none" ]]; then
	if [[ -e /usr/src/linux-${opts[-kv]}/.config ]]; then
		config=/usr/src/linux-${opts[-kv]}/.config
		xgrep=$(type -p grep)
	elif [[ -e /proc/config.gz ]]; then
		config=/proc/config.gz
		xgrep=$(type -p zgrep)
	else
		warn "no kernel config file found"
	fi
fi

if [[ "${config}" ]]; then
	COMP="${opts[-compressor]%% *}"
	CONFIG=CONFIG_RD_${COMP^^[a-z]}
	if ! ${xgrep} -q "^${CONFIG}=y" ${config}; then
		warn "${opts[-compressor]%% *} decompression is not supported by kernel-${opts[-kv]}"
		for (( i=0; i<${#compressor[@]}; i++ )); do
			COMP=${compressor[$i]}
			CONFIG=CONFIG_RD_${COMP^^[a-z]}
			if ${xgrep} -q "^${CONFIG}=y" ${config}; then
				opts[-compressor]="${compressor[$i]} -9"
				info "setting compressor to ${COMP}"
				break
			elif (( $i == (${#compressor[@]}-1) )); then
				die "no suitable decompressor support found in kernel-${opts[-kv]}"
			fi
		done
	fi
	unset config xgrep CONFIG COMP compressor
fi

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
function docpio {
	local ext=.cpio initramfs=${1:-${opts[-initramfs]}}
	local cmd="find . -print0 | cpio -0 -ov -Hnewc"

	case ${opts[-compressor]%% *} in
		(bzip2) ext+=.bz2;;
		(gzip)  ext+=.gz;;
		(xz)    ext+=.xz;;
		(lzma)  ext+=.lzma;;
		(lzip)  ext+=.lz;;
		(lzop)  ext+=.lzo;;
		(lz4)   ext+=.lz4;;
		(*) opts[-compressor]=; warn "initramfs will not be compressed";;
	esac

	if [[ -f /boot/${initramfs}${ext} ]]; then
	    mv /boot/${initramfs}${ext}{,.old}
	fi
	if [[ -n "${ext#.cpio}" ]]; then
		cmd+=" | ${opts[-compressor]} -c"
	fi

	eval ${cmd} >/boot/${initramfs}${ext} ||
		die "failed to generate /tmp/${initramfs}${ext}"
}

echo ">>> building ${opts[-initramfs]}..."
pushd "${opts[-tmpdir]}" || die "${opts[-tmpdir]} not found"

if [[ "${opts[-r]}" ]] || [[ "${opts[-regen]}" ]]; then
	cp -af {${opts[-usrdir]}/,}lib/${PKG[name]}/functions &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio "${opts[-initramfs]}" || die
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
mkdir -p {,s}bin dev proc sys newroot mnt/tok etc/{${PKG[name]},splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kv]},${PKG[name]}} || die
ln -sf lib{${opts[-arc]},} &&
	pushd usr && ln -sf lib{${opts[-arc]},} && popd || die

{
	for key in "${!PKG[@]}"; do
		echo "${key}=${PKG[$key]}"
	done
	echo "build=$(date +%Y-%m-%d-%T)"
} >etc/${PKG[name]}/id
touch etc/{fs,m}tab

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || donod

KV=(${kv/./ /})
if [[ "${KV[0]}" -eq 3 && "${KV[1]}" -ge 1 ]]; then
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
fi
unset KV

cp -a "${opts[-usrdir]}"/../init . && chmod 775 init || die
[[ -d root ]] && chmod 0700 root || mkdir -m700 root || die
cp -af {/,}lib/modules/${opts[-kv]}/modules.dep ||
	die "failed to copy modules.dep"

if [[ "${opts[-F]}" ]] || [[ "${opts[-firmware]}" ]]; then
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
	[[ "${opts[-bin]/$bin}" != "${opts[bin]}" ]] ||
		[[ "${opts[-b]/$bin}" != "${opts[-b]}" ]] && opts[-mgrp]+=":$bin"
done
opts[-mgrp]=${opts[-mgrp]/mdadm/raid}

for mod in ${opts[-M]//:/ } ${opts[-module]//:/ }; do
	for file in ${opts[-usrdir]}/../modules/*${mod}*; do
		cp -a "${file}" lib/${PKG[name]}/
	done
	(( $? != 0 )) && warn "$mod module does not exist"

	opts[-bin]+=:${opts[-b$mod]}
	opts[-mgrp]+=:$mod
done

[[ -f /etc/issue.logo ]] && cp {/,}etc/issue.logo

if [[ -x usr/bin/busybox ]]; then
	mv -f {usr/,}bin/busybox
elif type -p busybox >/dev/null; then
	bb=$(type -p busybox)
	if ldd ${bb} >/dev/null; then
		busybox --list-full >etc/${PKG[name]}/busybox.applets
		opts[-bin]+=:${bb}
		warn "busybox is not a static binary"
	fi
	cp -a ${bb} bin/
	unset bb
else
	die "no busybox binary found"
fi

if [[ ! -f etc/${PKG[name]}/busybox.applets ]]; then
	bin/busybox --list-full >etc/${PKG[name]}/busybox.applets || die
fi

while read line; do
	grep -q ${line} etc/${PKG[name]}/busybox.applets ||
	die "${line} applet not found, no suitable busybox found"
done <etc/${PKG[name]}/minimal.applets

pushd bin || die
for applet in $(grep '^bin' ../etc/${PKG[name]}/busybox.applets); do
	ln -s busybox ${applet#bin/}
done
popd
pushd sbin || die
for applet in $(grep '^sbin' ../etc/${PKG[name]}/busybox.applets); do
	ln -s ../bin/busybox ${applet#sbin/}
done
popd

if [[ "${opts[-L]}" ]] || [[ "${opts[-luks]}" ]]; then
	opts[-bin]+=:cryptsetup opts[-mgrp]+=:dm-crypt
fi

if [[ "${opts[-q]}" ]] || [[ "${opts[-squashd]}" ]]; then
	opts[-bin]+=:umount.aufs:mount.aufs opts[-mgrp]+=:squashd
fi

if [[ "${opts[-g]}" ]] || [[ "${opts[-gpg]}" ]]; then
	opts[-mgrp]+=:gpg
	if [[ -x usr/bin/gpg ]]; then :;
	elif [[ "$(gpg --version | sed -nre '/^gpg/s/.* ([0-9]{1})\..*$/\1/p')" -eq 1 ]]; then
		opts[-bin]+=:$(type -p gpg)
	else
		die "there is no usable gpg/gnupg-1.4.x binary"
	fi
fi

if [[ "${opts[-l]}" ]] || [[ "${opts[-lvm]}" ]]; then
	opts[-bin]+=:lvm opts[-mgrp]+=:device-mapper
	pushd sbin
	for lpv in {vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge
		do ln -s lvm ${lpv} || die
	done
	popd
fi

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
function domod {
	local mod module ret
	for mod in "$*"; do
		declare -a modules
		modules=($(find /lib/modules/${opts[-kv]} -name "${mod}.ko" -or -name "${mod}-*.ko"))
		if (( "${#modules[@]}" > 0 )); then
			for module in "${modules[@]}"; do
				mkdir -p .${module%/*} && cp -ar {,.}${module} ||
					die "failed to copy ${module} module"
			done
		else
			warn "${mod} does not exist"
			((ret=${ret}+1))
		fi
	done
	return ${ret}
}

for keymap in ${opts[-y]//:/ } ${opts[-keymap]//:/ }; do
	if [[ -f usr/share/keymaps/"${keymap}" ]]; then :;
	elif [[ -f "${keymap}" ]]; then
		cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} >usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	fi
done

for font in ${opts[-f]//:/ } ${opts[-font]//:/ }; do
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

if [[ "${opts[-s]}" ]] || [[ "${opts[-splash]}" ]]; then
	opts[-bin]+=:splash_util.static:fbcondecor_helper
	
	[[ "${opts[-toi]}" ]] &&
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
function docp {
	local link=${1} prefix
	[[ -n ${link} ]] || return
	rm -f .${link} && cp -a {,.}${link} || die

	[[ -h ${link} ]] &&
	while true; do
	    prefix=${link%/*}
		link=$(readlink ${link})
		[[ ${link%/*} == ${link} ]] && link=${prefix}/${link}
		rm -f .${link} && cp -a {,.}${link} || die
		[[ -h ${link} ]] || break
	done

	return 0
}

# @FUNCTION: dobin
# @DESCRIPTION: copy binary with libraries if not static
function dobin {
	local bin=$1 lib
	docp ${bin} || return

	ldd ${bin} >/dev/null || return 0

	for lib in $(ldd ${bin} | sed -nre 's,.* (/.*lib.*/.*.so.*) .*,\1,p' \
	    -e 's,.*(/lib.*/ld.*.so.*) .*,\1,p'); do
		mkdir -p .${lib%/*} && docp ${lib} || die
	done
}

for bin in ${opts[-b]//:/ } ${opts[-bin]//:/ }; do
	for b in {usr/,}{,s}bin/${bin}; do
		[[ -x ${b} ]] && continue 2
	done

	[[ -x ${bin} ]] && dobin ${bin}
	binary=$(type -p ${bin})
	[[ "${binary}" ]] && dobin ${binary} || warn "no ${bin} binary found"
	binary=
done
unset binary

domod "${opts[-m]//:/ }" "${opts[-kmod]//:/ }"

for grp in ${opts[-mgrp]//:/ }; do
	if [[ -n "${opts[-m${grp}]}" ]]; then
		for mod in ${opts[-m${grp}]//:/ }; do 
			domod ${mod} && echo ${mod} >>etc/${PKG[name]}/${grp}
		done
	fi
done

for lib in $(find usr/lib/gcc -iname 'lib*'); do
	ln -fs /$lib     lib/${lib##*/}
	ln -fs /$lib usr/lib/${lib##*/}
done

docpio || die

[[ "${opts[-K]}" ]] || [[ "${opts[-keep-tmpdir]}" ]] || rm -rf ${opts[-dir]}

echo ">>> ${opts[-initramfs]} initramfs built"

unset -v comp opt opts PKG

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
