#!/bin/zsh
# $Id: mkinitramfs-ll/svc/sdr.zsh,v 0.12.0 2014/07/07 11:59:45 -tclover Exp $
basename=${(%):-%1x}

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
  $basename-0.12.8
  
  usage: $basename [-update|-remove] [-r|-sqfsdir<dir>] -d|-sqfsd:<dir>:<dir>

  -q, -sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d, -sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f, -fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b, -bsize 131072        use [128k] 131072 bytes block size, which is the default
  -x, -busybox busybox     path to a static busybox binary, default is \$(which bb)
  -c, -comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
  -e, -exclude :<dir>      collon separated list of directories to exlude from image
  -o, -offset 0            overide default [10%] offset used to rebuild squashed dir
  -u, -update              update the underlying source directory e.g. bin:sbin:lib32
  -r, -remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n, -nomount             do not remount squashed dir nor aufs after rebuilding 
  -h, -help                print this help/usage and exit

 usage: AUFS+squahfs or *squash* and remove underlying src directories:
 $basename -r -d/var/db:/var/cache/edb:\$PORTDIR:/var/lib/layman
 usage: squash system related directories and update the underlaying src dir:
 $basename -u -d/bin:/sbin:/lib32:/lib64:/usr
EOF
exit $?
}

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable

if [[ $# == 0 ]] || [[ -n ${(k)opts[-h]} ]] || [[ -n ${(k)opts[-help]} ]] { usage }
zmodload zsh/zutil
zparseopts -E -D -K -A opts q: sqfsdir: d: sqfsd: f fstab b: bsize: \
	n nomount x:: busybox:: c: comp: e: excl: o: offset: u update r remove \
	h help v version || usage

# @VARIABLE: opts[-arc]
# @DESCRIPTION: architecture of the system [ 32 | 64]
if [[ -n $(uname -m | grep 64) ]] { opts[-arc]=64 } else { opts[-arc]=32 }
# @VARIABLE: opts[-sqfsdir] | opts[-r]
# @DESCRIPTION: root of squashed dir
:	${opts[-sqfsdir]:=${opts[-r]:-/sqfsd}}
# @VARIABLE: opts[-offset] | opts[-o]
# @DESCRIPTION: offset or rw/rr or ro branch ratio
:	${opts[-offset]:=$opts[-o]}
# @VARIABLE: opts[-exclude] | opts[-e]
# @DESCRIPTION: colon separated list of excluded dir
:	${opts[-exclude]:=$opts[-e]}
# @VARIABLE: opts[-bsize] | opts[-b]
# @DESCRIPTION: Block SIZE of squashfs underlying filesystem block
:	${opts[-bsize]:=${opts[-b]:-131072}}
# @VARIABLE: opts[-comp] | opts[-c]
# @DESCRIPTION: COMPression command with optional option
:	${opts[-comp]:=${opts[-c]:-gzip}}
# @VARIABLE: opts[-busybox] | opts[-b]
# @DESCRIPTION: full path to a static busysbox binary needed for updtating 
# system wide dir
:	${opts[-busybox]:=${opts[-x]:-$(which bb)}}

# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
info() { print -P " %B%F{green}*%b%f $@" }
# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { print -P " %B%F{red}*%b%f $@" }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die() {
	local ret=$?
	error $@
	return $ret
}
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

setopt NULL_GLOB

# @FUNCTION: mnt
# @DESCRIPTION: mount squashed dir
mnt() {
	if [[ $d == /*bin ]] || [[ $d == /lib* ]] {
		local busybox=/tmp/busybox cp grep mount mv rm mcdir mrc mkdir
		cp ${opts[-busybox]} /tmp/busybox ||
			die "no static busybox binary found"
		cp="$busybox cp -ar"
		mv="$busybox mv"
		rm="$busybox rm -fr"
		mount="$busybox mount"
		umount="$busybox umount"
		grep="$busybox grep"
		mkdir="$busybox mkdir"
	} else {
		cp="cp -ar"
		grep=grep; mount=mount
		umount=umount; mv=mv
		rm="rm -fr"
		mkdir=mkdir
	}
	if ${=grep} -w aufs:$d /proc/mounts 1>/dev/null 2>&1; then
		${=umount} -l $d || die "$sdr: failed to umount aufs:$d"
	fi
	if ${=grep} $b/rr /proc/mounts 1>/dev/null 2>&1; then
		${=umount} -l $b/rr || die "sdr: failed to umount $b.sfs" 
	fi
	${=rm} $b/rw/* || die "sdr: failed to clean up $b/rw"
	[[ -f $b.sfs ]] && ${=rm} $b.sfs 
	${=mv} $b.tmp.sfs $b.sfs || die "sdr: failed to move $b.tmp.sfs"
	${=mount} $b.sfs $b/rr -t squashfs -o nodev,loop,ro &&
	{	
		if [[ -n ${(k)opts[-r]} ]] || [[ -n ${(k)opts[-remove]} ]] { 
			${=rm} $d && ${=mkdir} $d || die "sdr: failed to clean up $d"
		} 
		if [[ -n ${(k)opts[-r]} ]] || [[ -n ${(k)opts[-update]} ]] { 
			${=rm} $d && ${=mkdir} $d && ${=cp} $b/rr /$d ||
			die "sdr: failed to update $d"
		}
	${=mount} -t aufs -o nodev,udba=reval,br:$b/rw:$b/rr aufs:$d $d ||
	die "sdr: failed to mount aufs:$d"
	} || die "sdr: failed to mount $b.sfs"
}

# @FUNCTION: squashd
# @DESCRIPTION: squash dir
squashd() {
	if [[ -n ${(k)opts[-f]} || -n ${(k)opts[-fstab]} ]] {
		echo "$b.sfs $b/rr squashfs nodev,loop,rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write squasshfs fstab line"
		echo "$d $d aufs nodev,udba=reval,br:$b/rw:$b/rr 0 0" >>/etc/fstab ||
			die "sdr: failed to write aufs fstab line" 
	}
	mkdir -p -m 0755 $b/{rr,rw} || die "sdr: failed to create $d/{rr,rw}"
	mksquashfs $d $b.tmp.sfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-wildcards -regex -e ${(pws,:,)opts[-exclude]}} ||
		die "sdr: failed to build $d.sfs"
	if [[ $d == /lib${opts[-arc]} ]] {
		# move rc-svcdir cachedir if mounted
		mkdir -p /var/{lib/init.d,cache/splash}
		if grep $d/splash/cache /proc/mounts 1>/dev/null 2>&1; then
			mount --move $d/splash/cache /var/cache/splash &&
				mcdir=yes || die "sdr: failed to move cachedir"
		fi
		if grep $d/rc/init.d /proc/mounts 1>/dev/null 2>&1; then
			mount --move $d/rc/init.d /var/lib/init.d &&
				mrc=yes || die "sdr: failed to move rc-svcdir"
		fi
	}
	if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-nomount]} ]] { :;
	} else { mnt }
	if [[ -n $mcdir ]] { 
		mount --move /var/cache/splash $d/splash/cache ||
			die "sdr: failed to move back cachedir"
	}
	if [[ -n $mrc ]] { 
		mount --move /var/lib/init.d $d/rc/init.d ||
			die "sdr: failed to move back rc-svcdir"
	}
	info ">>> sdr:...squashed $d sucessfully [re]build"
}

for d (${(pws,:,)opts[-sqfsd]} ${(pws,:,)opts[-d]}) {
	b=${opts[-sqfsdir]}/$d
	if [[ -e ${opts[-sqfsdir]}/$d.sfs ]] { 
		if [[ ${opts[-offset]:-10} != 0 ]] {
			r=${$(du -sk $b/rr)[1]}
			w=${$(du -sk $b/rw)[1]}
			if (( ($w*100/$r) < ${opts[-offset]:-10} )) { 
				info "sdr: skiping... $d, or append -o|-offset option"
			} else {
				info ">>> sdr: updating squashed $d..."
				squashd
			}
		} else {
			info ">>> sdr: updating squashed $d..."
			squashd
		}
	} else {
		info ">>> sdr: building squashed $d..."
		squashd
	}
}

[[ -f $busybox ]] && rm -f $busybox
unset bdir opts rr rw

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
