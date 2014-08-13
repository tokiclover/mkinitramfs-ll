#!/bin/bash
# $Id: mkinitramfs-ll/svc/sdr.bash,v 0.13.0 2014/08/08 13:59:42 -tclover Exp $
basename=${0##*/}

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
  $basename-0.13.0
  usage: $basename [{-u|--update}|{-r|--remove}] [-q|--squashroot=<dir>] -d|--squashdir=<dir>:<dir>

  -q, --squashroot <dir>    overide default value of squashed rootdir 'squashroot=/var/aufs'
  -d, --squashdir <dir>     squash colon seperated list of dir
  -f, --fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b, --bsize 131072        use [128k] 131072 bytes block size, which is the default
  -x, --busybox busybox     path to a static busybox binary, default is \$(which bb)
  -c, --comp 'gzip'         use gzip compressor with compression option, default to lzo
  -e, --exclude :<dir>      collon separated list of directories to exlude from image
  -o, --offset 0            overide default [10%] offset used to rebuild squashed dir
  -u, --update              update the underlying source directory e.g. bin:sbin:lib32
  -r, --remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n, --nomount             do not remount squashed dir nor aufs after rebuilding 
  -h, --help, -?            print this help/usage and exit

 usage: AUFS+squahfs or *squash* director-y-ies with removing underlying src dirs: 
 $basename -r -d/var/db:/var/cache/edb:\$PORTDIR:/var/lib/layman
 usage: squash system related directories and update the underlaying sources dirs:
 $basename -u -d/bin:/sbin:/lib32:/lib64:/usr
EOF
exit $?
}

[[ $# = 0 ]] && usage
opt=$(getopt -o x::b:c:d:e:fo:nhruq: -l bsize:,comp:,exclude:,fstab,offset \
	  -l noremount,busybox::,squashroot:,squashdir:,remove,update,help,version \
	  -n $basename -- "$@" || usage)
eval set -- "$opt"

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
declare -A opts

while [[ $# > 0 ]]; do
	case $1 in
		-f|--fstab) opts[-fstab]=y; shift;;
		-x|--busybox) opts[-busybox]=${2:-$(which bb)}; shift 2;;
		-o|--offset) opts[-offset]="${2}"; shift 2;;
		-e|--exclude) opts[-exclude]+=":${2}"; shift 2;;
		-q|--squashroot) opts[-squashroot]="${2}"; shift 2;;
		-d|--squashdir) opts[-squashdir]+=":${2}"; shift 2;;
		-a|--arch) opts[-arc]="${2}"; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-u|--update) opts[-update]=y; shift;;
		-r|--remove) opts[-remove]=y; shift;;
		-n|--nomount) opts[-nomount]=y; shift;;
		--) shift; break;;
		-h|--help|-?|*) usage;;
	esac
done

# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
info() {
	echo -ne " \e[1;32m* \e[0m$@\n"
}
# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() {
	echo -ne " \e[1;31m* \e[0m$@\n"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die() {
	local ret=$?
	error "$@"
	return $ret
}

# @VARIABLE: opts[-arc]
# @DESCRIPTION: LONG_BIT, word length, supported
opts[-arc]=$(getconf LONG_BIT)
# @VARIABLE: opts[-squashroot] | opts[-q]
# @DESCRIPTION: root of squashed dir
[[ "${opts[-squashroot]}" ]] || opts[-squashroot]=/aufs
# @VARIABLE: opts[-bsize]
# @DESCRIPTION: Block SIZE of squashfs underlying filesystem block
[[ "${opts[-bsize]}" ]] || opts[-bsize]=131072
# @VARIABLE: opts[-busybox]
# @DESCRIPTION: full path to a static busysbox binary needed for updtating 
# system wide dir
[[ "${opts[-busybox]}" ]] || opts[-busybox]="$(which bb)"
# @VARIABLE: opts[-comp]
# @DESCRIPTION: COMPression command with optional option
[[ "${opts[-comp]}" ]] || opts[-comp]="lzo -Xcompression-level 1"
# @VARIABLE: opts[-exclude]
# @DESCRIPTION: colon separated list of excluded dir
[[ "${opts[-exclude]}" ]] && opts[-exclude]="-wildcards -regex -e ${opts[-exclude]//:/ }"
# @VARIABLE: opts[-offset] | opts[-o]
# @DESCRIPTION: offset or rw/rr or ro branch ratio

# @FUNCTION: squashmount
# @DESCRIPTION: mount squashed dir
squashmount() {
	if [[ "${dir}" == /*bin ]] || [[ "${dir}" == /lib* ]]; then
		local busybox=/tmp/busybox cp grep mount mv rm mcdir mrc mkdir
		cp ${opts[-busybox]} $busybox || die "no static busybox binary found"
		cp="$busybox cp -ar"
		mv="$busybox mv"
		rm="$busybox rm -fr"
		mount="$busybox mount"
		umount="$busybox umount"
		grep="$busybox grep"
		mkdir="$busybox mkdir -p"
	else
		cp="cp -ar"; grep=grep
		mount="mount"; umount=umount
		mv=mv; rm="rm -fr"
		mkdir="mkdir -p"
	fi
	if $grep -q aufs:${dir} /proc/mounts; then
		$umount -l ${dir} || die "sdr: failed to umount aufs:${dir}"
	fi
	if $grep -q ${base}/rr /proc/mounts; then
		$umount -l ${base}/rr || die "sdr: failed to umount ${base}.squashfs"
	fi
	$rm "${base}"/rw/* || die "sdr: failed to clean up ${base}/rw"
	[[ -e ${base}.squashfs ]] && $rm ${base}.squashfs 
	$mv ${base}.tmp.squashfs ${base}.squashfs ||
	die "sdr: failed to move ${dir}.tmp.squashfs"
	$mount -t squashfs -onodev,loop,ro ${base}.squashfs ${base}/rr &&
	{
		if [[ -n "${opts[-remove]}" ]]; then
			$rm ${dir} && $mkdir ${dir} || die "sdr: failed to clean up ${dir}"
		fi
		if [[ -n "${opts[-update]}" ]]; then
			$rm ${dir} && $mkdir ${dir} && $cp ${base}/rr ${dir} ||
			die "sdr: failed to update ${dir}"
		fi
		$mount -onodev,udba=reval,br:${base}/rw:${base}/rr -taufs aufs:${dir} ${dir} ||
		die "sdr: failed to mount aufs:${dir} branch"
	} || die "sdr: failed to mount ${base}.squashfs"
}

# @FUNCTION: squashdir
# @DESCRIPTION: squash dir
squashdir() {
	local n=/dev/null
	if [[ "${opts[-fstab]}" == "y" ]]; then
		echo "${base}.squashfs ${base}/rr squashfs nodev,loop,rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write squashfs line to fstab"
		echo "aufs:${dir} ${dir} aufs nodev,udba=reval,br:${base}/rw:${base}/rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write aufs line to fstab"
	fi
	mkdir -p -m 0755 "${base}"/{rr,rw} || die "sdr: failed to create ${base}/{rr,rw} dirs"
	mksquashfs ${dir} ${base}.tmp.squashfs -b ${opts[-bsize]} -comp ${opts[-comp]} \
		${opts[-exclude]} || die "sdr: failed to build ${dir}.squashfs img"
	if [[ "${dir}" == /lib${opts[-arc]} ]]; then
		# move rc-svcdir and cachedir if mounted
		if grep ${dir}/splash/cache /proc/mounts 1>${n} 2>&1; then
			mount --move ${dir}/splash/cache /var/cache/splash &&
				mcdir=yes || die "sdr: failed to move cachedir"
		fi
		if grep ${dir}/rc/init.d /proc/mount 1>${n} 2>&1; then
			mount --move ${dir}/rc/init.d /var/lib/init.d &&
				rc=yes || die "sdr: failed to move rc-svcdir"
		fi
	fi
	[[ ${opts[-nomount]} ]] || squashmount
	if [[ -n "$mcdir" ]]; then
		mount --move /var/cache/splash ${dir}/splash/cache ||
			die "sdr: failed to move back cachedir"
	fi
	if [[ -n "$mrc" ]]; then
		mount --move /var/lib/init.d ${dir}/rc/init.d ||
			die "sdr: failed to move back rc-svcdir"
	fi
	info ">>> sdr: ...sucessfully build squashed"
}

# @FUNCTION: squash_init
# @DESCRIPTION: initialize aufs+squashfs if need be, or exit if no support found
squash_init() {
	local n=/dev/null

	grep -q aufs /proc/filesystems ||
	if ! grep -q aufs /proc/modules; then
	    if ! modprobe aufs >${n} 2>&1; then
	        error "failed to initialize aufs kernel module, exiting"
	        opts[-nomount]=1
	    fi
	fi

    grep -q squashfs /proc/filesystems ||
	if ! grep -q squashfs /proc/modules; then
	    if ! modprobe squashfs >${n} 2>&1; then
	        die "failed to initialize squashfs kernel module, exiting"
	    fi
	fi
}
squash_init

for dir in ${opts[-squashdir]//:/ }; do
	base="${opts[-squashroot]}/${dir}"
	base=${base//\/\//\/}
	if [[ -e ${base}.squashfs ]]; then
		if [[ ${opts[-offset]:-10} != 0 ]]; then
			rr=$(du -sk ${base}/rr | awk '{print $1}')
			rw=$(du -sk ${base}/rw | awk '{print $1}')
			if (( (${rw}*100/${rr}) < ${opts[-offset]:-10} )); then
				info "sdr: skiping ${dir}, or append -o|--offset option"
			else
				info ">>> sdr: updating squashed ${dir}..."
				squashdir
			fi
		else
			info ">>> sdr: updating squashed ${dir}..."
			squashdir
		fi
	else
		info ">>> sdr: building squashed ${dir}..."
		squashdir
	fi			
done

[[ -f $busybox ]] && rm -f $busybox
unset base dir opt opts rr rw

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
