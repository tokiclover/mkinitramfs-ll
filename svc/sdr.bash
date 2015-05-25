#!/bin/bash
#
# $Header: mkinitramfs-ll/svc/sdr.bash                   Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.20.0 2015/05/24 12:33:03                   Exp $
#

shopt -qs extglob
typeset -A PKG
PKG=(
	[name]=sdr
	[shell]=bash
	[version]=0.20.0
)

# @FUNCTION: Print help message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options] <directory-ies>

  -q, --squash-root=<dir>   Set root directory (default '/aufs')
  -b, --block-size=131072   Set block size in bytes (default 128KB)
  -x, --busybox=busybox     Static BusyBox to use (System Wide case)
  -c, --compressor=gzip     Set compressor to use (default to lzo)
  -X, --exclude=:<dir>      Director-ies-y (list) to exlude from image
  -o, --offset=0            Offset to use when rebuilding (default 10%)
  -u, --update              Update the underlying source directory
  -r, --remove              Remove the underlying source directory
  -n, --no-remount          Disable mount after rebuild or update
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
	"-o" "?b:c:o:nhruq:X:x::"
	"-l" "block-size:,busybox::,compressor:,exclude:,offset,help"
	"-l" "no-remount,squash-root:,remove,update"
	"-n" "${PKG[name]}.${PKG[shell]}"
	"-s" "${PKG[shell]}"
)
opt=($(getopt "${opt[@]}" -- "$@" || usage))
eval set -- "${opt[@]}"

while true; do
	case $1 in
		(-b|--block-size)
			opts[-bsize]="$2"
			shift 2;;
		(-x|--busybox)
			opts[-busybox]="${2:-$commands[busybox]}"
			shift 2;;
		(-o|--offset)
			opts[-offset]="$2"
			shift 2;;
		(-X|--exclude) opts[-exclude]+=":$2"
			shift 2;;
		(-q|--squash-root)
			opts[-root]="$2"
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
		(-n|--no-remount)
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
	return $ret
}

# @VARIABLE: Kernel bit lenght
opts[-arc]=$(getconf LONG_BIT)
# @VARIABLE: Root directory (mount hierarchy)
[[ "${opts[-root]}" ]] || opts[-root]=/aufs
[[ "${opts[-bsize]}" ]] || opts[-bsize]=131072
# @VARIABLE: Full path to a static busysbox (required for system update)
[[ "${opts[-busybox]}" ]] || opts[-busybox]="$(type -p busybox)"
# @VARIABLE: Compression command
[[ "${opts[-comp]}" ]] || opts[-comp]="lzo -Xcompression-level 1"
# @VARIABLE: Colon separated list of excluded directory
[[ "${opts[-exclude]}" ]] && opts[-exclude]="-wildcards -regex -e ${opts[-exclude]//:/ }"
# @VARIABLE: rw/rr branch ration (percent)
[[ "${opts[-offset]}" ]] || opts[-offset]=10

# @FUNCTION: Helper to mount squashed directory
function squash-mount {
	if [[ "${dir}" == *(s)bin || "${dir}" == *lib*(32|64) ]]; then
		ldd ${opts[-busybox]} >/dev/null && die "no static busybox binary found"
		local busybox=/tmp/busybox
		cp ${opts[-busybox]} ${busybox} || die
		local cp="${busybox} cp -a"        mv="${busybox} mv"
		local rm="${busybox} rm -fr"    mount="${busybox} mount"
		local umount="${busybox} umount" grep="${busybox} grep"
		local mkdir="${busybox} mkdir -p"
	else
		local cp="cp -a" grep=grep mv=mv rm="rm -fr"
		local mount=mount umount=umount
		local mkdir="mkdir -p"
	fi

	if ${grep} -q aufs:${dir} /proc/mounts; then
		auplink ${dir} flush
		${umount} -l aufs:${dir} || die "failed to umount aufs:${dir}"
	fi
	if ${grep} -q ${DIR}/rr /proc/mounts; then
		${umount} -l ${DIR}/rr || die "failed to umount ${DIR}.squashfs"
	fi
	${rm} "${DIR}"/rw/* || die "failed to clean up ${DIR}/rw"

	[[ -e ${DIR}.squashfs ]] && [[ -e ${DIR}.tmp.squashfs ]] &&
	${rm} ${DIR}.squashfs
	${mv} ${DIR}.tmp.squashfs ${DIR}.squashfs ||
	die "failed to move ${dir}.tmp.squashfs"

	if ${mount} -t squashfs -o nodev,loop,ro ${DIR}.squashfs ${DIR}/rr; then
		if [[ "${opts[-remove]}" ]]; then
			${rm} ${dir} && $mkdir ${dir} || die "failed to clean up ${dir}"
		fi
		if [[ "${opts[-update]}" ]]; then
			${rm} ${dir} && $mkdir ${dir} && ${cp} ${DIR}/rr ${dir} ||
			die "failed to update ${dir}"
		fi
		${mount} -t aufs -o nodev,udba=reval,br:${DIR}/rw:${DIR}/rr aufs:${dir} ${dir} ||
		die "failed to mount aufs:${dir} branch"
	else
		die "failed to mount ${DIR}.squashfs"
	fi
}
# @FUNCTION: Helper to squash-directory
function squash-dir {
	mkdir -p -m 0755 "${DIR}"/{rr,rw} || die "failed to create ${DIR}/{rr,rw} dirs"
	mksquashfs ${dir} ${DIR}.tmp.squashfs -b ${opts[-bsize]} -comp ${opts[-comp]} \
		${opts[-exclude]} || die "failed to build ${dir}.squashfs img"
	[[ "${opts[-mount]}" ]] || squash-mount
	echo ">>> ${0##*/}: ...sucessfully build squashed"
}

for mod in aufs squashfs; do
	grep -q ${mod} /proc/filesystems || modprobe ${mod} >/dev/null 2>&1 ||
	case ${mod} in
		(aufs) warn "Failed to load ${mod} module"; opts[-mount]=false;;
		(s*fs) die  "Failed to load ${mod} module";;
	esac
done

IFS=":$IFS"
for dir in $*; do
	dir="/${dir#/}"; DIR="/${opts[-root]#/}${dir}"
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

[[ -f "$busybox" ]] && rm -f "$busybox"
unset DIR dir opt opts rr rw

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
