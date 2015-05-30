#!/bin/bash
#
# $Header: mkinitramfs-ll/svc/sdr.bash                   Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.21.0 2015/05/28 12:33:03                   Exp $
#

shopt -qs extglob
typeset -A PKG
PKG=(
	[name]=sdr
	[shell]=bash
	[version]=0.21.0
)
NULL=/dev/null

# @FUNCTION: Print help message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options] <directory-ies>

  -f, --filesystem=aufs     Set the merge-filesystem to use
  -q, --squash-root=<dir>   Set root directory (default '/squash')
  -b, --block-size=131072   Set block size in bytes (default 128KB)
  -x, --busybox=busybox     Static BusyBox to use (System Wide case)
  -c, --compressor=gzip     Set compressor to use (default to lzo)
  -X, --exclude=:<dir>      Director-ies-y (list) to exlude from image
  -o, --offset=0            Offset to use when rebuilding (default 10%)
  -u, --update              Update the underlying source directory
  -r, --remove              Remove the underlying source directory
  -m, --mount               Enable mount-only mode, no-(re)build
  -M, --no-mount            Disable mount, (re-)build-only mode
  -U, --unmount             Enable unmount-only mode, no-build
  -h, --help, -?            Print this help message and exit
EOH
exit $?
}
(( $# == 0 )) && usage

# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
declare -A opts
declare -a opt
opt=(
	"-o" "?b:c:f:o:Mmnhruq:X:x:"
	"-l" "block-size:,busybox:,compressor:,exclude:,filesystem:,offset,help"
	"-l" "mount,no-mount,squash-root:,remove,update,unmount"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

while true; do
	case "${1}" in
		(-x|--busybox) opts[-busybox]="${2}"; shift;;
		(-b|--block-size) opts[-block-size]="${2}"; shift;;
		(-f|--filesystem) opts[-filesystem]="${2}"; shift;;
		(-q|--squash-root) opts[squash-root]="${2}"; shift;;
		(-c|--compressor)  opts[-compressor]="${2}"; shift;;
		(-X|--exclude) opts[-exclude]+=":${2}"; shift;;
		(-o|--offset) opts[-offset]="${2}"; shift;;
		(-u|--update)  opts[-keep-dir]=1;;
		(-r|--remove)  opts[-keep-dir]=0;;
		(-n|--no-mount) opts[-mount]=0;;
		(-m|--mount)    opts[-mount]=2;;
		(-M|--unmount)  opts[-mount]=3;;
		(--) shift; break;;
		(-h|--help|-?|*) usage;;
	esac
	shift
done

# @DESCRIPTION: print info message to stdout
function info {
	echo -ne " \e[1;32m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n"
}
# @FUNCTION: Print info message to stdout
function error {
	echo -ne " \e[1;31m* \e[0m${PKG[name]}.${PKG[shell]}: $@\n"
}
# @FUNCPTION: Fatal error heler
function die {
	local ret=${?}; error "${@}"; exit ${ret}
}

# @VARIABLE: Root directory (mount hierarchy)
:	${opts[squash-root]:=/squash}
:	${opts[-block-size]:=131072}
# @VARIABLE: Full path to a static busysbox (required for system update)
:	${opts[-busybox]:=$(type -p busybox 2>${NULL})}
# @VARIABLE: Compression command
:	${opts[-compressor]:=lzo -Xcompression-level 1}
# @VARIABLE: rw/rr branch ration (percent)
:	${opts[-offset]:=10}
:	${opts[-mount]:=1}

# @FUNCTION: Helper to mount squashed directory
function squash-mount {
	local cp grep mv rm mount umount mkdir
	case "${dir}" in
		(/bin|/sbin|/lib32|/lib64)
		ldd ${busybox} >${NULL} 2>&1 && die "No static busybox binary found"
		cp ${busybox} /tmp && busybox=/tmp/busybox || die
		cp="${busybox} cp -a" mv="${busybox} mv" rm="${busybox} rm -fr"
		mount="${busybox} mount" umount="${busybox} umount"
		grep="${busybox} grep" mkdir="${busybox} mkdir -p -m 0755"
		;;
		(*)
		cp="cp -a" grep=grep mv=mv rm="rm -fr"
		mount=mount umount=umount mkdir="mkdir -p -m 0755"
		;;
	esac

	if ${grep} -q ${opts[-filesystem]}:${dir} /proc/mounts; then
		case "${opts[-filesystem]}" in
			(aufs) auplink ${dir} flush >${NULL} 2>&1;;
		esac
		${umount} -l ${opts[-filesystem]}:${dir} >${NULL} 2>&1 ||
			die "Failed to umount ${opts[-filesystem]}:${dir}"
	fi
	if ${grep} -q ${DIR}/rr /proc/mounts; then
		${umount} -l ${DIR}/rr >${NULL} 2>&1 ||
			die "Failed to umount ${DIR}.squashfs"
	fi
	(( ${opts[-mount]} > 2 )) && return

	[[ -e ${DIR}.squashfs ]] && [[ -e ${DIR}.tmp.squashfs ]] &&
		${rm} ${DIR}.squashfs && ${mv} ${DIR}.tmp.squashfs ${DIR}.squashfs
	case "${opts[-filesystem]}" in
		(aufs)    ${rm} ${DIR}/rw && ${mkdir} ${DIR}/rw ||
			die "Failed to clean up ${DIR}/rw";;
		(overlay) ${rm} ${DIR}/{up,wk} && ${mkdir} ${DIR}/{up,wk} ||
			die "Failed to clean up ${DIR}/{up,wk}";;
	esac
	${mount} -t squashfs -o nodev,loop,ro ${DIR}.squashfs ${DIR}/rr >${NULL} 2>&1 ||
		die "Failed to mount ${DIR}.squashfs"

	if [[ "${opts[-keep-dir]}" ]]; then
		${rm} ${dir} && ${mkdir} ${dir} ||
			die "Failed to remove ${dir}"
	fi
	case "${opts[-keep-dir]}" in
		(1) ${cp} ${DIR}/rr ${dir} ||
			die "Failed to update ${dir}";;
	esac

	${mount} -t ${opts[-filesystem]} -o ${opt} \
		${opts[-filesystem]}:${dir} ${dir} >${NULL} 2>&1 ||
		die "Failed to mount ${opts[-filesystem]}:${dir}"
}
# @FUNCTION: Helper to squash-directory
function squash-dir {
	case "${opts[-filesystem]}" in
		(aufs)
			opt=nodev,udba=reval,br:${DIR}/rw:${DIR}/rr
			mkdir -p -m 0755 ${DIR}/r{r,w};;
		(overlay)
			opt=nodev,upperdir=${DIR}/up,lowerdir=${DIR}/rr,workdir=${DIR}/wk
			mkdir -p -m 0755 ${DIR}/{rr,up,wk};;
	esac
	(( ${?} == 0 )) || die "Failed to create required directories"
	(( ${opts[-mount]} > 1 )) && { squash-mount; return; }

	mksquashfs ${dir} ${DIR}.tmp.squashfs -b ${opts[-block-size]} -comp ${opts[-compressor]} \
		${opts[-exclude]:+-wildcards -regex -e} ${opts[-exclude]} ||
		die "Failed to build ${dir}.squashfs image"
	echo -e "\e[1;36m>>>\e[0m Sucessfully build ${DIR}.tmp.squashfs"

	(( ${opts[-mount]} )) && squash-mount
}

for mod in ${opts[-filesystem]:-aufs overlay} squashfs; do
	grep -q ${mod} /proc/filesystems || modprobe ${mod} >${NULL} 2>&1 ||
		case ${mod} in
			(aufsi|overlay) error "Failed to load ${mod} module"; opts[-mount]=0;;
			(squashfs) die  "Failed to load ${mod} module";;
		esac
	case "${mod}" in
		(aufs|overlay) opts[-filesystem]="${mod}"
			case "${mod}" in
				(aufs) RW=rw;;
				(ove*) RW=up;;
			esac;;
	esac
done

for dir in ${*//:/ }; do
	DIR="/${opts[squash-root]#/}/${dir#/}" dir="/${dir#/}"
	if [[ -e ${DIR}.squashfs ]]; then
		case "${opts[-mount]}" in
			(3) echo -e "\e[1;34m>>>\e[0m Umounting ${dir}..."
				squash-dir; continue;;
			(2) echo -e "\e[1;35m>>>\e[0m Mounting ${dir}..."
				squash-dir; continue;;
		esac
		if (( ${opts[-offset]} != 0 )); then
			rr=$(du -sk ${DIR}/rr    | awk '{print $1}')
			rw=$(du -sk ${DIR}/${RW} | awk '{print $1}')
			if (( (${rw}*100/${rr}) < ${opts[-offset]} )); then
				echo -e "\e[1;31m>>>\e[0m Skiping ${dir}... or use -o option"
			else
				echo -e "\e[1;32m>>>\e[0m Updating squashed ${dir}..."
				squash-dir
			fi
		else
			echo -e "\e[1;32m>>>\e[0m Updating squashed ${dir}..."
			squash-dir
		fi
	else
		echo -e "\e[1;32m>>>\e[0m Building squashed ${dir}..."
		squash-dir
	fi			
done

[[ -x "${busybox}" ]] && rm -f "${busybox}"

unset DIR RW dir opt opts rr rw

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
