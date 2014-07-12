#!/bin/bash
# $Id: mkinitramfs-ll/svc/sdr.bash,v 0.12.8 2014/07/07 10:59:42 -tclover Exp $
basename=${0##*/}

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
  $basename-0.12.8
  
  usage: $basename [{-u|--update}|{-r|--remove}] [-q|--sqfsdir=<dir>] -d|--sqfsd=<dir>:<dir>

  -q, --sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d, --sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f, --fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b, --bsize 131072        use [128k] 131072 bytes block size, which is the default
  -x, --busybox busybox     path to a static busybox binary, default is \$(which bb)
  -c, --comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
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
opt=$(getopt -o x::b:c:d:e:fo:r:nhvuq -l bsize:,comp:,exclude:,fstab,offset \
	  -l noremount,busybox::,sqfsdir:,sqfsd:,remove,update,help,version \
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
		-q|--sqfsdir) opts[-sqfsdir]="${2}"; shift 2;;
		-d|--sqfsd) opts[-sqfsd]+=":${2}"; shift 2;;
		-a|--arch) opts[-arc]="${2}"; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-u|--update) opts[-update]=y; shift;;
		-R|--remove) opts[-remove]=y; shift;;
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
# @DESCRIPTION: architecture of the system [ 32 | 64]
[[ -n "$(uname -m | grep 64)" ]] && opts[-arc]=64 || opts[-arc]=32
# @VARIABLE: opts[-sqfsdir] | opts[-r]
# @DESCRIPTION: root of squashed dir
[[ -n "${opts[-sqfsdir]}" ]] || opts[-sqfsdir]=/sqfsd
# @VARIABLE: opts[-bsize]
# @DESCRIPTION: Block SIZE of squashfs underlying filesystem block
[[ -n "${opts[-bsize]}" ]] || opts[-bsize]=131072
# @VARIABLE: opts[-busybox]
# @DESCRIPTION: full path to a static busysbox binary needed for updtating 
# system wide dir
[[ -n "${opts[-busybox]}" ]] || opts[-busybox]="$(which bb)"
# @VARIABLE: opts[-comp]
# @DESCRIPTION: COMPression command with optional option
[[ -n "${opts[-comp]}" ]] || opts[-comp]=gzip
# @VARIABLE: opts[-exclude]
# @DESCRIPTION: colon separated list of excluded dir
[[ -n "${opts[-exclude]}" ]] && opts[-exclude]="-wildcards -regex -e ${opts[-exclude]//:/ }"
# @VARIABLE: opts[-offset] | opts[-o]
# @DESCRIPTION: offset or rw/rr or ro branch ratio

# @FUNCTION: mnt
# @DESCRIPTION: mount squashed dir
mnt() {
	if [[ "$d" == /*bin ]] || [[ "$d" == /lib* ]]; then
		local busybox=/tmp/busybox cp grep mount mv rm mcdir mrc
		cp ${opts[-busybox]} $busybox || die "no static busybox binary found"
		cp="$busybox cp -ar"
		mv="$busybox mv"
		rm="$busybox rm -fr"
		mount="$busybox mount"
		umount="$busybox umount"
		grep="$busybox grep"
		mkdir="$busybox mkdir"
	else
		cp="cp -ar"
		grep=grep
		mount="mount"
		umount=umount mv=mv
		rm="rm -fr"
		mkdir=mkdir
	fi
	if [[ -n "$($grep -w aufs:$d /proc/mounts)" ]]; then 
		$umount -l $d || die "sdr: failed to umount aufs:$d"
	fi
	if [[ -n "$($grep $b/rr /proc/mounts)" ]]; then 
		$umount -l $b/rr || die "sdr: failed to umount $b.sfs"
	fi
	$rm "$b"/rw/* || die "sdr: failed to clean up $b/rw"
	[[ -e $b.sfs ]] && $rm $b.sfs 
	$mv $b.tmp.sfs $b.sfs || die "sdr: failed to move $d.tmp.sfs"
	$mount $b.sfs $b/rr -t squashfs -onodev,loop,ro &&
	{
		if [[ -n "${opts[-remove]}" ]]; then
			$rm $d && $mkdir $d || die "sdr: failed to clean up $d"
		fi
		if [[ -n "${opts[-update]}" ]]; then
			$rm $d && $mkdir $d && $cp $b/rr $d || die "sdr: failed to update $d"
		fi
		$mount -onodev,udba=reval,br:$b/rw:$b/rr -taufs aufs:$d $d ||
		die "sdr: failed to mount aufs:$d branch"
	} || die "sdr: failed to mount $b.sfs"
}

# @FUNCTION: squashd
# @DESCRIPTION: squash dir
squashd() {
	if [[ "${opts[-fstab]}" == "y" ]]; then
		echo "$b.sfs $b/rr squashfs nodev,loop,rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write squashfs line to fstab"
		echo "aufs:$d $d aufs nodev,udba=reval,br:$b/rw:$b/rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write aufs line to fstab"
	fi
	mkdir -p -m 0755 "$b"/{rr,rw} || die "sdr: failed to create $b/{rr,rw} dirs"
	mksquashfs $d $b.tmp.sfs -b ${opts[-bsize]} -comp ${opts[-comp]} \
		${opts[-exclude]} >/dev/null || die "sdr: failed to build $d.sfs img"
	if [[ "$d" == /lib${opts[-arc]} ]]; then
		# move rc-svcdir and cachedir if mounted
		if [[ -n "$(grep $d/splash/cache /proc/mounts)" ]]; then
			mount --move $d/splash/cache /var/cache/splash &&
				mcdir=yes || die "sdr: failed to move cachedir"
		fi
		if [[ -n "$(grep $d/rc/init.d /proc/mount)" ]]; then
			mount --move $d/rc/init.d /var/lib/init.d &&
				rc=yes || die "sdr: failed to move rc-svcdir"
		fi
	fi
	[[ -z "${opts[-nomount]}" ]] && mnt
	if [[ -n "$mcdir" ]]; then
		mount --move /var/cache/splash $d/splash/cache ||
			die "sdr: failed to move back cachedir"
	fi
	if [[ -n "$mrc" ]]; then
		mount --move /var/lib/init.d $d/rc/init.d ||
			die "sdr: failed to move back rc-svcdir"
	fi
	echo -ne "\e[1;32m>>> sdr: ...sucessfully build squashed $d\e[0m\n"
}

for d in ${opts[-sqfsd]//:/ }; do
	b="${opts[-sqfsdir]}/$d"
	if [[ -e $b.sfs ]]; then
		if [[ ${opts[-offset]:-10} != 0 ]]; then
			r=$(du -sk $b/rr | awk '{print $1}')
			w=$(du -sk $b/rw | awk '{print $1}')
			if (( ($w*100/$r) < ${opts[-offset]:-10} )); then
				info "sdr: skiping $d, or append -o|--offset option"
			else
				echo -ne "\e[1;32m>>> sdr: updating squashed $d...\e[0m\n"
				squashd
			fi
		else
			echo -ne "\e[1;32m>>> sdr: updating squashed $d...\e[0m\n"
			squashd
		fi
	else
		echo -ne "\e[1;32m>>> sdr: building squashed $d...\e[0m\n"
		squashd
	fi			
done

[[ -f $busybox ]] && rm -f $busybox
unset b d opt opts r w

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
