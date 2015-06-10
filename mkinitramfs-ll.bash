#!/bin/bash
#
# $Header: mkinitramfs-ll/mkinitramfs-ll.bash            Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.21.0 2015/05/28 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	[name]=mkinitramfs-ll
	[shell]=bash
	[version]=0.21.0
)

# @FUNCTION: Print help message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [-a|-all] [options]

  -a, --all                   Short variant of '-lLgtq -H:btrfs:zfs:zram'
  -f, --font=REGEX            Fonts to include in the initramfs
  -F, --firmware=REGEX        Firmware file/directory to include
  -k, --kernel-version=KV     Build an initramfs for kernel version VERSION
  -c, --compressor='gzip -9'  Use 'gzip -9' compressor instead of default
  -L, --luks                  Enable LUKS support (require cryptsetup binary)
  -l, --lvm                   Enable LVM2 support (require lvm2 binary)
  -b, --bin=BINS              Binar-y-ies to include if available
  -d, --usrdir=DIRECTORY      Use DIRECTORY as USRDIR instead of the default
  -g, --gpg                   Enable GnuPG support (require gnupg-1.4.x)
  -p, --prefix=initrd-        Use 'initrd-' prefix instead of default ['initramfs-']
  -H, --hook=REGEX            Include hook or script if available
  -m, --module=REGEX          Include kernel modules if available
      --module-tuxonice=REGEX Append kernel modules to tuxonice group
      --module-remdev=REGEX   Append kernel modules to remdev   group
      --module-squashd=REGEX  Append kernel modules to squashd  group
      --module-gpg=REGEX      Append kernel modules to gpg      group
      --module-boot=REGEX     Append kernel modules to boot     group
  -s, --splash=THEMES         Include splash themes  if available
  -t, --toi                   Enable TuxOnIce support (require tuxoniceui-userui)
  -q, --squashd               Enable UnionFS+SquashFS support (AUFS/OverlayFS)
  -r, --rebuild               Re-Build an initramfs from an old directory
  -y, --keymap=:fr-latin1     Keymaps to include the initramfs
  -K, --keep-tmpdir           Keep the temporary build directory
  -h, --help, -?              Print this help or usage message
EOH
exit $?
}

# @FUNCTION: Print error message to stdout
function error {
	echo -ne " \e[1;31m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCTION: Print info message to stdout
function info {
	echo -ne " \e[1;32m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n"
}
# @FUNCPTION: Print warning message to stdout
function warn {
	echo -ne " \e[1;33m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n" >&2
}
# @FUNCPTION: Fatal error helper
function die {
	local ret=$?
	error "$@"
	exit $ret
}

# @FUNCTION: Temporary dir/file helper
# @ARG: -d|-f [-m <mode>] [-o <owner[:group]>] [-g <group>] TEMPLATE
function mktmp {
	local tmp=${TMPDIR:-/tmp}/$1-XXXXXX
	mkdir -p $tmp || die "mktmp: failed to make $tmp"
	echo "$tmp"
}

# @FUNCTION: File copy helper (handle symlinks)
# @ARG: <file>
function docp {
	local link=${1} prefix
	[[ -n ${1} && -e ${1} ]] || return
	mkdir -p .${1%/*}
	rm -f .${1} && cp -a {,.}${1} || die

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

# @FUNCTION: Device nodes (helper)
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
	"-o" "ab:c:f:F:gk:lH:KLm:p:qrs:thu:y:?"
	"-l" "all,bin:,compressor:,firmware:,font:,gpg,help"
	"-l" "hook:,luks,lvm,keep-tmpdir,module:,keymap:,kernel-version:"
	"-l" "module-boot:,module-gpg:,module-remdev:,module-squashd:,module-tuxonice:"
	"-l" "prefix:,rebuild,splash:,squashd,toi,usrdir:"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

# @VARIABLE: Associative Array holding (almost) every options
declare -A opts

while true; do
	case "$1" in
		(-[KLaglqrt]|--[aglrt]*|--sq*|--keep*)
			opts[${1/--/-}]=true
			shift;;
		(-[cdkp]|--[cpu]*|--kernel-*)
			opts[${1/--/-}]="$2"
			shift 2;;
		(-[FHbfmsy]|--[bfks]*|--hook|--module*)
			opts[${1/--/-}]+=":$2"
			shift 2;;
		(--)
			shift
			break;;
		(-?|-h|--help|*)
			usage;;
	esac
done

if [[ "${opts[-a]}" || "${opts[-all]}" ]]; then
	opts[-font]+=: opts[-gpg]=true opts[-lvm]=true opts[-squashd]=true
	opts[-toi]=true opts[-luks]=true opts[-keymap]+=:
	opts[-hook]+=:btrfs:zfs:zram
fi

for key in f{,ont}; do
if [[ "${opts[-$key]}" && "${opts[-$key]}" == ":" ]]; then
	if [[ -e /etc/conf.d/consolefont ]]; then
		opts[-font]+=$(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' \
			/etc/conf.d/consolefont)
	else
		warn "no console font found"
	fi
fi
done

for key in y keymap; do
if [[ "${opts[-$key]}" && "${opts[-$key]}" == ":" ]]; then
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

# @VARIABLE: Kernel version
:	${opts[-k]:=${opts[-kernel-version]:-${opts[-k]=$(uname -r)}}}
# @VARIABLE: Initramfs prefx
:	${opts[-prefix]:=${opts[-p]:-initramfs-}}
# @VARIABLE: USRDIR path to use
:	${opts[-usrdir]:=${opts[-d]:-"${PWD}"/usr}}
# @VARIABLE: Full path to initramfs image
opts[-initramfs]="${opts[-prefix]}${opts[-k]}"
:	${opts[-compressor]:=${opts[-c]:-xz -9 --check=crc32}}
# @VARIABLE: Kernel architecture
opts[-arch]="$(uname -m)"
# @VARIABLE: Kernel bit lenght
opts[-arc]="$(getconf LONG_BIT)"
# @VARIABLE: (initramfs) Tmporary directory
opts[-tmpdir]="$(mktmp ${opts[-initramfs]})"
# @DESCRIPTION: (initramfs) Configuration directory
opts[-confdir]="etc/${PKG[name]}"

# Set up compression
declare -a compressor
compressor=(bzip2 gzip lzip lzop lz4 xz)

case "${opts[-compressor]}" in
	(none) ;;
	([a-z]*)
	if [[ -e /usr/src/linux-${opts[-k]}/.config ]]; then
		config=/usr/src/linux-${opts[-k]}/.config
		xgrep=$(type -p grep)
	elif [[ -e /proc/config.gz ]]; then
		config=/proc/config.gz
		xgrep=$(type -p zgrep)
	else
		warn "no kernel config file found"
	fi
	;;
esac
if [[ "${config}" ]]; then
	COMP="${opts[-compressor]%% *}"
	CONFIG=CONFIG_RD_${COMP^^[a-z]}
	if ! ${xgrep} -q "^${CONFIG}=y" ${config}; then
		warn "${opts[-compressor]%% *} decompression is not supported by kernel-${opts[-k]}"
		for (( i=0; i<${#compressor[@]}; i++ )); do
			COMP=${compressor[$i]}
			CONFIG=CONFIG_RD_${COMP^^[a-z]}
			if ${xgrep} -q "^${CONFIG}=y" ${config}; then
				opts[-compressor]="${compressor[$i]} -9"
				info "setting compressor to ${COMP}"
				break
			elif (( $i == (${#compressor[@]}-1) )); then
				die "no suitable decompressor support found in kernel-${opts[-k]}"
			fi
		done
	fi
	unset config xgrep CONFIG COMP compressor
fi

# @FUNCTION: CPIO image builder
# @ARG: <out-file>
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

if [[ "${opts[-r]}" || "${opts[-rebuild]}" ]]; then
	cp -af {${opts[-usrdir]}/,}lib/${PKG[name]}/functions &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio || die
	echo ">>> regenerated ${opts[-initramfs]}..." && exit
else
	rm -fr *
fi

# Set up the initramfs
if [[ -d "${opts[-usrdir]}" ]]; then
	cp -ar "${opts[-usrdir]}" . &&
	mv -f usr/{root,etc} . &&
	mv -f usr/lib lib${opts[-arc]} || die
else 
	die "${opts[-usrdir]} dir not found"
fi
mkdir -p usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} \
	{,s}bin dev proc sys newroot mnt/tok etc/{${PKG[name]},splash} \
	run lib${opts[-arc]}/{modules/${opts[-k]},${PKG[name]}} || die
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
KV=(${opts[-k]//./ })
if [[ "${KV[0]}" -eq 3 && "${KV[1]}" -ge 1 ]]; then
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
fi
unset KV

cp -a "${opts[-usrdir]}"/../init . && chmod 775 init || die
[[ -d root ]] && chmod 0700 root || mkdir -m700 root || die
cp -af {/,}lib/modules/${opts[-k]}/modules.dep ||
	die "failed to copy modules.dep"

# Set up (requested) firmware
if [[ "${opts[-F]}" || "${opts[-firmware]}" ]]; then
	if [[ "${opts[-F]}" == : ]] || [[ "${opts[-firmware]}" == : ]]; then
		warn "Adding the whole firmware directory"
		cp -a {/,}lib/firmware
	fi
	mkdir -p lib/firmware
	for fw in ${opts[-F]//:/ } ${opts[-firmware]//:/ }; do
		[[ -e ${fw} ]] && cp -a ${fw} lib/firmware ||
		for fw in /lib/firmware/*${fw}*; do
			docp ${fw}
		done
	done
fi

# Set up RAID option
for bin in dmraid mdadm zfs; do
	[[ "${opts[-bin]/$bin}" != "${opts[bin]}" ]] ||
		[[ "${opts[-b]/$bin}" != "${opts[-b]}" ]] && opts[-module-group]+=":$bin"
done
opts[-module-group]=${opts[-module-group]/mdadm/raid}

# Set up (requested) hook
for hook in ${opts[-H]//:/ } ${opts[-hook]//:/ }; do
	for file in ${opts[-usrdir]}/../hooks/*${hook}*; do
		cp -a "${file}" lib/${PKG[name]}/
	done
	if (( $? != 0 )); then
		warn "$hook hook/script does not exist"
		continue
	fi
	opts[-bin]+=:${opts[-bin-$hook]}
	opts[-module-group]+=:$hook
done

[[ -f /etc/issue.logo ]] && cp {/,}etc/issue.logo

# Handle & copy BusyBox binary
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
for bin in $(< ${opts[-usrdir]}/../scripts/minimal.applets); do
	grep -q ${bin} ${opts[-confdir]}/busybox.applets ||
	die "${bin} applet not found, no suitable busybox found"
done
for bin in $(grep  '^bin' ${opts[-confdir]}/busybox.applets); do
	ln -s busybox ${bin}
done
for bin in $(grep '^sbin' ${opts[-confdir]}/busybox.applets); do
	ln -s ../bin/busybox ${bin}
done

# Set up a few options
if [[ "${opts[-L]}" || "${opts[-luks]}" ]]; then
	opts[-bin]+=:cryptsetup opts[-module-group]+=:dm-crypt
fi
if [[ "${opts[-q]}" || "${opts[-squashd]}" ]]; then
	opts[-bin]+=:umount.aufs:mount.aufs opts[-module-group]+=:squashd
fi
if [[ "${opts[-g]}" || "${opts[-gpg]}" ]]; then
	if [[ -x usr/bin/gpg ]]; then :;
	elif [[ "$(gpg --version | sed -nre '/^gpg/s/.* ([0-9]{1})\..*$/\1/p')" -eq 1 ]]; then
		opts[-bin]+=:$(type -p gpg)
	else
		die "there is no usable gpg/gnupg-1.4.x binary"
	fi
fi
if [[ "${opts[-l]}" || "${opts[-lvm]}" ]]; then
	opts[-bin]+=:lvm opts[-module-group]+=:device-mapper
fi

# @FUNCTION: Kernel module copy helper
# @ARG: [-v|--verbose] <module>
function domod {
	case $1 in
		(-v|--verbose)
			local verbose=$2
			shift 2;;
	esac
	local mod ret name prefix=/lib/modules/${opts[-k]}/
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

# Handle & copy keymap/consolefont
declare -a FONT KEYMAP
for keymap in ${opts[-y]//:/ } ${opts[-keymap]//:/ }; do
	if [[ -f usr/share/keymaps/${keymap}-${opts[-arch]}.bin ]]; then
		:;
	elif [[ -f "${keymap}" ]]; then
		cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} >usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	fi
	(( $? == 0 )) && KEYMAP+=(${keymap}-${opts[-arch]}.bin)
done
echo "${KEYMAP[0]}" >${opts[-confdir]}/kmap

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
unset FONT font KEYMAP keymap

# Handle & copy splash themes
if [[ "${opts[-s]}" || "${opts[-splash]}" ]]; then
	opts[-bin]+=:splash_util.static:fbcondecor_helper

	if [[ "${opts[-t]}" ]] || [[ "${opts[-toi]}" ]]; then
		opts[-bin]+=:tuxoniceui_text && opts[-kmodule]+=:tuxonice
	fi
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

# @FUNCTION: (static/dynamic) Binary copy helper
# @ARG: <bin>
function dobin {
	local bin=$1 lib
	docp ${bin} || return
	ldd ${bin} >/dev/null || return 0

	for lib in $(ldd ${bin} | sed -nre 's,.* (/.*lib.*/.*.so.*) .*,\1,p' \
	    -e 's,.*(/lib.*/ld.*.so.*) .*,\1,p'); do
		mkdir -p .${lib%/*} && docp ${lib} || die
	done
}

# Handle & copy binaries
for bin in ${opts[-b]//:/ } ${opts[-bin]//:/ }; do
	for b in {usr/,}{,s}bin/${bin}; do
		[ -x ${b} -a ! -h ${b} ] && continue 2
	done
	[[ -x ${bin} ]] && binary=${bin} || binary=$(type -p ${bin})
	[[ "${binary}" ]] && dobin ${binary} || warn "no ${bin} binary found"
done
unset binary bin b

# Handle & copy kernel module
domod ${opts[-m]//:/ } ${opts[-module]//:/ }

for mod in ${opts[-module-boot]//:/ }; do
	if [[ "${opts[-module-$mod]}" ]]; then
		echo "${mod}" >> ${opts[-confdir]}/boot
	else
		mboot+=":${mod}"
	fi
done
opts[-module-boot]="${mboot}"
unset mboot mod

for group in ${opts[-module-group]//:/ }; do
	domod -v ${opts[-confdir]}/${group} ${opts[-module-${group}]//:/ }
done

# Set up user environment if present
for (( i=0; i < ${#env[@]}; i++ )); do
	echo "${env[i]}" >> ${opts[-confdir]}/env
done
unset env

# Handle GCC libraries symlinks
[[ -d usr/lib/gcc ]] &&
for lib in $(find usr/lib/gcc -iname 'lib*'); do
	ln -fns /$lib     lib/${lib##*/}
	ln -fns /$lib usr/lib/${lib##*/}
done

docpio || die
[[ "${opts[-K]}" || "${opts[-keep-tmpdir]}" ]] || rm -rf ${opts[-tmpdir]}
echo ">>> ${opts[-initramfs]} initramfs built"
unset -v comp opt opts PKG

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
