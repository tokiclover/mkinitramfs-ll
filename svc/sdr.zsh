#!/bin/zsh
#
# $Header: mkinitramfs-ll/svc/sdr.bash                   Exp $
# $Author: (c) 2011-2014 -tclover <tokiclover@gmail.com> Exp $
# $License: 2-clause/new/simplified BSD                  Exp $
# $Version: 0.13.6 2014/09/26 12:33:03                   Exp $
#

typeset -A PKG
PKG=(
	name sdr
	shell zsh
	version 0.13.6
)

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOH
  ${PKG[name]}.${PKG[shell]}-${PKG[version]}
  usage: ${PKG[name]}.${PKG[sehll]} [options] [-r|-squashroot<dir>] -d|-squashdir:<dir>:<dir>

  -q, --squash-root=<dir>   overide default value of squashed rootdir squash-root=/aufs
  -d, --squash-dir=<dir>    squashed directory-ies, colon seperated list of dir
  -b, --block-size=131072   use [128k] 131072 bytes block size, which is the default
  -x, --busybox=busybox     path to a static busybox binary, default is \$commands[busybox]
  -c, --compressor=gzip     use gzip compressor with compression option, default to lzo
  -X, --exclude=:<dir>      collon separated list of directories to exlude from image
  -o, --offset=0            overide default [10%] offset used to rebuild squashed dir
  -u, --update              update the underlying source directory e.g. bin:sbin:lib32
  -r, --remove              remove the underlying source directory e.g. usr:\$PORTDIR
  -n, --no-remount          do not remount squashed dir nor aufs after rebuilding
  -h, --help, -?            print this help/usage and exit

 usage: AUFS+squahfs or *squash* and remove underlying src directories:
 $PKG[name].$PKG[shell] -r -d/var/db:/var/cache/edb:\$PORTDIR:/var/lib/layman
 usage: squash system related directories and update the underlaying src dir:
 $PKG[name].$PKG[shell] -u -d/bin:/sbin:/lib32:/lib64:/usr
EOH
exit $?
}

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable

(( $# == 0 )) && usage
opt=$(getopt -o ?x::b:c:d:X:fo:nhruq: -l block-size:,compressor:,exclude: \
	-l fstab,offset,no-remount,busybox::,squash-root:,squash-dir:,remove \
	-l update,help,version -n ${PKG[name]}.${PKG[shell]} -- "$argv[@]" || usage)
eval set -- $opt

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
typeset -A opts

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
			opts[-squashroot]=$2
			shift 2;;
		(-d|--squashdir)
			opts[-squashdir]+=:$2
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

# @VARIABLE: opts[-arc]
# @DESCRIPTION: LONG_BIT, word length, supported
opts[-arc]=$(getconf LONG_BIT)
# @VARIABLE: opts[-root]
# @DESCRIPTION: root of squashed dir
:	${opts[-root]:=${opts[-r]:-/aufs}}
# @VARIABLE: opts[-offset]
# @DESCRIPTION: offset or rw/rr or ro branch ratio
:	${opts[-offset]:=10}
# @VARIABLE: opts[-bsize]
# @DESCRIPTION: Block SIZE of squashfs underlying filesystem block
:	${opts[-bsize]:=131072}
# @VARIABLE: opts[-comp]
# @DESCRIPTION: COMPression command with optional option
:	${opts[-comp]:=lzo -Xcompression-level 1}
# @VARIABLE: opts[-busybox]
# @DESCRIPTION: full path to a static busysbox binary needed for updtating 
# system wide dir
:	${opts[-busybox]:=$commands[busyboxb]}

# @FUNCTION: error
# @DESCRIPTION: print info message to stderr
function error {
    print -P " %B%F{red}*%b %1x: %F{yellow}%U%I%u%f: $@" >&2
}
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
function info {
    print -P " %B%F{green}*%b%f %1x: $@"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die {
	local ret=$?
	error $@
	return $ret
}

setopt EXTENDED_GLOB

# @FUNCTION: squash-mount
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
		${=umount} -l ${dir} || die "$sdr: failed to umount aufs:${dir}"
	fi
	if ${=grep} -q ${base}/rr /proc/mounts; then
		${=umount} -l ${base}/rr || die "sdr: failed to umount ${base}.squashfs" 
	fi

	${=rm} ${base}/rw/* || die "sdr: failed to clean up ${base}/rw"

	[[ -e ${base}.squashfs ]] && [[ -e ${base}.tmp.squahfs ]] && ${=rm} ${base}.squashfs 
	${=mv} ${base}.tmp.squashfs ${base}.squashfs ||
	die "sdr: failed to move ${base}.tmp.squashfs"

	if ${=mount} -t squashfs -o nodev,loop,ro ${base}.squashfs ${base}/rr; then
		if (( ${+opts[-remove]} )) {
			${=rm} ${dir} && ${=mkdir} ${dir} ||
			die "sdr: failed to clean up ${dir}"
		} 
		if (( ${+opts[-update]} )) {
			${=rm} ${dir} && ${=mkdir} ${dir} && ${=cp} ${base}/rr /${dir} ||
			die "sdr: failed to update ${dir}"
		}
		${=mount} -t aufs -o nodev,udba=reval,br:${base}/rw:${base}/rr aufs:${dir} ${dir} ||
		die "sdr: failed to mount aufs:${dir}"
	else
	    die "sdr: failed to mount ${base}.squashfs"
	fi
}

# @FUNCTION: squash-dir
# @DESCRIPTION: squash-dir
function squash-dir {
	mkdir -p -m 0755 ${base}/{rr,rw} || die "sdr: failed to create ${dir}/{rr,rw}"

	mksquashfs ${dir} ${base}.tmp.squashfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-wildcards -regex -e ${(pws,:,)opts[-exclude]}} ||
		die "sdr: failed to build ${dir}.squashfs"

	(( ${+opts[-mount]} )) || squash-mount

	print ">>> sdr:...squashed ${dir} sucessfully [re]build"
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
	base=${opts[-root]}/${dir}
	base=${base//\/\//\/}
	dir=/${dir}
	dir=${dir//\/\//\/}

	if [[ -e ${base}.squashfs ]]; then
		if (( ${opts[-offset]} != 0 )); then
			rr=${$(du -sk ${base}/rr)[1]}
			rw=${$(du -sk ${base}/rw)[1]}
			if (( (${rw}*100/${rr}) < ${opts[-offset]} )); then
				info "sdr: skiping... ${dir}, or append -o|-offset option"
			else
				print ">>> sdr: updating squashed ${dir}..."
				squash-dir
			fi
		else
			print ">>> sdr: updating squashed ${dir}..."
			squash-dir
		fi
	else
		print ">>> sdr: building squashed ${dir}..."
		squash-dir
	fi
}

[[ -f $busybox ]] && rm -f $busybox
unset base dir opts rr rw

#
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
#
