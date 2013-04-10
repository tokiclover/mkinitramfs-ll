#!/bin/zsh
# $Id: mkinitramfs-ll/svc/sdr.zsh,v 0.12.0 2013/02/11 09:59:45 -tclover Exp $
revision=0.12.0

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
 usage: ${(%):-%1x} [-update|-remove] [-r|-sqfsdir<dir>] -d|-sqfsd:<dir>:<dir>

  -r|-sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d|-sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f|-fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b|-bsize 131072        use [128k] 131072 bytes block size, which is the default
  -B|-busybox busybox     path to a static busybox binary, default is \$(which bb)
  -c|-comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
  -e|-exclude :<dir>      collon separated list of directories to exlude from image
  -o|-offset 0            overide default [10%] offset used to rebuild squashed dir
  -U|-update              update the underlying source directory e.g. bin:sbin:lib32
  -R|-remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n|-nomount             do not remount squashed dir nor aufs after rebuilding 
  -u|-usage               print this help/usage and exit
  -v|-version             print version string and exit
	
 usage: speed up your system with aufs+squahfs by squashing a few dirs:
 ${(%):-%1x} -remove -d var/db:var/cache/edb:\$PORTDIR
 usage: squash system related directories and update the underlaying sources dir:
 ${(%):-%1x} -update -d bin:sbin:lib32:lib64
EOF
exit $?
}

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable

if [[ $# = 0 ]] { usage
} else {
	zmodload zsh/zutil
	zparseopts -E -D -K -A opts r: sqfsdir: d: sqfsd: f fstab B:: b: bsize: \
		n nomount busybox:: c: comp: e: excl: o: offset: U update R remove \
		u usage v version || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] {
		usage
	}
	if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
		print "${(%):-%1x}-$revision"
		exit
	}
}

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
:	${opts[-busybox]:=${opts[-B]:-$(which bb)}}

# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
info() 	{ print -P " %B%F{green}*%b%f $@" }
# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
error() { print -P " %B%F{red}*%b%f $@" }
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
die()   {
	error $@
	return
}
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

setopt NULL_GLOB

# @FUNCTION: mnt
# @DESCRIPTION: mount squashed dir
mnt() {
	if [[ $dir = *bin ]] || [[ $dir = lib* ]] {
		local busybox=/tmp/busybox cp grep mount mv rm mcdir mrc
		cp ${opts[-busybox]} /tmp/busybox ||
			die "no static busybox binary found"
		cp="$busybox cp -ar"
		mv="$busybox mv"
		rm="$busybox rm -fr"
		mount="$busybox mount"
		umount="$busybox umount"
		grep="$busybox grep"
	} else {
		cp="cp -ar"
		grep=grep; mount=mount
		umount=umount; mv=mv
		rm="rm -fr"
	}
	if [[ -n $(${=mount} -t aufs | ${=grep} -w $dir) ]] {
		${=umount} -l /$dir 1>/dev/null 2>&1 ||
			die "$dir: failed to umount aufs branch"
	}
	if [[ -n $(${=mount} -t squashfs | ${=grep} $bdir/rr) ]] {
		${=umount} -l $bdir/rr 1>/dev/null 2>&1 ||
			die "failed to umount $bdir.sfs" 
	}
	${=rm} $bdir/rw/* || die "failed to clean up $bdir/rw"
	[[ -f $bdir.sfs ]] && ${=rm} $bdir.sfs 
	${=mv} $bdir.tmp.sfs $bdir.sfs || die "failed to move $dir.tmp.sfs"
	${=mount} $bdir.sfs $bdir/rr -t squashfs -o nodev,loop,ro 1>/dev/null 2>&1 &&
	{	
		if [[ -n ${(k)opts[-R]} ]] || [[ -n ${(k)opts[-remove]} ]] { 
			${=rm} /$dir/* || die "failed to clean up $bdir"
		} 
		if [[ -n ${(k)opts[-U]} ]] || [[ -n ${(k)opts[-update]} ]] { 
			${=rm} /$dir && ${=cp} $bdir/rr /$dir || die "$dir: failed to update"
		}
	${=mount} -t aufs -o nodev,udba=reval,br:$bdir/rw:$bdir/rr $dir /$dir \
		1>/dev/null 2>&1 || die "$dir: failed to mount aufs branch"
	} || die "failed to mount $dir.sfs"
}

# @FUNCTION: squashd
# @DESCRIPTION: squash dir
squashd() {
	if [[ -n ${(k)opts[-fstab]} || -n ${(k)opts[-fstab]} ]] {
		echo "$bdir.sfs $bdir/rr squashfs nodev,loop,rr 0 0" >>/etc/fstab ||
			die "$dir: failed to write squasshfs line"
		echo "$dir /$dir aufs nodev,udba=reval,br:$bdir/rw:$bdir/rr 0 0" >>/etc/fstab ||
			die "$dir: failed to write aufs line" 
	}
	mkdir -p -m 0755 $bdir/{rr,rw} || die "failed to create $dir/{rr,rw} dirs"
	mksquashfs /$dir $bdir.tmp.sfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-wildcards -regex -e ${(pws,:,)opts[-exclude]}} \
			>/dev/null || die "failed to build $dir.sfs img"
	if [[ $dir = lib${opts[-arc]} ]] { # move rc-svcdir cachedir if mounted
		mkdir -p /var/{lib/init.d,cache/splash}
		if [[ -n $(mount -ttmpfs | grep /$dir/splash/cache) ]] { 
			mount --move /$dir/splash/cache /var/cache/splash 1>/dev/null 2>&1 &&
				mcdir=yes || die "failed to move cachedir"
		}
		if [[ -n $(mount -ttmpfs | grep /$dir/rc/init.d) ]] { 
			mount --move /$dir/rc/init.d /var/lib/init.d 1>/dev/null 2>&1 &&
				mrc=yes || die "failed to move rc-svcdir"
		}
	}
	if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-nomount]} ]] { :;
	} else { mnt }
	if [[ -n $mcdir ]] { 
		mount --move /var/cache/splash /$dir/splash/cache 1>/dev/nul 2>&1 ||
			die "failed to move back cachedir"
	}
	if [[ -n $mrc ]] { 
		mount --move /var/lib/init.d /$dir/rc/init.d 1>/dev/null 2>&1 ||
			die "failed to move back rc-svcdir"
	}
	print -P "%F{green}>>> ...squashed $dir sucessfully [re]build%f"
}

for dir (${(pws,:,)opts[-sqfsd]} ${(pws,:,)opts[-d]}) {
	bdir=${opts[-sqfsdir]}/$dir
	if [[ -e /sqfsd/$dir.sfs ]] { 
		if [[ ${opts[-offset]:-10} != 0 ]] {
			rr=${$(du -sk $bdir/rr)[1]}
			rw=${$(du -sk $bdir/rw)[1]}
			if (( ($rw*100/$rr) < ${opts[-offset]:-10} )) { 
				info "$dir: skiping... there's \`-o' options to change the offset"
			} else {
				print -P "%F{green}>>> updating squashed $dir...%f"
				squashd
			}
		} else {
			print -P "%F{green}>>> updating squashed $dir...%f"
			squashd
		}
	} else {
		print -P "%F{green}>>> building squashed $dir...%f"
		squashd
	}
}

[[ -f $busybox ]] && rm -f $busybox
unset bdir opts rr rw

# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
