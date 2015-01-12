#!/bin/bash
#
# $Header: mkinitramfs-ll/mkinitramfs-ll.bash            Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.16.2 2015/01/10 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	[name]=mkinitramfs-ll
	[shell]=bash
	[version]=0.16.0
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [-a|-all] [options]

  -a, --all                   Short variant of '-l -L -g -H:btrfs:zfs:zram -t -q'
  -f, --font=[:ter-v14n]      Fonts to include in the initramfs
  -F, --firmware=[:file]      Firmware file/directory to include
  -k, --kv=VERSION            Build an initramfs for kernel version VERSION
  -c, --compressor='gzip -9'  Use 'gzip -9' compressor instead of default
  -L, --luks                  Enable LUKS support (require cryptsetup binary)
  -l, --lvm                   Enable LVM2 support (require lvm2 binary)
  -b, --bin=:<bin>            Binar-y-ies to include if available
  -d, --usrdir=[DIRECTORY]    Use DIRECTORY as USRDIR instead of the default
  -g, --gpg                   Enable GnuPG support (require gnupg-1.4.x)
  -p, --prefix=initrd-        Use 'initrd-' prefix instead of default ['initramfs-']
  -H, --hook=:<name>          Include hook or script if available
  -m, --kmod=[:<mod>]         Include kernel modules if available
      --mtuxonice=[:<mod>]    Append kernel modules to tuxonice group
      --mremdev=[:<mod>]      Append kernel modules to remdev   group
      --msquashd=[:<mod>]     Append kernel modules to squashd  group
      --mgpg=[:<mod>]         Append kernel modules to gpg      group
      --mboot=[:<mod>]        Append kernel modules to boot     group
  -s, --splash=[:<theme>]     Include splash themes  if available
  -t, --toi                   Enable TuxOnIce support (require tuxoniceui-userui)
  -q, --squashd               Enable AUFS+SquashFS support (require aufs-util)
  -r, --rebuild               Re-Build an initramfs from an old directory
  -y, --keymap=:fr-latin1     Keymaps to include the initramfs
  -K, --keep-tmpdir           Keep the temporary build directory
  -h, --help, -?              Print this help or usage message

  :argument|:option           Support a colon separated list of Argument|Option 
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
	"-o" "ab:c::f::F::gk::lH:KLm::p::qrs::thu::y::?"
	"-l" "all,bin:,compressor::,firmware::,font::,gpg,help"
	"-l" "hook:,luks,lvm,keep-tmpdir,kmod::,keymap::,kv::"
	"-l" "mboot::,mgpg::,mremdev::,msquashd::,mtuxonice::"
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
		(-[cdkp]|--[cpu]*|--kv)
			opts[${1/--/-}]="$2"
			shift 2;;
		(-[FHbfmsy]|--[bfks]*|--ho*)
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
	opts[-hook]+=:btrfs:zfs:zram
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
# @VARIABLE: opts[-confdir]
# @DESCRIPTION: configuration directory
opts[-confdir]="etc/${PKG[name]}"

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
	local ext=.cpio initramfs=${1:-/boot/${opts[-initramfs]}}
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

	if [[ -f ${initramfs}${ext} ]]; then
	    mv ${initramfs}${ext}{,.old}
	fi
	if [[ -n "${ext#.cpio}" ]]; then
		cmd+=" | ${opts[-compressor]} -c"
	fi

	eval ${cmd} > /${initramfs}${ext} ||
	die "Failed to build ${initramfs}${ext} initramfs"
}

echo ">>> building ${opts[-initramfs]}..."
pushd "${opts[-tmpdir]}" || die "${opts[-tmpdir]} not found"

if [[ "${opts[-r]}" ]] || [[ "${opts[-regen]}" ]]; then
	cp -af {${opts[-usrdir]}/,}lib/${PKG[name]}/functions &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio || die
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
for dir in {,usr/}lib; do
	ln -s lib${opts[-arc]} ${dir}
done

{
	for key in "${!PKG[@]}"; do
		echo "${key}=${PKG[$key]}"
	done
	echo "build=$(date +%Y-%m-%d-%H-%M-%S)"
} >${opts[-confdir]}/id
touch etc/{fs,m}tab

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || donod

KV=(${opts[-kv]//./ })
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
	if [[ "${opts[-F]}" == : ]] || [[ "${opts[-firmware]}" == : ]]; then
		warn "Adding the whole firmware directory"
		cp -a {/,}lib/firmware
	fi
	mkdir -p lib/firmware
	for f in ${opts[-F]//:/ } ${opts[-firmware]//:/ }; do
		[[ -e ${f} ]] && firmware+=(${f}) ||
			firmware+=(/lib/firmware/*${f}*)
		mkdir -p .${firmware[$((${#firmware[@]}-1))]%/*}
	done
	cp -a "${firmware[@]}" lib/firmware/
	unset firmware
fi

for bin in dmraid mdadm zfs; do
	[[ "${opts[-bin]/$bin}" != "${opts[bin]}" ]] ||
		[[ "${opts[-b]/$bin}" != "${opts[-b]}" ]] && opts[-mgrp]+=":$bin"
done
opts[-mgrp]=${opts[-mgrp]/mdadm/raid}

for hook in ${opts[-H]//:/ } ${opts[-hook]//:/ }; do
	for file in ${opts[-usrdir]}/../hooks/*${hook}*; do
		cp -a "${file}" lib/${PKG[name]}/
	done
	(( $? != 0 )) && warn "$mod module does not exist"

	opts[-bin]+=:${opts[-b$hook]}
	opts[-mgrp]+=:$hook
done

[[ -f /etc/issue.logo ]] && cp {/,}etc/issue.logo

if [[ -x usr/bin/busybox ]]; then
	mv -f {usr/,}bin/busybox
elif type -p busybox >/dev/null; then
	bb=$(type -p busybox)
	if ldd ${bb} >/dev/null; then
		busybox --list-full >${opts[-confdir]}/busybox.applets
		opts[-bin]+=:${bb}
		warn "busybox is not a static binary"
	fi
	cp -a ${bb} bin/
	unset bb
else
	die "no busybox binary found"
fi

if [[ ! -f ${opts[-confdir]}/busybox.applets ]]; then
	bin/busybox --list-full >${opts[-confdir]}/busybox.applets || die
fi

while read line; do
	grep -q ${line} ${opts[-confdir]}/busybox.applets ||
	die "${line} applet not found, no suitable busybox found"
done <${opts[-confdir]}/minimal.applets

for bin in $(grep  '^bin' ${opts[-confdir]}/busybox.applets); do
	ln -s busybox ${bin}
done
for bin in $(grep '^sbin' ${opts[-confdir]}/busybox.applets); do
	ln -s ../bin/busybox ${bin}
done

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
fi

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
function domod {
	case $1 in
		(-v|--verbose)
			local verbose=$2
			shift 2;;
	esac

	local mod ret name prefix=/lib/modules/${opts[-kv]}/
	local -a modules

	for mod in "$@"; do
		modules=($(grep -E "${mod}(|[_-]*)" .${prefix}modules.dep))

		if (( "${#modules[@]}" > 0 )); then
			for (( i=0; i < "${#modules[@]}"; i++ )); do
				if [[ "${modules[i]%:}" != "${modules[i]}" ]]; then
					modules[$i]="${modules[i]%:}"
					if [[ "${verbose}" ]]; then
						name="${modules[i]##*/}"
						echo "${name/.ko}" >> ${verbose} || die
					fi
				fi
				mkdir -p .${prefix}${modules[i]%/*} && cp -ar {,.}${prefix}${modules[i]} ||
					die "failed to copy ${modules[i]} module"
			done
		else
			warn "${mod} does not exist"
			((ret=${ret}+1))
		fi
	done
	return ${ret}
}

declare -a KEYMAP
for keymap in ${opts[-y]//:/ } ${opts[-keymap]//:/ }; do
	if [[ -f usr/share/keymaps/${keymap}-${opts[-arch]}.bin ]]; then
		continue
	elif [[ -f "${keymap}" ]]; then
		cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} >usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	fi
	(( $? == 0 )) && KEYMAP+=(${keymap}-${opts[-arch]}.bin)
done
echo "${KEYMAP[0]}" >${opts[-confdir]}/kmap
unset KEYMAP keymap

declare -a FONT
for font in ${opts[-f]//:/ } ${opts[-font]//:/ }; do
	if [[ -f usr/share/consolefonts/${font} ]]; then :;
	elif [[ -f ${font} ]]; then
		cp -a ${font} usr/share/consolefonts/ 
	else 
		for file in /usr/share/consolefonts/${font}*.gz; do
			if [[ -f ${file} ]]; then
				cp ${file} . 
				gzip -d ${file##*/}
			fi
		done
		mv ${font}* usr/share/consolefonts/
	fi
	(( $? == 0 )) && FONT+=(${font})
done
echo "${FONT[0]}" >${opts[-confdir]}/font
unset FONT font

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
	[[ -x ${bin} ]] && binary=${bin} || binary=$(type -p ${bin})
	[[ "${binary}" ]] && dobin ${binary} || warn "no ${bin} binary found"
done
unset binary bin b

domod ${opts[-m]//:/ } ${opts[-kmod]//:/ }

# Remove module group name from boot group before processing module groups
for mod in ${opts[-mboot]//:/ }; do
	if [[ "${opts[-m$mod]}" ]]; then
		echo "${mod}" >> ${opts[-confdir]}/boot
	else
		mboot+=":${mod}"
	fi
done
opts[-mboot]="${mboot}"
unset mboot mod

for grp in ${opts[-mgrp]//:/ }; do
	domod -v ${opts[-confdir]}/${grp} ${opts[-m${grp}]//:/ }
done

# Set up user environment if present
for (( i=0; i < ${#env[@]}; i++ )); do
	echo "${env[i]}" >> ${opts[-confdir]}/env
done
unset env

[[ -d usr/lib/gcc ]] &&
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
