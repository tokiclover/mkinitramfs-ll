#!/bin/sh
#
# $Header: mkinitramfs-ll/mkinitramfs-ll.sh              Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.20.1 2015/05/28 12:33:03                   Exp $
#

name=mkinitramfs
pkg=${name}-ll
shell=sh
version=0.21.0
null=/dev/null

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${pkg}.${shell} version ${version}
  usage: ${pkg} [-a|-all] [OPTIONS]

  -a, --all                   Short variant of -l -L -g -H'btrfs zfs zram' -t -q
  -f, --font=ter-v14n         Fonts to include in the initramfs
  -F, --firmware=name         Firmware file/directory to include
  -k, --kernel-version=KV     Build an initramfs for kernel version VERSION
  -c, --compressor='gzip -9'  Use 'gzip -9' compressor instead of default
  -L, --luks                  Enable LUKS support (require cryptsetup binary)
  -l, --lvm                   Enable LVM2 support (require lvm2 binary)
  -b, --bin=<bins>            Binar-y-ies to include if available
  -d, --usrdir=DIRECTORY      Use DIRECTORY as USRDIR instead of the default
  -g, --gpg                   Enable GnuPG support (require gnupg-1.4.x)
  -p, --prefix=initrd-        Use 'initrd-' prefix instead of default ['initramfs-']
  -H, --hook=<name>           Include hook or script if available
  -m, --module=<mod>          Include kernel modules if available
      --module-tuxonice=mod   Append kernel modules to tuxonice group
      --module-remdev=mod     Append kernel modules to remdev   group
      --module-squashd=mod    Append kernel modules to squashd  group
      --module-gpg=mod        Append kernel modules to gpg      group
      --module-boot=mod       Append kernel modules to boot     group
  -s, --splash=<theme>        Include splash themes  if available
  -t, --toi                   Enable TuxOnIce support (require tuxoniceui-userui)
  -q, --squashd               Enable AUFS+SquashFS support (require aufs-util)
  -r, --rebuild               Re-Build an initramfs from an old directory
  -y, --keymap=fr-latin1      Keymaps to include the initramfs
  -K, --keep-tmpdir           Keep the temporary build directory
  -h, --help, -?              Print this help or usage message
EOH
exit $?
}

# @FUNCTION: Print error message to stderr & exit
die()
{
	local ret=${?}; error "${@}"; exit ${ret}
}

# @FUNCTION: (static/dynamic) Binary copy helper
# @ARG: <binary>
dobin() {
	local bin="${1}" lib
	docp ${bin} || return
	ldd ${bin} >${null} 2>&1 || return 0

	for lib in $(ldd ${bin} | sed -nre 's,.* (/.*lib.*/.*.so.*) .*,\1,p' \
	    -e 's,.*(/lib.*/ld.*.so.*) .*,\1,p'); do
		mkdir -p .${lib%/*} && docp ${lib} || die
	done
}

# @FUNCTION: File copy helper (handle symlinks)
# @ARG: <file>
docp() {
	local link=${1} prefix
	[ -n "${1}" -a -e "${1}" ] || return
	mkdir -p .${1%/*}
	rm -f .${1} && cp -a ${1} .${1} || die

	[ -h ${link} ] &&
	while true; do
	    prefix=${link%/*}
		link=$(readlink ${link})
		[ ${link%/*} = ${link} ] && link=${prefix}/${link}
		rm -f .${link} && cp -a ${link} .${link} || die
		[ -h ${link} ] || break
	done
	return 0
}

# @FUNCTION: CPIO image builder
docpio() {
	local ext=.cpio irfs=${1:-/boot/$initramfs}
	local cmd="find . -print0 | cpio -0 -ov -Hnewc"

	case "${compressor%% *}" in
		(bzip2) ext+=.bz2;;
		(gzip)  ext+=.gz ;;
		(xz)    ext+=.xz ;;
		(lzma)  ext+=.lzma;;
		(lzip)  ext+=.lz ;;
		(lzop)  ext+=.lzo;;
		(lz4)   ext+=.lz4;;
		(*) compressor=; warn "Initramfs will not be compressed";;
	esac
	if [ -f ${irfs}${ext} ]; then
	    mv ${irfs}${ext} ${irfs}${ext}.old
	fi
	if [ -n "${ext#.cpio}" ]; then
		cmd+=" | ${compressor} -c"
	fi
	eval ${cmd} >/${irfs}${ext} ||
	die "Failed to build ${irfs}${ext} initramfs"
}

# @FUNCTION: Kernel module copy helper
# @ARG: [-v|--verbose] <module-group>
domod() {
	case "${1}" in
		(-v|--verbose)
			local verbose="${2}"
			shift 2;;
	esac
	local m mod ret n p=/lib/modules/${kv}/

	for mod; do
		modules="$(sed -nre "s/(${mod}(|[_-]).*$)/\1/p" .${p}modules.dep)"
		if [ -n "${modules}" ]; then
			for m in ${modules}; do
				case "${m}" in
					(*:)
					m="${m%:}"
					if [ "${verbose}" ]; then
						n="${m##*/}"
						echo "${n/.ko}" >>${verbose} || die
					fi
					;;
				esac
				mkdir -p .${p}${m%/*} && cp -ar ${p}${m} .${p}${m} ||
					die "Failed to copy ${m} kernel module"
			done
		else
			warn "${mod} kernel module not found"
			ret=$((${ret}+1))
		fi
	done
	return ${ret}
}

# @FUNCTION: Device nodes (helper)
donod() {
	pushd dev || die
	[ -c console ] || mknod -m 600 console c 5 1 || die
	[ -c urandom ] || mknod -m 666 urandom c 1 9 || die
	[ -c random  ] || mknod -m 666 random  c 1 8 || die
	[ -c mem     ] || mknod -m 640 mem     c 1 1 && chmod 0:9 mem || die
	[ -c null    ] || mknod -m 666 null    c 1 3 || die
	[ -c tty     ] || mknod -m 666 tty     c 5 0 || die
	[ -c zero    ] || mknod -m 666 zero    c 1 5 || die

	local i=0
	while [ ${i} -lt 8 ]; do
		[ -c tty${i} ] || mknod -m 600 tty${i} c 4 ${i} || die
	done
	popd || die
}

# @FUNCTION: Temporary dir/file helper
mktmp() {
	local tmp="${TMPDIR:-/tmp}/${1}-XXXXXX"
	mkdir -p "${tmp}" || die "Failed to make ${tmp}"
	echo "${tmp}"
}

[ -f ./${pkg}.conf ] && source ./${pkg}.conf ||
	die "No ${name}.conf configuration file found"

opt="$(getopt \
	-o ab:c:f:F:gk:lH:KLm:p:qrs:thu:y:\? \
	-l all,bin:,compressor:,firmware:,font:,gpg,help \
	-l hook:,luks,lvm,keep-tmpdir,module:,keymap:,kernel-version: \
	-l module-boot:,module-gpg:,module-remdev:,module-squashd:,module-tuxonice: \
	-l prefix:,rebuild,splash:,squashd,toi,usrdir: \
	-n ${name} -s sh -- "${@}" || usage)"
eval set -- ${opt}

while true; do
	case "${1}" in
		(--) shift; break;;
		(-a|--all) opt_all=1;;
		(-l|--lvm) opt_lvm=1;;
		(-t|--toi) opt_toi=1;;
		(-g|--gpg) opt_gpg=1;;
		(-L|--luks) opt_luks=1;;
		(-q|--squashd) opt_squashd=1;;
		(-r|--rebuild) opt_rebuild=1;;
		(-K|--keep-tmpdir) opt_tmpdir=1;;
		(-b|--bin) shift; bins="${bins} ${1}";;
		(-k|--kernel-version) shift; kv="${1}";;
		(-f|--font) shift; fonts="${1} ${fonts}";;
		(-c|--compressor) shift; compressor="${1}";;
		(-y|--keymap) shift; keymaps="${1} ${keymaps}";;
		(-m|--module) shift; modules="${modules} ${1}";;
		(-f|--firmware) shift; firmwares="${firmware} ${1}";;
		(--module-*) eval ${1/-/_}="\$${1/-/_} ${2}"; shift;;
		(-s|--splash) shift; splash="${splash} ${1}";;
		(-H|--hook) shift; hooks="${hooks} ${1}";;
		(-d|--usrdir) shift; usrdir="${1}";;
		(-p|--prefix) shift; prefix="${1}";;
		(-?|-h|--help|*) usage;;
	esac
	shift
done

# @VARIABLE: Kernel version
:	${kv:=$(uname -r)}
# @VARIABLE: Initramfs prefx
:	${prefix:=initramfs-}
# @VARIABLE: USRDIR path to use
:	${usrdir:=${PWD}/usr}
# @VARIABLE: Full path to initramfs image
:	${initramfs=${prefix}${kv}}
:	${compressor:=xz -9 --check=crc32}
# @VARIABLE: Kernel ARCHitecture
:	${ARCH:=$(uname -m)}
# @VARIABLE: Kernel bit lenght
:	${LONG_BIT:=$(getconf LONG_BIT)}
# @VARIABLE: (initramfs) Tmporary directory
tmpdir="$(mktmp ${initramfs})"
# @DESCRIPTION: (initramfs) Configuration directory
confdir="etc/${pkg}"
source "${usrdir}"/lib/${pkg}/functions || exit 1
eval_colors

if [ -n "${opt_all}" ]; then
	fonts="${fonts-:}" keymaps="${keymaps-:}" hooks="${hooks} btrfs zfs zram"
	opt_gpg=true opt_lvm=true opt_squashd=true opt_toi=true opt_luks=true
fi
if [ -n "${fonts}" -a "${fonts}" = ":" ] && [ -e /etc/conf.d/consolefont ]; then
	fonts="${fonts} $(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' \
		/etc/conf.d/consolefont)"
fi
if [ -n "${keymaps}" -a "${keymaps}" = ":" ] && [ -e /etc/conf.d/keymaps ]; then
	keymaps="${keymaps} $(sed -nre 's,^keymap="([a-zA-Z].*)",\1,p' \
		/etc/conf.d/keymaps)"
fi

case "${compressor}" in
	(none) ;;
	([a-z]*)
	if [ -e /usr/src/linux-${kv}/.config ]; then
		config=/usr/src/linux-${kv}/.config
		xgrep=$(type -p grep 2>${null})
	elif [ -e /proc/config.gz ]; then
		config=/proc/config.gz
		xgrep=$(type -p zgrep 2>${null})
	else
		warn "No kernel config file found"
	fi
esac
if [ -f "${config}" ]; then
	comp="${compressor%% *}"
	CONFIG=CONFIG_RD_$(echo "${comp}" | tr '[a-z]' '[A-Z]')
	if ! ${xgrep} -q "^${CONFIG}=y" ${config} >${null} 2>&1; then
		warn "${comp} compressor is not supported by kernel-${kv}"
		for comp in bzip2 gzip lzip lzop lz4 xz; do
			CONFIG=CONFIG_RD_$(echo "${comp}" | tr '[a-z]' '[A-Z]')
			if ${xgrep} -q "^${CONFIG}=y" ${config}; then
				compressor="${comp} -9"
				info "Setting up compressor to ${comp}"
				break
			elif [ "${comp}" = "xz" ]; then
				warn "No suitable compressor support found in kernel-${kv}"
				compressor=
			fi
		done
	fi
	unset config xgrep CONFIG comp
fi

echo " >>> Building ${initramfs}..."
cd "${tmpdir}" || die "${tmpdir} not found"

if [ -n "${rebuild}" ]; then
	cp -af "${usrdir}"/lib/${pkg}/functions lib/${pkg} &&
	cp -af "${usrdir}"/../init . && chmod 775 init || die
	docpio
	echo " >>> Regenerated ${initramfs}"
	exit
else
	rm -fr *
fi

# Set up the initramfs
if [ -d "${usrdir}" ]; then
	cp -ar "${usrdir}" . &&
	mv -f usr/root usr/etc . &&
	mv -f usr/lib lib${LONG_BIT} || die
else 
	die "${usrdir} usrdir not found"
fi
mkdir -p usr/share/consolefonts usr/share/keymaps usr/lib${LONG_BIT} \
	usr/bin usr/sbin sbin bin dev proc sys newroot mnt/tok etc/${pkg} \
	etc/splash run lib${LONG_BIT}/modules/${kv} lib${LONG_BIT}/${pkg} || die
for dir in lib usr/lib; do
	ln -s lib${LONG_BIT} ${dir}
done

{
	for key in pkg shell version; do
		eval echo "${key}=\${$key}"
	done
	echo "build=$(date +%Y-%m-%d-%H-%M-%S)"
} >${confdir}/id
touch etc/fstab etc/mtab

cp -a /dev/console /dev/random /dev/urandom /dev/mem /dev/null /dev/tty \
	/dev/tty[0-6] /dev/zero dev/ || donod
major="${kv%%.*}" minor="${kv#*.}"
minor="${minor%%.*}"
if [ "${major}" -eq 3 -a "${minor}" -ge 1 ]; then
	cp -a /dev/loop-control dev/ >$null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
fi
unset major minor

cp -a "${usrdir}"/../init . && chmod 775 init || die
[ -d root ] && chmod 0700 root || mkdir -m 0700 root || die
cp -af /lib/modules/${kv}/modules.dep lib/modules/${kv} ||
	die "Failed to copy modules.dep"

# Set up (requested) firmware
if [ -n "${firmwares}" ]; then
	case "${firmwares}" in
		(:)
		warn "Adding the whole firmware directory"
		cp -a /lib/firmware lib
		;;
		(*)
		mkdir -p lib/firmware
		for fw in ${firmwares}; do
			[ -e ${fw} ] && cp -a ${fw} lib/firmware ||
				for fw in /lib/firmware/*${fw}*; do
					docp ${fw}
				done
		done
		;;
	esac
fi

# Set up RAID option
for bin in dmraid mdadm zfs; do
	case "${bins}" in
		(*${bin}*) module_group="${module_group} ${bin}";;
	esac
done
module_group="${module_group/mdadm/raid}"

# Set up (requested) hook
for hook in ${hooks}; do
	for file in "${usrdir}"/../hooks/*${hook}*; do
		cp -a "${file}" lib/${pkg}/
	done
	if [ ${?} != 0 ]; then
		warn "No $hook hook/script does not exist"
		continue
	fi
	eval bins="\"${bins} \${bin_$hook}\""
	module_group="${module_group} ${hook}"
done

[ -f /etc/issue.logo ] && cp /etc/issue.logo etc/

# Handle & copy BusyBox binary
if [ -x usr/bin/busybox ]; then
	mv -f usr/bin/busybox bin/
elif type -p busybox >${null} 2>&1; then
	bb=$(type -p busybox 2>${null})
	if ldd ${bb} >${null} 2>&1; then
		busybox --list-full >${confdir}/busybox.applets
		bin="${bd} ${bin}"
		warn "busybox is not a static binary"
	fi
	cp -a ${bb} bin/
	unset bb
else
	die "No busybox binary found"
fi
if [ ! -f ${confdir}/busybox.applets ]; then
	bin/busybox --list-full >${confdir}/busybox.applets || die
fi
while read bin; do
	grep -q ${bin} ${confdir}/busybox.applets ||
	die "${bin} applet not found, no suitable busybox found"
done <"${usrdir}"/../scripts/minimal.applets
for bin in $(grep  '^bin/' ${confdir}/busybox.applets); do
	ln -s busybox ${bin}
done
for bin in $(grep '^sbin/' ${confdir}/busybox.applets); do
	ln -s ../bin/busybox ${bin}
done

# Set up a few options
if [ -n "${opt_luks}" ]; then
	bins="${bins} cryptsetup" module_group="${module_group} dm-crypt"
fi
if [ -n "${opts_squashd}" ]; then
	bins="${bins} umount.aufs mount.aufs" module_group="${module_group} squashd"
fi
if [ -n "${opts_gpg}" ]; then
	if [ -x usr/bin/gpg ]; then :;
	elif [ "$(gpg --version | sed -nre '/^gpg/s/.* ([0-9]{1})\..*$/\1/p')" -eq 1 ]; then
		bins="${bins} $(type -p gpg 2>${null})"
	else
		die "No usable gpg/gnupg-1.4.x binary found"
	fi
fi
if [ -n "${opt_lvm}" ]; then
	bins="${bins} lvm" module_group="${module_group} device-mapper"
fi

# Handle & copy keymap/consolefont
for keymap in ${keymaps}; do
	if [ -f usr/share/keymaps/${keymap}-${ARCH}.bin ]; then
		:;
	elif [ -f "${keymap}" ]; then
		cp -a "${keymap}" usr/share/keymaps/
	else 
		loadkeys -b -u ${keymap} >usr/share/keymaps/${keymap}-${ARCH}.bin ||
			die "Failed to build ${keymap} keymap"
	fi
	[ ${?} = 0 ] && KEYMAPS="${KEYMAPS+$KEYMAPS }${keymap}-${ARCH}.bin"
done
echo "${KEYMAPS%% *}" >${confdir}/kmap

for font in ${fonts}; do
	if [ -f usr/share/consolefonts/${font} ]; then :;
	elif [ -f ${font} ]; then
		cp -a ${font} usr/share/consolefonts/ 
	else 
		for file in /usr/share/consolefonts/${font}*.gz; do
			if [ -f ${file} ]; then
				cp ${file} . 
				gzip -d ${file##*/}
			fi
		done
		mv ${font}* usr/share/consolefonts/
	fi
	[ ${?} = 0 ] && FONTS="${FONTS+$FONTS }${font}"
done
echo "${FONTS%% *}" >${confdir}/font
unset FONTS font KEYMAPS keymap

# Handle & copy splash themes
if [ -n "${splash}" ]; then
	bins="${bins} splash_util.static fbcondecor_helper"

	if [ -n "${opt_toi}" ]; then
		bins="${bins} tuxoniceui_text" && module_group="${module_group} tuxonice"
	fi
	for theme in ${splash}; do
		if [ -d etc/splash/${theme} ]; then :;
		elif [ -d /etc/splash/${theme} ]; then
			cp -r /etc/splash/${theme} etc/splash/
		elif [ -d ${theme} ]; then
			cp -ar ${theme} etc/splash/
		else
			warn "Failed to copy ${theme} theme"
		fi
	done
fi

# Handle & copy binaries
for bin in ${bins}; do
	for b in usr/*bin/${bin} *bin/${bin}; do
		[ -x ${b} -a ! -h ${b} ] && continue 2
	done
	[ -x ${bin} ] && binary=${bin} || binary=$(type -p ${bin} 2>${null})
	[ -n "${binary}" ] && dobin ${binary} || warn "no ${bin} binary found"
done
unset binary bin b

# Handle & copy kernel module
domod ${modules}

for mod in ${module_boot}; do
	if eval [ -n \"\${module_$mod}\" ]; then
		echo "${mod}" >> ${confdir}/boot
	else
		mboot="${boot} ${mod}"
	fi
done
module_boot="${mboot}"
unset mboot mod

for group in ${module_group}; do
	eval domod -v ${confdir}/${group/_/-} \${module_${group/-/_}}
done

# Set up user environment if present
for e in ${env}; do
	echo "${e}" >>${confdir}/env
done
unset e env

# Handle GCC libraries symlinks
[ -d usr/lib/gcc ] &&
for lib in $(find usr/lib/gcc -iname 'lib*'); do
	ln -fns /$lib     lib/${lib##*/}
	ln -fns /$lib usr/lib/${lib##*/}
done

docpio
[ -n "${opt_tmpdir}" ] || rm -rf ${tmpdir}
echo ">>> Built ${initramfs} initramfs"

#
# vim:fenc=utf-8:ci:pi:sts=2:sw=2:ts=2:
#
