#!/bin/bash
# $Id: mkinitramfs-ll/svc/sdr.bash,v 0.11.7 2013/02/11 09:59:42 -tclover Exp $
revision=0.11.7
usage() {
  cat <<-EOF
 usage: ${0##*/} [--update|--remove] [-r|--sqfsdir=<dir>] -d|--sqfsd=<dir>:<dir>

  -r, --sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d, --sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f, --fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b, --bsize 131072        use [128k] 131072 bytes block size, which is the default
  -B, --busybox busybox     path to a static busybox binary, default is \$(which bb)
  -c, --comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
  -e, --exclude :<dir>      collon separated list of directories to exlude from image
  -o, --offset 0            overide default [10%] offset used to rebuild squashed dir
  -U, --update              update the underlying source directory e.g. bin:sbin:lib32
  -R, --remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n, --nomount             do not remount squashed dir nor aufs after rebuilding 
  -u, --usage               print this help/usage and exit
  -v, --version             print version string and exit
	
 usage: speed up your system with aufs+squahfs by squashing a few dirs: 
 ${0##*/} --remove -d var/db:var/cache/edb:\$PORTDIR
 usage: squash system related directories and update the underlaying sources dir:
 ${0##*/} --update -d bin:sbin:lib32:lib64
EOF
exit $?
}
[[ $# = 0 ]] && usage
opt=$(getopt -o B::b:c:d:e:fo:r:nuvUR -l bsize:,comp:,exclude:,fstab,offset:,noremount \
	  -l busybox::,sqfsdir:,sqfsd:,remove,update,usage,version -n sdr -- "$@" || usage)
eval set -- "$opt"
declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-f|--fstab) opts[-fstab]=y; shift;;
		-v|--version) echo "${0##*/}-${revision}"; exit;;
		-B|--busybox) opts[-busybox]=${2:-$(which bb)}; shift 2;;
		-o|--offset) opts[-offset]="${2}"; shift 2;;
		-e|--exclude) opts[-exclude]+=":${2}"; shift 2;;
		-r|--sqfsdir) opts[-sqfsdir]="${2}"; shift 2;;
		-d|--sqfsd) opts[-sqfsd]+=":${2}"; shift 2;;
		-a|--arch) opts[-arc]="${2}"; shift 2;;
		-c|--comp) opts[-comp]="${2}"; shift 2;;
		-U|--update) opts[-update]=y; shift;;
		-R|--remove) opts[-remove]=y; shift;;
		-n|--nomount) opts[-nomount]=y; shift;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
info() 	{ echo -ne " \e[1;32m* \e[0m$@\n"; }
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; return; }
[[ -n "$(uname -m | grep 64)" ]] && opts[-arc]=64 || opts[-arc]=32
[[ -n "${opts[-sqfsdir]}" ]] || opts[-sqfsdir]=/sqfsd
[[ -n "${opts[-bsize]}" ]] || opts[-bsize]=131072
[[ -n "${opts[-busybox]}" ]] || opts[-busybox]="$(which bb)"
[[ -n "${opts[-comp]}" ]] || opts[-comp]=gzip
[[ -n "${opts[-exclude]}" ]] && opts[-exclude]="-wildcards -regex -e ${opts[-exclude]//:/ }"
mnt() {
	if [[ "$dir" = *bin ]] || [[ "$dir" = lib* ]]; then
		local busybox=/tmp/busybox cp grep mount mv rm mcdir mrc
		cp ${opts[-busybox]} $busybox || die "no static busybox binary found"
		cp="$busybox cp -ar"; mv="$busybox mv"; rm="$busybox rm -fr"
		mount="$busybox mount"; umount="$busybox umount"; grep="$busybox grep"
	else cp="cp -ar"; grep=grep; mount="mount"; umount=umount mv=mv; rm="rm -fr"; fi
	if [[ -n "$($mount -t aufs | $grep -w $dir)" ]]; then 
		$umount -l /$dir 1>/dev/null 2>&1 || die "$dir: failed to umount aufs branch"
	fi
	if [[ -n "$($mount -t squashfs | $grep $bdir/rr)" ]]; then 
		$umount -l $bdir/rr 1>/dev/null 2>&1 || die "$dir: failed to umount sfs img"
	fi
	$rm "$bdir"/rw/* || die "failed to clean up $bdir/rw"
	[[ -e $bdir.sfs ]] && $rm $bdir.sfs 
	$mv $bdir.tmp.sfs $bdir.sfs || die "failed to move $dir.tmp.sfs img"
	$mount $bdir.sfs $bdir/rr -tsquashfs -onodev,loop,ro 1>/dev/null 2>&1 &&
	{
		if [[ -n "${opts[-remove]}" ]]; then
			$rm /$dir/* || die "$dir:failed to clean up"
		fi
		if [[ -n "${opts[-update]}" ]]; then
			$rm /$dir && $cp $bdir/rr /$dir || die "$dir: failed to update"
		fi
		$mount -onodev,udba=reval,br:$bdir/rw:$bdir/rr -taufs $dir /$dir \
			1>/dev/null 2>&1 || die "$dir: failed to mount aufs branch"
	} || die "failed to mount $dir.sfs"
}
squashd() {
	if [[ "${opts[-fstab]}" = "y" ]]; then
		echo "$bdir.sfs $bdir/rr squashfs nodev,loop,rr 0 0" >>/etc/fstab ||
			die "$dir: failed to write squashfs line"
		echo "$dir /$dir aufs nodev,udba=reval,br:$bdir/rw:$bdir/rr 0 0" >>/etc/fstab ||
			die "$dir: failed to write aufs line"
	fi
	mkdir -p -m 0755 "$bdir"/{rr,rw} || die "failed to create $bdir/{rr,rw} dirs"
	mksquashfs /$dir $bdir.tmp.sfs -b ${opts[-bsize]} -comp ${opts[-comp]} \
		${opts[-exclude]} >/dev/null || die "failed to build $dir.sfs img"
	if [[ "$dir" = lib${opts[-arc]} ]]; then # move rc-svcdir and cachedir if mounted
		if [[ -n "$(mount -ttmpfs | grep /$dir/splash/cache)" ]]; then
			mount --move /$dir/splash/cache /var/cache/splash 1>/dev/null 2>&1 &&
				mcdir=yes || die "failed to move cachedir"
		fi
		if [[ -n "$(mount -ttmpfs | grep /$dir/rc/init.d)" ]]; then
			mount --move /$dir/rc/init.d /var/lib/init.d 1>/dev/null 2>&1 &&
				rc=yes || die "failed to move rc-svcdir"
		fi
	fi
	[[ -z "${opts[-nomount]}" ]] && mnt
	if [[ -n "$mcdir" ]]; then
		mount --move /var/cache/splash /$dir/splash/cache &>/dev/nul ||
			die "failed to move back cachedir"
	fi
	if [[ -n "$mrc" ]]; then
		mount --move /var/lib/init.d /$dir/rc/init.d 1>/dev/null 2>&1 ||
			die "failed to move back rc-svcdir"
	fi
	echo -ne "\e[1;32m>>> ...sucessfully build squashed $dir\e[0m\n"
}
for dir in ${opts[-sqfsd]//:/ }; do
	bdir="${opts[-sqfsdir]}/$dir"
	if [[ -e /sqfsd/$dir.sfs ]]; then
		if [[ ${opts[-offset]:-10} != 0 ]]; then
			rr=$(du -sk $bdir/rr | awk '{print $1}')
			rw=$(du -sk $bdir/rw | awk '{print $1}')
			if (( ($rw*100/$rr) < ${opts[-offset]:-10} )); then
				info "$dir: skiping... there's an '-o' offset option to change the offset"
			else echo -ne "\e[1;32m>>> updating squashed $dir...\e[0m\n"; squashd; fi
		else echo -ne "\e[1;32m>>> updating squashed $dir...\e[0m\n"; squashd; fi
	else echo -ne "\e[1;32m>>> building squashed $dir...\e[0m\n"; squashd; fi			
done
[[ -f $busybox ]] && rm -f $busybox
unset bdir opt opts rr rw
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
