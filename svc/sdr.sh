#!/bin/sh
#
# $Header: mkinitramfs-ll/svc/sdr.sh                     Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.21.0 2015/05/28 12:33:03                   Exp $
#

name=sdr
version=0.21.0
NULL=/dev/null

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${name} version ${version}
  usage: ${0##*/} [OPTIONS] <directory-ies>

  -f, --filesystem=aufs     Set the merge-filesystem to use
  -q, --squash-root=<dir>   Set root directory (default '/squash')
  -b, --block-size=131072   Set block size in bytes (default 128KB)
  -x, --busybox=busybox     Static BusyBox to use (System Wide case)
  -c, --compressor=gzip     Set compressor to use (default to lzo)
  -X, --exclude=<dir>       Director-ies-y (list) to exlude from image
  -o, --offset=0            Offset to use when rebuilding (default 10%)
  -u, --update              Update the underlying source directory
  -r, --remove              Remove the underlying source directory
  -m, --mount               Enable mount-only mode, no-(re)build
  -n, --no-mount            Disable mount, (re-)build-only mode
  -M, --unmount             Enable unmount-only mode, no-build
  -h, --help, -?            Print this help message and exit
EOH
${1:+exit $1}
}

[ ${#} = 0 ] && usage 1

opt="$(getopt \
	-o \?b:c:f:o:Mmnhruq:X:x:: \
	-l block-size:,busybox::,compressor:,exclude:,filesystem:,offset,help \
	-l mount,no-mount,squash-root:,remove,update,unmount \
	-n "${name}" -s sh -- "${@}" || usage)"
[ ${?} = 0 ] || exit 2
eval set -- ${opt}

while true; do
	case "${1}" in
		(-x|--busybox) shift; busybox="${1:-$(type -p busybox 2>${NULL})}";;
		(-X|--exclude) shift; exclude="${exlude} ${1}";;
		(-f|--filesystem) shift; filesystem="${1}";;
		(-b|--block-*) shift; block_size="${1}";;
		(-c|--compre*) shift; compressor="${1}";;
		(-q|--squash-root) shift; squash_root="${1}";;
		(-o|--offset)  shift; offset="${1}";;
		(-n|--no-mount) mount_dir=0;;
		(-m|--mount)   mount_dir=2;;
		(-M|--unmount) mount_dir=3;;
		(-u|--update) update=true;;
		(-r|--remove) remove=true;;
		(--) shift; break;;
		(-h|--help|-?|*) usage 0;;
	esac
	shift
done

:	${usrdir:=${PWD}/usr}
source "${usrdir}"/lib/mkinitramfs-ll/functions || exit 1
eval_colors
:	${squash_root:=/squash}
:	${block_size:=131072}
:	${busybox:=$(type -p busybox 2>${NULL})}
:	${compressor:=lzo -Xcompression-level 1}
:	${offset:=10}
:	${mount_dir:=1}

#
# @FUNCTION: Print error message to stderr & exit
#
die()
{
	local ret=${?}; error "${@}"; exit ${ret}
}

# @FUNCTION: Helper to mount squashed directory
squash_mount() {
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

	if ${grep} -q ${filesystem}:${dir} /proc/mounts; then
		case "${filesystem}" in
			(aufs) auplink ${dir} flush >${NULL} 2>&1;;
		esac
		${umount} -l ${filesystem}:${dir} >${NULL} 2>&1 ||
			die "Failed to umount aufs:${dir}"
	fi
	if ${grep} -q ${DIR}/rr /proc/mounts; then
		${umount} -l ${DIR}/rr >${NULL} 2>&1 ||
			die "Failed to umount ${DIR}.squashfs"
	fi
	[  "${mount_dir}" -gt 2 ] && return

	[ -e ${DIR}.squashfs -a -e ${DIR}.tmp.squashfs ] &&
		${rm} ${DIR}.squashfs && ${mv} ${DIR}.tmp.squashfs ${DIR}.squashfs
	case "${filesystem}" in
		(aufs)    ${rm} ${DIR}/rw && ${mkdir} ${DIR}/rw ||
			die "Failed to clean up ${DIR}/rw";;
		(overlay) ${rm} ${DIR}/up ${DIR}/wk && ${mkdir} ${DIR}/up ${DIR}/wk ||
			die "Failed to clean up ${DIR}/{up,wk}";;
	esac
	${mount} -t squashfs -o nodev,loop,ro ${DIR}.squashfs ${DIR}/rr >${NULL} 2>&1 ||
		die "Failed to mount ${DIR}.squashfs"
	if [ -n "${remove}" ]; then
		${rm} ${dir} && ${mkdir} ${dir} || die "Failed to clean up ${dir}"
	fi
	if [ -n "${update}" ]; then
		${rm} ${dir} && ${mkdir} ${dir} && ${cp} ${DIR}/rr ${dir} ||
			die "Failed to update ${dir}"
	fi
	${mount} -t ${filesystem} -o ${opt} \
		${filesystem}:${dir} ${dir} >${NULL} 2>&1 ||
		die "Failed to mount ${filesystem}:${dir}"
}
# @FUNCTION: Helper to squash-directory
squash_dir() {
	case "${filesystem}" in
		(aufs)
			opt=nodev,udba=reval,br:${DIR}/rw:${DIR}/rr
			mkdir -p -m 0755 ${DIR}/rr ${DIR}/rw;;
		(overlay)
			opt=nodev,upperdir=${DIR}/up,lowerdir=${DIR}/rr,workdir=${DIR}/wk
			mkdir -p -m 0755 ${DIR}/rr ${DIR}/up ${DIR}/wk;;
	esac
	[ "${?}" = 0 ] || die "Failed to create required directories"
	[ "${mount_dir}" -gt 1 ] && { squash_mount; return; }

	mksquashfs ${dir} ${DIR}.tmp.squashfs -b ${block_size} -comp ${compressor} \
		${exclude+=-wildcards -regex -e} ${exclude} ||
		die "Failed to build ${dir}.squashfs image"
	echo ">>> ${0##*/}: ...sucessfully build squashed"

	[ "${mount_dir}" = 1 ] && squash_mount
}

for mod in ${filesystem:-aufs overlay} squashfs; do
	grep -q ${mod} /proc/filesystems || modprobe ${mod} >${NULL} 2>&1 ||
		case ${mod} in
			(aufs|overlay) error "Failed to load ${mod} module"; mount_dir=false;;
			(squashfs) die  "Failed to load ${mod} module";;
		esac
	case "${mod}" in
		(aufs|overlay) filesystem="${mod}"
			case "${mod}" in
				(aufs) RW=rw;;
				(ove*) RW=up;;
			esac;;
	esac
done

for dir in ${*}; do
	DIR="/${squash_root#/}/${dir#/}" dir="/${dir#/}"
	if [ -e ${DIR}.squashfs ]; then
		case "${mount_dir}" in
			(3) echo -e "\e[1;34m>>>\e[0m Umounting ${dir}..."
				squash_dir; continue;;
			(2) echo -e "\e[1;35m>>>\e[0m Mounting ${dir}..."
				squash_dir; continue;;
		esac
		if [ ${offset} != 0 ]; then
			rr=$(du -sk ${DIR}/rr    | awk '{print $1}')
			rw=$(du -sk ${DIR}/${RW} | awk '{print $1}')
			if [ $((${rw} * 100 / ${rr})) -lt ${offset} ]; then
				echo -e "\e[1;31m>>>\e[0m Skiping ${dir}... or use -o option"
			else
				echo -e "\e[1;32m>>>\e[0m Updating squashed ${dir}..."
				squash_dir
			fi
		else
			echo -e "\e[1;32m>>>\e[0m Updating squashed ${dir}..."
			squash_dir
		fi
	else
		echo -e "\e[1;32m>>>\e[0m Building squashed ${dir}..."
		squash_dir
	fi
	end "${?}"
done

[ -x "${busybox}" ] && rm -f "${busybox}"
unset DIR RW dir exclude filesystem rr rw opt mount_dir squash_root

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
