#!/bin/zsh
#
# $Header: mkinitramfs-ll/mkinitramfs-ll.zsh             Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.16.0 2015/01/01 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name mkinitramfs-ll
	shell zsh
	version 0.16.0
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
function usage {
  cat <<-EOF
  ${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [-a|-all] [options]

  -a, --all                   Short variant of '-l -L -g -H:zfs:zram -t -q'
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
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error {
	print -P " %B%F{red}*%b %1x: %F{yellow}%U%I%u%f: $@" >&2
}
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
function info {
	print -P " %B%F{green}*%b%f %1x: $@"
}
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
function warn {
	print -P " %B%F{red}*%b%f %1x: $@" >&2
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error $@
	exit $ret
}

# @FUNCTION: mktmp
# @DESCRIPTION: make tmp dir or file in ${TMPDIR:-/tmp}
# @ARG: TEMPLATE
function mktmp {
	local tmp=${TMPDIR:-/tmp}/$1-XXXXXX
	mkdir -p $tmp || die "mktmp: failed to make $tmp"
	print "$tmp"
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

	for (( i=0; i<8; i++ )) {
		[[ -c tty${i} ]] || mknod -m 600 tty${i} c 4 ${i} || die
	}
	popd || die
}

setopt EXTENDED_GLOB NULL_GLOB
unsetopt KSH_ARRAYS

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
typeset -A opts

typeset -a opt
opt=(
	"-o" "ab:c::f::F::gk::lH:KLm::p::qrs::thu::y::?"
	"-l" "all,bin:,compressor::,firmware::,font::,gpg,help"
	"-l" "hook:,luks,lvm,keep-tmpdir,kmod::,keymap::,kv::"
	"-l" "mboot::,mgpg::,mremdev::,msquashd::,mtuxonice::"
	"-l" "prefix::,rebuild,splash::,squashd,toi,usrdir::"
	"-n" ${PKG[name]}.${PKG[shell]}
)
opt=($(getopt ${opt} -- ${argv} || usage))
eval set -- ${opt}

for (( ; $# > 0; ))
	case $1 {
		(-[KLaglqrt]|--[aglrt]*|--sq*|--keep*)
			opts[${1/--/-}]=
			shift;;
		(-[cdkp]|--[cpu]*|--kv)
			opts[${1/--/-}]=$2
			shift 2;;
		(-[FHbfmsy]|--[bfks]*|--ho*)
			opts[${1/--/-}]+=:$2
			shift 2;;
		(--)
			shift
			break;;
		(-?|-h|--help|*)
			usage;;
	}

if (( ${+opts[-a]} )) || (( ${+opts[-all]} )) {
	opts[-font]+=: opts[-gpg]= opts[-lvm]= opts[-squashd]=
	opts[-toi]= opts[-luks]= opts[-keymap]+=:
	opts[-hook]+=:zfs:zram
}

if (( ${+opts[-y]} )) || (( ${+opts[-keymap]} )) &&
	[[ ${opts[-keymap]:-$opts[-y]} == ":" ]] {
	if [[ -e /etc/conf.d/keymaps ]] {
		opts[-keymap]+=$(sed -nre 's,^keymap="([a-zA-Z].*)",\1,p' \
			/etc/conf.d/keymaps)
	} else {
		warn "no console keymap found"
	}
}

if (( ${+opts[-f]} )) || (( ${+opts[-font]} )) &&
	[[ ${opts[-font]:-$opts[-f]} == ":" ]] {
	if [[ -e /etc/conf.d/consolefont ]] {
		opts[-font]+=$(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' \
			/etc/conf.d/consolefont)
	} else {
		warn "no console font found"
	}
}

if [[ -f "${PKG[name]}".conf ]] {
	source "${PKG[name]}".conf 
} else {
	die "no ${PKG[name]}.conf found"
}

# @VARIABLE: opts[-kv]
# @DESCRIPTION: kernel version to pick up
:	${opts[-kv]:=${opts[-k]:-$(uname -r)}}
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix-$kv.$ext>
:	${opts[-prefix]:=${opts[-p]:-initramfs-}}
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
:	${opts[-usrdir]:=${opts[-u]:-"${PWD}"/usr}}
# @VARIABLE: opts[-compressor]
# @DESCRIPTION: compression command
:	${opts[-compressor]:=${opts[-c]:-xz -9 --check=crc32}}
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
:	${opts[-initramfs]:=${opts[-prefix]}${opts[-kv]}}
# @VARIABLE: opts[-arch]
# @DESCRIPTION: kernel architecture
:	${opts[-arch]:=$(uname -m)}
# @VARIABLE: opts[-arc]
# @DESCRIPTION: kernel bit lenght supported
:	${opts[-arc]:=$(getconf LONG_BIT)}
# @VARIABLE: opts[-tmpdir]
# @DESCRIPTION: tmp dir where to generate initramfs
# an initramfs compressed image
:	${opts[-tmpdir]:=$(mktmp ${opts[-initramfs]:t})}
# @VARIABLE: opts[-confdir]
# @DESCRIPTION: configuration directory
:	${opts[-confdir]=etc/${PKG[name]}}

typeset -a compressor
compressor=(bzip2 gzip lzip lzop lz4 xz)

if (( ${+opts[-compressor]} )) && [[ ${opts[-compressor]} != "none" ]] {
	if [[ -e /usr/src/linux-${opts[-kv]}/.config ]] {
		config=/usr/src/linux-${opts[-kv]}/.config
		xgrep=${commands[grep]}
	} elif [[ -e /proc/config.gz ]] {
		config=/proc/config.gz
		xgrep=${commands[zgrep]}
	} else { warn "no kernel config file found" }
}

if (( ${+config} )) {
	CONFIG=CONFIG_RD_${${opts[-compressor][(w)1]}:u}
	if ! ${=xgrep} -q "^${CONFIG}=y" ${config}; then
		warn "${opts[-compressor][(w)1]} decompression is not supported by kernel-${opts[-kv]}"
		for comp (${compressor[@]}) {
			CONFIG=CONFIG_RD_${comp:u}
			if ${=xgrep} -q "^${CONFIG}=y" ${config}; then
				opts[-compressor]="${comp} -9"
				info "setting compressor to ${comp}"
				break
			elif [[ ${comp} == "xz" ]]; then
				die "no suitable compressor support found in kernel-${opts[-kv]}"
			fi
		}
	fi
	unset config xgrep CONFIG comp compressor
}

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
function docpio {
	local ext=.cpio initramfs=${1:-/boot/${opts[-initramfs]}}
	local cmd="find . -print0 | cpio -0 -ov -Hnewc"

	case ${opts[-compressor][(w)1]} {
		(bzip2) ext+=.bz2;;
		(gzip)  ext+=.gz;;
		(xz)    ext+=.xz;;
		(lzma)  ext+=.lzma;;
		(lzip)  ext+=.lz;;
		(lzop)  ext+=.lzo;;
		(lz4)   ext+=.lz4;;
		(*) opts[-compressor]=; warn "initramfs will not be compressed";;
	}

	if [[ -f ${initramfs}${ext} ]] {
	    mv ${initramfs}${ext}{,.old}
	}
	if [[ -n ${ext#.cpio} ]] {
		cmd+=" | ${=opts[-compressor]} -c"
	}
	eval ${=cmd} > ${initramfs}${ext} ||
	die "Failed to build ${initramfs}${ext} initramfs"
}

print -P "%F{green}>>> building ${opts[-initramfs]}...%f"
pushd ${opts[-tmpdir]} || die "no ${opts[-tmpdir]} tmpdir found"

if (( ${+opts[-r]} )) || (( ${+opts[-rebuild]} )) {
	cp -af {${opts[-usrdir]}/,}lib/${PKG[name]}/functions &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio || die
	print -P "%F{green}>>> regenerated ${opts[-initramfs]}...%f" && exit
} else {
	rm -fr *
}

if [[ -d ${opts[-usrdir]} ]] {
	cp -ar ${opts[-usrdir]} . &&
	mv -f {usr/,}root &&
	mv -f {usr/,}etc &&
	mv -f usr/lib lib${opts[-arc]} || die
} else {
	die "${opts[-usrdir]} dir not found"
}

mkdir -p usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} || die
mkdir -p {,s}bin dev proc sys newroot mnt/tok etc/{${PKG[name]},splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kv]},${PKG[name]}} || die
for dir ({,usr/}lib) ln -s lib${opts[-arc]} ${dir}

{
	for key (${(k)PKG[@]}) print "${key}=${PKG[$key]}"
	print "build=$(date +%Y-%m-%d-%H-%M-%S)"
} >${opts[-confdir]}/id
touch etc/{fs,m}tab

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || donod
if [[ ${${(pws:.:)opts[-kv]}[1]} -eq 3 ]] &&
	[[ ${${(pws:.:)opts[-kv]}[2]} -ge 1 ]] {
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
}

cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
[[ -d root ]] && chmod 0700 root || mkdir -m700 root || die

for bin (dmraid mdadm zfs)
	for opt (${opts[-b]} ${opts[-bin]})
		if [[ ${opt/$bin} != $opt ]] { opts[-mgrp]+=:$bin }
opts[-mgrp]=${opts[-mgrp]/mdadm/raid}

for hook (${(pws,:,)opts[-H]} ${(pws,:,)opts[-hook]}) {
	for file (${opts[-usrdir]:h}/hooks/*${hook}*) {
		cp -a ${file} lib/${PKG[name]}
	}
	(( $? != 0 )) && warn "$mod module does not exist"

	opts[-bin]+=:${opts[-b$hook]}
	opts[-mgrp]+=:$hook
}

cp -ar {/,}lib/modules/${opts[-kv]}/modules.dep ||
	die "failed to copy modules.dep"

[[ -f /etc/issue.logo ]] && cp {/,}etc/issue.logo

if (( ${+opts[-F]} || ${+opts[-firmware]} )) {
	if [[ ${opts[-F]} == : ]] || [[ ${opts[-firmware]} == : ]]; then
		warn "Adding the whole firmware directory"
		cp -a {/,}lib/firmware
	fi
	mkdir -p lib/firmware
	for f (${(pws,:,)opts[-F]} ${(pws,:,)opts[-firmware]}) {
		[[ -e ${f} ]] && firmware+=(${f}) ||
			firmware+=(/lib/firmware/*${f}*(N))
		mkdir -p .${firmware[${#firmware}]:h}
	}
	cp -a ${firmware} lib/firmware/
	unset firmware
}

if [[ -x usr/bin/busybox ]] {
	mv -f {usr/,}bin/busybox
} elif (( ${+commands[busybox]} )) {
	if (ldd ${commands[busybox]} >/dev/null) {
		busybox --list-full >${opts[-confdir]}/busybox.applets
		opts[-bin]+=:${commands[busybox]}
		warn "busybox is not a static binary"
	}
	cp -a ${commands[busybox]} bin/
} else { die "no busybox binary found" }

if [[ ! -f ${opts[-confdir]}/busybox.applets ]] {
	bin/busybox --list-full >${opts[-confdir]}/busybox.applets || die
}

for bin ($(grep  '^bin' ${opts[-confdir]}/busybox.applets))
	ln -s busybox ${bin}
for bin ($(grep '^sbin' ${opts[-confdir]}/busybox.applets))
	ln -s ../bin/busybox ${bin}

if (( ${+opts[-L]} )) || (( ${+opts[-luks]} )) {
	opts[-bin]+=:cryptsetup opts[-mgrp]+=:dm-crypt
}

if (( ${+opts[-g]} )) || (( ${+opts[-gpg]} )) {
	opts[-mgrp]+=:gpg
	if [[ -x usr/bin/gpg ]] { :;
	} elif [[ $(gpg --version | sed -nre '/^gpg/s/.* ([0-9]{1})\..*$/\1/p') -eq 1 ]] {
		opts[-bin]+=:${commands[gpg]}
	} else { die "there's no usable gpg/gnupg-1.4.x" }
}

if (( ${+opts[-l]} )) || (( ${+opts[-lvm]} )) {
	opts[-bin]+=:lvm opts[-mgrp]+=:device-mapper
}

if (( ${+opts[-q]} )) || (( ${+opts[-squashd]} )) {
	opts[-bin]+=:mount.aufs:umount.aufs opts[-mgrp]+=:squashd
}

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
function domod {
	case $1 in
		(-v|--verbose)
			local verbose=$2
			shift 2;;
	esac

	local mod ret prefix=/lib/modules/${opts[-kv]}/
	local -a modules

	for mod (${argv}) {
		modules=($(grep -E "${mod}(|[_-]*)" .${prefix}modules.dep))

		if (( ${#modules} > 0 )) {
			for (( i=1; i <= ${#modules}; i++ )) {
				if [[ ${modules[i]%:} != ${modules[i]} ]] {
					modules[$i]="${modules[i]%:}"
					if (( ${+verbose} )) {
						print ${${modules[i]:t}/.ko} >> ${verbose} || die
					}
				}
				mkdir -p .${prefix}${modules[i]:h} && cp -ar {,.}${prefix}${modules[i]} ||
					die "failed to copy ${modules[i]} module"
			}
		} else {
			warn "${mod} does not exist"
			((ret=${ret}+1))
		}
	}
	return ${ret}
}

typeset -a KEYMAP
for keymap (${(pws,:,)opts[-y]} ${(pws,:,)opts[-keymap]}) {
	if [[ -f usr/share/keymaps/${keymap}-${opts[-arch]}.bin ]] {
		:;
	} elif [[ -f ${keymap} ]] {
		cp -a ${keymap} usr/share/keymaps/
	} else {
		loadkeys -b -u ${keymap} > usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	}
	(( $? == 0 )) && KEYMAP+=(${keymap}-${opts[-arch]}.bin)
}
print ${KEYMAP[1]} >${opts[-confdir]}/kmap
unset KEYMAP keymap

typeset -a FONT
for font (${(pws,:,)opts[-f]} ${(pws,:,)opts[-font]}) {
	if [[ -f usr/share/consolefonts/${font} ]] {
		:;
	} elif [[ -f ${font} ]] {
		cp -a ${font} usr/share/consolefonts/
	} else {
		for file (/usr/share/consolefonts/${font}*.gz) {
			cp ${file} . 
			gzip -d ${file:t}
		}
		mv ${font}* usr/share/consolefonts/
	}
	(( $? == 0 )) && FONT+=(${font})
}
print ${FONT[1]} >${opts[-confdir]}/font
unset FONT font

if (( ${+$opts[-s]} )) || (( ${+opts[-splash]} )) {
	opts[-bin]+=:splash_util.static:fbcondecor_helper
	
	if (( ${+opts[-toi]} || ${+opts[-t]} )) {
		opts[-bin]+=:tuxoniceui_text
	}
	
	for theme (${(pws,:,)opts[-splash]})
		if [[ -d etc/splash/${theme} ]] {
			:;
		} elif [[ -d /etc/splash/${theme} ]] {
			cp -ar {/,}etc/splash/${theme}
		} elif [[ -d ${theme} ]] {
			cp -r ${theme} etc/splash/
		} else { warn "splash themes does not exist" }
}

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
		rm -f .${link} && cp -f {,.}${link} || die
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

	for lib ($(ldd ${bin} | sed -nre 's,.* (/.*lib.*/.*.so.*) .*,\1,p' \
	    -e 's,.*(/lib.*/ld.*.so.*) .*,\1,p'))
		mkdir -p .${lib%/*} && docp ${lib} || die
}

for bin (${(pws,:,)opts[-b]} ${(pws,:,)opts[-bin]}) {
	for b ({usr/,}{,s}bin/${bin}) { [[ -x ${b} ]] && continue 2 }
	[[ -x ${bin} ]] && binary=${bin} || binary=${commands[$bin]}
	[[ -n ${binary} ]] && dobin ${binary} || warn "no ${bin} binary found"
}
unset -v binary bin b

# Remove module group name from boot group before processing module groups
for mod (${(pws,:,)opts[-mboot]})
	if (( ${+opts[-m$mod]} )) {
		print ${mod} >>${opts[-confdir]}/boot
	} else { mboot+=:${mod} }
opts[-mboot]=${mboot}
unset mboot mod

for module (${(pws,:,)opts[-m]}${(pws,:,)opts[-kmod]}) domod ${module}
for grp (${(pws,:,)opts[-mgrp]})
	domod -v ${opts[-confdir]}/${grp} ${(pws,:,)opts[-m${grp}]}

# Set up user environment if present
for (( i=1; i <= ${#env[@]}; i++ ))
	print ${env[i]} >>${opts[-confdir]}/env
unset env

for lib (usr/lib/gcc/**/lib*.so*(.N)) {
	ln -fs $lib     lib/$lib:t
	ln -fs $lib usr/lib/$lib:t
}

docpio || die

print -P "%F{green}>>> ${opts[-initramfs]} initramfs built%f"

(( ${+opts[-K]} )) || (( ${+opts[-keeptmp]} )) || rm -rf ${opts[-tmpdir]}

unset comp opts PKG

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
