#!/bin/zsh
#
# $Header: mkinitramfs-ll/svc/sdr.bash                   Exp $
# $Author: (c) 2011-2015 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.18.0 2015/01/20 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name sdr
	shell zsh
	version 0.16.0
)

# @DESCRIPTION: print usages message
function usage {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]} version ${PKG[version]}
  usage: ${PKG[name]}.${PKG[shell]} [options] -d|--squashdir=:<dir>

  -q, --squash-root=<dir>   Set root directory (default '/aufs')
  -d, --squash-dir=:<dir>   Director-ies-y (list) to squash or update
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
typeset -A opts

declare -a opt
opt=(
	"-o" "?b:c:d:o:nhruq:X:x::"
	"-l" "block-size:,busybox::,compressor:,exclude:,offset,help"
	"-l" "no-remount,squash-root:,squash-dir:,remove,update"
	"-n" ${PKG[name]}.${PKG[shell]}
)
opt=($(getopt ${opt} -- ${argv} || usage))
eval set -- ${opt}
for (( ; $# > 0; ))
	case $1 {
		(-b|--block-size)
			opts[-bsize]=$2
			shift 2;;
		(-x|--busybox)
			opts[-busybox]=${2:-$commands[busybox]}
			shift 2;;
		(-o|--offset)
			opts[-offset]=$2
			shift 2;;
		(-X|--exclude) opts[-exclude]+=:$2
			shift 2;;
		(-q|--squashroot)
			opts[-root]=$2
			shift 2;;
		(-d|--squashdir)
			opts[-dir]+=:$2
			shift 2;;
		(-c|--compressor)
			opts[-comp]=$2
			shift 2;;
		(-u|--update)
			opts[-update]=
			shift;;
		(-r|--remove)
			opts[-remove]=
			shift;;
		(-n|--nomount)
			opts[-nomount]=
			shift;;
		(--)
			shift
			break;;
		(-h|--help|-?|*)
			usage;;
	}

# @DESCRIPTION: LONG_BIT, word length, supported
opts[-arc]=$(getconf LONG_BIT)
# @DESCRIPTION: root of squashed dir
:	${opts[-root]:=${opts[-r]:-/aufs}}
[[ ${opts[-root]#/} == ${opts[-root]} ]] && opts[-root]=/${opts[-root]}
# @DESCRIPTION: offset or rw/rr or ro branch ratio
:	${opts[-offset]:=10}
# @DESCRIPTION: Block SIZE of squashfs underlying filesystem block
:	${opts[-bsize]:=131072}
# @DESCRIPTION: COMPression command with optional option
:	${opts[-comp]:=lzo -Xcompression-level 1}
# @DESCRIPTION: full path to a static busysbox binary needed for updtating 
# system wide dir
:	${opts[-busybox]:=$commands[busyboxb]}

# @DESCRIPTION: print info message to stderr
function error {
    print -P " %B%F{red}*%b %1x: %F{yellow}%U%I%u%f: $@" >&2
}
# @DESCRIPTION: print info message to stdout
function info {
    print -P " %B%F{green}*%b%f %1x: $@"
}
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error $@
	return $ret
}

setopt EXTENDED_GLOB NULL_GLOB

# @DESCRIPTION: mount squashed dir
function squash-mount {
	if [[ ${dir} == /(|s)bin || ${dir} == /lib(32|64) ]] {
		ldd ${opts[-busybox]} >/dev/null && die "no static busybox binary found"
		local busybox=/tmp/busybox
		cp ${opts[-busybox]} /tmp/busybox || die 
		local cp="${busybox} cp -a"        mv="${busybox} mv"
		local rm="${busybox} rm -fr"     grep="${busybox} grep"
        local mount="${busybox} mount" umount="${busybox} umount"
		local mkdir="${busybox} mkdir -p"
	} else {
		local cp="cp -a" mv=mv rm="rm -fr" grep=grep
		local mount=mount umount=umount   mkdir="mkdir -p"
	}

	if ${=grep} -q aufs:${dir} /proc/mounts; then
		auplink ${dir} flush
		${=umount} -l aufs:${dir} || die "$failed to umount aufs:${dir}"
	fi
	if ${=grep} -q ${base}/rr /proc/mounts; then
		${=umount} -l ${base}/rr || die "failed to umount ${base}.squashfs" 
	fi
	${=rm} ${base}/rw/* || die "failed to clean up ${base}/rw"

	[[ -e ${base}.squashfs ]] && [[ -e ${base}.tmp.squahfs ]] && ${=rm} ${base}.squashfs 
	${=mv} ${base}.tmp.squashfs ${base}.squashfs ||
	die "failed to move ${base}.tmp.squashfs"

	if ${=mount} -t squashfs -o nodev,loop,ro ${base}.squashfs ${base}/rr; then
		if (( ${+opts[-remove]} )) {
			${=rm} ${dir} && ${=mkdir} ${dir} ||
			die "failed to clean up ${dir}"
		} 
		if (( ${+opts[-update]} )) {
			${=rm} ${dir} && ${=mkdir} ${dir} && ${=cp} ${base}/rr /${dir} ||
			die "failed to update ${dir}"
		}
		${=mount} -t aufs -o nodev,udba=reval,br:${base}/rw:${base}/rr aufs:${dir} ${dir} ||
		die "failed to mount aufs:${dir}"
	else
	    die "failed to mount ${base}.squashfs"
	fi
}

# @DESCRIPTION: squash-dir
function squash-dir {
	mkdir -p -m 0755 ${base}/{rr,rw} || die "failed to create ${dir}/{rr,rw}"
	mksquashfs ${dir} ${base}.tmp.squashfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-wildcards -regex -e ${(pws,:,)opts[-exclude]}} ||
		die "failed to build ${dir}.squashfs"
	(( ${+opts[-mount]} )) || squash-mount
	print -P ">>> %1x:...squashed ${dir} sucessfully [re]build"
}

# Check wether aufs is filesystem is available
grep -q aufs /proc/filesystems ||
	if ! modprobe aufs >/dev/null 2>&1; then
		error "failed to initialize aufs kernel module, using nomount option"
		opts[-nomount]=1
	fi

# Check wether squashfs filesystem is available
grep -q squashfs /proc/filesystems ||
	modprobe squashfs >/dev/null 2>&1 ||
	die "failed to initialize squashfs kernel module, exiting"

for dir (${(pws,:,)opts[-dir]}) {
	base=${opts[-root]}${dir}
	dir=/${dir#/}

	if [[ -e ${base}.squashfs ]]; then
		if (( ${opts[-offset]} != 0 )); then
			rr=${$(du -sk ${base}/rr)[1]}
			rw=${$(du -sk ${base}/rw)[1]}
			if (( (${rw}*100/${rr}) < ${opts[-offset]} )); then
				info "skiping... ${dir}, or append -o|-offset option"
			else
				print -P ">>> %1x: updating squashed ${dir}..."
				squash-dir
			fi
		else
			print -P ">>> %1x: updating squashed ${dir}..."
			squash-dir
		fi
	else
		print -P ">>> %1x: building squashed ${dir}..."
		squash-dir
	fi
}

[[ -f $busybox ]] && rm -f $busybox
unset base dir opts rr rw

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
