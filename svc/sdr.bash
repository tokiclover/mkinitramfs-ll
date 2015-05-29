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
  -n, --no-mount            Disable mount after rebuild or update
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
	"-o" "?b:c:f:o:nhruq:X:x::"
	"-l" "block-size:,busybox::,compressor:,exclude:,filesystem:,offset,help"
	"-l" "no-mount,squash-root:,remove,update"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

while true; do
	case "$1" in
		(-b|--block-size)
			opts[-block-size]="$2"
			shift 2;;
		(-x|--busybox)
			opts[-busybox]="${2:-$commands[busybox]}"
			shift 2;;
		(-f|--filesystem)
			opts[-filesystem]="$2"
			shift 2;;
		(-o|--offset)
			opts[-offset]="$2"
			shift 2;;
		(-X|--exclude) opts[-exclude]+=":$2"
			shift 2;;
		(-q|--squash-root)
			opts[squash-root]="$2"
			shift 2;;
		(-c|--compressor)
			opts[-compressor]="$2"
			shift 2;;
		(-u|--update)
			opts[-update]=true
			shift;;
		(-r|--remove)
			opts[-remove]=true
			shift;;
		(-n|--no-mount)
			opts[-mount]=false
			shift;;
		(--)
			shift
			break;;
		(-h|--help|-?|*)
			usage;;
	esac
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
	local ret=$?
	error "$@"
	exit $ret
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
	${rm} "${DIR}"/rw/* || die "Failed to clean up ${DIR}/rw"

	[[ -e ${DIR}.squashfs ]] && [[ -e ${DIR}.tmp.squashfs ]] &&
		${rm} ${DIR}.squashfs
	${mv} ${DIR}.tmp.squashfs ${DIR}.squashfs ||
		die "Failed to move ${dir}.tmp.squashfs"

	${mount} -t squashfs -o nodev,loop,ro ${DIR}.squashfs ${DIR}/rr >${NULL} 2>&1 ||
		die "Failed to mount ${DIR}.squashfs"
	if [[ "${opts[-remove]}" ]]; then
		${rm} ${dir} && ${mkdir} ${dir} || die "Failed to clean up ${dir}"
	fi
	if [[ "${opts[-update]}" ]]; then
		${rm} ${dir} && ${mkdir} ${dir} && ${cp} ${DIR}/rr ${dir} >${NULL} 2>&1 ||
			die "Failed to update ${dir}"
	fi
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

	mksquashfs ${dir} ${DIR}.tmp.squashfs -b ${opts[-block-size]} -comp ${opts[-compressor]} \
		${opts[-exclude]:+-wildcards -regex -e} ${opts[-exclude]} ||
		die "Failed to build ${dir}.squashfs image"
	echo ">>> ${0##*/}: ...sucessfully build squashed"

	[[ "${opts[-mount]}" ]] || squash-mount
}

for mod in ${opts[-filesystem]:-aufs overlay} squashfs; do
	grep -q ${mod} /proc/filesystems || modprobe ${mod} >${NULL} 2>&1 ||
		case ${mod} in
			(aufsi|overlay) error "Failed to load ${mod} module"; opts[-mount]=false;;
			(squashfs) die  "Failed to load ${mod} module";;
		esac
	case "${mod}" in
		(aufs|overlay) opts[-filesystem]="${mod}";;
	esac
done

for dir in ${*//:/ }; do
	DIR="/${opts[squash-root]#/}/${dir#/}" dir="/${dir#/}"
	if [[ -e ${DIR}.squashfs ]]; then
		if (( ${opts[-offset]} != 0 )); then
			rr=$(du -sk ${DIR}/rr | awk '{print $1}')
			rw=$(du -sk ${DIR}/rw | awk '{print $1}')
			if (( (${rw}*100/${rr}) < ${opts[-offset]} )); then
				info "skiping ${dir}, or append -o|--offset option"
			else
				echo ">>> ${0##*/}: updating squashed ${dir}..."
				squash-dir
			fi
		else
			echo ">>> ${0##*/}: updating squashed ${dir}..."
			squash-dir
		fi
	else
		echo ">>> ${0##*/}: building squashed ${dir}..."
		squash-dir
	fi			
done

[[ -f "${busybox}" ]] && rm -f "${busybox}"
unset DIR dir opt opts rr rw

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
