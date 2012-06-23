#!/bin/zsh
# $Id: mkinitramfs-ll/svc/sdr.zsh,v 0.9.1 2012/06/23 02:50:46 -tclover Exp $
revision=0.9.1
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-update|-remove] [-r|-sqfsdir<dir>] -d|-sqfsd:<dir>:<dir>

  -r|-sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d|-sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f|-fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b|-bsize 131072        use [128k] 131072 bytes block size, which is the default
  -c|-comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
  -e|-exclude :<dir>      collon separated list of directories to exlude from image
  -o|-offset 0            overide default [10%] offset used to rebuild squashed dir
  -U|-update              update the underlying source directory e.g. bin:sbin:lib32
  -R|-remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n|-nomount             do not remount squashed dir nor aufs after rebuilding 
  -u|-usage               print this help/usage and exit
  -v|-version             print version string and exit
	
  usages: speed up your system with aufs+squahfs by squashing a few dirs:
  ${(%):-%1x} -remove -d var/db:var/cache/edb:\$PORTDIR
  squash system related directories and update the underlaying sources dir:
  ${(%):-%1x} -update -d bin:sbin:lib32:lib64
EOF
exit $?
}
if [[ $# = 0 ]] { usage
} else { zmodload zsh/zutil
	zparseopts -E -D -K -A opts r: sqfsdir: d: sqfsd: f fstab b: bsize: n nomount \
		c: comp: e: excl: o: offset: U update R remove u usage v version || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
	if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
		print "${(%):-%1x}-$revision"; exit }
}
if [[ -n $(uname -m | grep 64) ]] { opts[-arc]=64 } else { opts[-arc]=32 }
:	${opts[-sqfsdir]:=${opts[-r]:-/sqfsd}}
:	${opts[-offset]:=$opts[-o]}
:	${opts[-exclude]:=$opts[-e]}
:	${opts[-bsize]:=${opts[-b]:-131072}}
:	${opts[-comp]:=${opts[-c]:-gzip}}
info() 	{ print -P " %B%F{green}*%b%f $@" }
error() { print -P " %B%F{red}*%b%f $@" }
die()   { error $@; return 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
setopt NULL_GLOB
squashd() {
	mkdir -p $bdir/{ro,rw} || die "failed to create $dir/{ro,rw} dirs"
	mksquashfs /$dir $bdir.tmp.sfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-wildcards -regex -e ${(pws,:,)opts[-exclude]}} >/dev/null \
		|| die "failed to build $dir.sfs img"
	if [[ $dir = lib${opts[-arc]} ]] { # move rc-svcdir cachedir if mounted
		mkdir -p /var/{lib/init.d,cache/splash}
		if [[ -n $(mount -ttmpfs | grep /$dir/splash/cache) ]] { 
			mount --move /$dir/splash/cache /var/cache/splash &>/dev/null &&
				local mcdir=yes || die "failed to move cachedir"
		}
		if [[ -n $(mount -ttmpfs | grep /$dir/rc/init.d) ]] { 
			mount --move /$dir/rc/init.d /var/lib/init.d &>/dev/null &&
				local mrc=yes || die "failed to move rc-svcdir"
		}
	}
	if [[ -n $(mount -t aufs | grep -w $dir) ]] {
		umount -l /$dir &>/dev/null || die "$dir: failed to umount aufs branch"
	}
	if [[ -n $(mount -t squashfs | grep $bdir/ro) ]] {
		umount -l $bdir/ro &>/dev/null || die "failed to umount $bdir.sfs" 
	}
	rm -fr $bdir/rw/* || die "failed to clean up $bdir/rw"
	[[ -e $bdir.sfs ]] && rm -f $bdir.sfs 
	mv $bdir.tmp.sfs $bdir.sfs || die "failed to move $dir.tmp.sfs"
	if [[ -n ${(k)opts[-fstab]} || -n ${(k)opts[-fstab]} ]] {
		echo "$bdir.sfs $bdir/ro squashfs nodev,loop,ro 0 0" >>/etc/fstab ||
			die "$dir: failed to write squasshfs line"
		echo "$dir /$dir aufs nodev,udba=reval,br:$bdir/rw:$bdir/ro 0 0" >>/etc/fstab ||
			die "$dir: failed to write aufs line" 
	}
	if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-nomount]} ]] { :; } else {
		mount $bdir.sfs $bdir/ro -tsquashfs -onodev,loop,ro &>/dev/null &&
		{	
		if [[ "$dir" = "bin" ]] { local cp=$bdir/ro/cp mv=$bdir/ro/mv rm=$bdir/ro/rm
		} else { local cp=cp mv=mv rm=rm }
		if [[ -n ${(k)opts[-R]} ]] || [[ -n ${(k)opts[-remove]} ]] { 
			$rm -rf /$dir/* || die "failed to clean up $bdir"
		} 
		if [[ -n ${(k)opts[-U]} ]] || [[ -n ${(k)opts[-update]} ]] { 
			$cp -aru $bdir/ro /${dir}ro && mv /$dir{,rm}
			$mv /$dir{ro,} && $rm -fr /${dir}rm || die "failed to update $dir"
		}
		mount -onodev,udba=reval,br:$bdir/rw:$bdir/ro -taufs $dir /$dir &>/dev/null ||
			die "$dir: failed to mount aufs branch"
		} || die "failed to mount $dir.sfs"
	}
	if [[ -n $mcdir ]] { 
		mount --move /var/cache/splash /$dir/splash/cache &>/dev/nul ||
			die "failed to move back cachedir"
	}
	if [[ -n $mrc ]] { 
		mount --move /var/lib/init.d /$dir/rc/init.d &>/dev/null ||
			die "failed to move back rc-svcdir"
	}
	print -P "%F{green}>>> ...squashed $dir sucessfully [re]build%f"
}
for dir (${(pws,:,)opts[-sqfsd]} ${(pws,:,)opts[-d]}) {
	bdir=${opts[-sqfsdir]}/$dir
	if [[ -e /sqfsd/$dir.sfs ]] { 
		if [[ ${opts[-offset]:-10} != 0 ]] {
			ros=${$(du -sk $bdir/ro)[1]}
			rws=${$(du -sk $bdir/rw)[1]}
			if (( ($rws*100/$ros) < ${opts[-offset]:-10} )) { 
				info "$dir: skiping... there's \`-o' options to change the offset"
			} else { print -P "%F{green}>>> updating squashed $dir...%f"; squashd }
		} else { print -P "%F{green}>>> updating squashed $dir...%f"; squashd }
	} else { print -P "%F{green}>>> building squashed $dir...%f"; squashd }
}
unset bdir opts ros rws
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
