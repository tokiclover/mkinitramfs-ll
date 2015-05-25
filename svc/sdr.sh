#!/bin/sh
#
# $Header: mkinitramfs-ll/svc/sdr.sh                     Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.20.0 2015/05/24 12:33:03                   Exp $
#

name=sdr
version=0.20.0

# @FUNCTION: Print help message
usage() {
  cat <<-EOH
  ${name} version ${version}
  usage: ${0##*/} [OPTIONS] <directory-ies>

  -q, --squash-root=<dir>   Set root directory (default '/aufs')
  -b, --block-size=131072   Set block size in bytes (default 128KB)
  -x, --busybox=busybox     Static BusyBox to use (System Wide case)
  -c, --compressor=gzip     Set compressor to use (default to lzo)
  -X, --exclude=<dir>       Director-ies-y (list) to exlude from image
  -o, --offset=0            Offset to use when rebuilding (default 10%)
  -u, --update              Update the underlying source directory
  -r, --remove              Remove the underlying source directory
  -n, --no-remount          Disable mount after rebuild or update
  -h, --help, -?            Print this help message and exit
EOH
${1:+exit $1}
}

[ ${#} = 0 ] && usage 1

opt="$(getopt \
	-o \?b:c:o:nhruq:X:x:: \
	-l block-size:,busybox::,compressor:,exclude:,offset,help \
	-l no-remount,,squash-root:,remove,update \
	-n "${name}" -s sh -- "${@}" || usage)"
[ ${?} = 0 ] || exit 2
eval set -- ${opt}

while true; do
	case "${1}" in
		(-x|--busybox) shift; busybox="${1:-$(type -p busybox)}";;
		(-X|--exclude) shift; exclude="${exlude} ${1}";;
		(-b|--block-*) shift; block_size="${1}";;
		(-c|--compre*) shift; compressor="${1}";;
		(-q|--squash-root) shift; rootdir="${1}";;
		(-o|--offset)  shift; offset="${1}";;
		(-n|--no-remount) mount_dir=false;;
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
:	${rootdir:=/aufs}
:	${block_size:=131072}
:	${busybox:=$(type -p busybox)}
:	${compressor:=lzo -Xcompression-level 1}
:	${offset:=10}

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
		ldd ${busybox} >/dev/null 2>&1 && die "No static busybox binary found"
		cp ${busybox} /tmp && busybox=/tmp/busybox || die
		cp="${busybox} cp -a" mv="${busybox} mv" rm="${busybox} rm -fr"
		mount="${busybox} mount" umount="${busybox} umount"
		grep="${busybox} grep" mkdir="${busybox} mkdir -p"
		;;
		(*)
		cp="cp -a" grep=grep mv=mv rm="rm -fr"
		mount=mount umount=umount mkdir="mkdir -p"
		;;
	esac

	if ${grep} -q aufs:${dir} /proc/mounts; then
		auplink ${dir} flush
		${umount} -l aufs:${dir} || die "Failed to umount aufs:${dir}"
	fi
	if ${grep} -q ${DIR}/rr /proc/mounts; then
		${umount} -l ${DIR}/rr || die "Failed to umount ${DIR}.squashfs"
	fi
	${rm} "${DIR}"/rw/* || die "Failed to clean up ${DIR}/rw"

	[ -e ${DIR}.squashfs -a -e ${DIR}.tmp.squashfs ] &&
	${rm} ${DIR}.squashfs
	${mv} ${DIR}.tmp.squashfs ${DIR}.squashfs ||
		die "Failed to move ${dir}.tmp.squashfs"

	if ${mount} -t squashfs -o nodev,loop,ro ${DIR}.squashfs ${DIR}/rr; then
		if [ -n "${remove}" ]; then
			${rm} ${dir} && $mkdir ${dir} || die "Failed to clean up ${dir}"
		fi
		if [ -n "${update}" ]; then
			${rm} ${dir} && $mkdir ${dir} && ${cp} ${DIR}/rr ${dir} ||
			die "Failed to update ${dir}"
		fi
		${mount} -t aufs -o nodev,udba=reval,br:${DIR}/rw:${DIR}/rr aufs:${dir} ${dir} ||
		die "Failed to mount aufs:${dir} branch"
	else
		die "Failed to mount ${DIR}.squashfs"
	fi
}
# @FUNCTION: Helper to squash-directory
squash_dir() {
	mkdir -p -m 0755 "${DIR}"/{rr,rw} ||
		die "Failed to create ${DIR}/{rr,rw} dirs"
	mksquashfs ${dir} ${DIR}.tmp.squashfs -b ${block_size} -comp ${compressor} \
		${exclude+=-wildcards -regex -e} ${exclude} ||
		die "Failed to build ${dir}.squashfs img"
	${mount_dir-true} && squash_mount
}

for mod in aufs squashfs; do
	grep -q ${mod} /proc/filesystems || modprobe ${mod} >/dev/null 2>&1 ||
	case ${mod} in
		(aufs) warn "Failed to load ${mod} module"; mount_dir=false;;
		(s*fs) die  "Failed to load ${mod} module";;
	esac
done

IFS=":${IFS}"
for dir in ${*}; do
	dir="/${dir#/}"; DIR="/${rootdir#/}${dir}"
	if [ -e ${DIR}.squashfs ]; then
		if [ ${offset} != 0 ]; then
			rr=$(du -sk ${DIR}/rr | awk '{print $1}')
			rw=$(du -sk ${DIR}/rw | awk '{print $1}')
			if [ $((${rw} * 100 / ${rr})) -lt ${offset} ]; then
				info "Skiping ${dir}, or append -o option to force rebuilding"
			else
				begin "Rebuilding squashed ${dir}...\n"
				squash_dir
			fi
		else
			begin "Rebuilding squashed ${dir}...\n"
			squash_dir
		fi
	else
		begin "Building squashed ${dir}...\n"
		squash_dir
	fi
	end "${?}"
done

[ -x "${busybox}" ] && rm -f "${busybox}"

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
