#!/bin/bash
# $Id: mkinitramfs-ll/svc/sdr.bash,v 0.9.1 2012/06/20 15:16:35 -tclover Exp $
revision=0.9.1
usage() {
  cat <<-EOF
  usage: ${0##*/} [--update|--remove] [-r|--sqfsdir=<dir>] -d|--sqfsd=<dir>:<dir>

  -r, --sqfsdir <dir>       overide default value of squashed rootdir 'sqfsdir=/sqfsd'
  -d, --sqfsd <dir>         squash colon seperated list of dir without the leading '/'
  -f, --fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b, --bsize 131072        use [128k] 131072 bytes block size, which is the default
  -c, --comp 'xz -Xbjc x86' use xz compressor, with optional optimization arguments
  -e, --exclude :<dir>      collon separated list of directories to exlude from image
  -o, --offset 0            overide default [10%] offset used to rebuild squashed dir
  -U, --update              update the underlying source directory e.g. bin:sbin:lib32
  -R, --remove              remove the underlying source directory e.g. usr:\${PORTDIR}
  -n, --nomount             do not remount squashed dir nor aufs after rebuilding 
  -u, --usage               print this help/usage and exit
  -v, --version             print version string and exit
	
  usages: speed up your system with aufs+squahfs by squashing a few dirs: 
  ${0##*/} --remove -d var/db:var/cache/edb:\$PORTDIR
  squash system related directories and update the underlaying sources dir:
  ${0##*/} --update -d bin:sbin:lib32:lib64
EOF
exit $?
}
[[ $# = 0 ]] && usage
opt=$(getopt -o b:c:d:e:fo:r:nuvUR -l bsize:,comp:,exclude:,fstab,offset:,noremount \
	  -l sqfsdir:,sqfsd:,remove,update,usage,version -n sdr -- "$@" || usage)
eval set -- "$opt"
declare -A opts
while [[ $# > 0 ]]; do
	case $1 in
		-f|--fstab) opts[fstab]=y; shift;;
		-v|--version) echo "${0##*/}-${revision}"; exit;;
		-o|--offset) opts[offset]="${2}"; shift 2;;
		-e|--exclude) opts[exclude]+=":${2}"; shift 2;;
		-r|--sqfsdir) opts[sqfsdir]="${2}"; shift 2;;
		-d|--sqfsd) opts[sqfsd]+=":${2}"; shift 2;;
		-a|--arch) opts[arc]="${2}"; shift 2;;
		-c|--comp) opts[comp]="${2}"; shift 2;;
		-U|--update) opts[update]=y; shift;;
		-R|--remove) opts[remove]=y; shift;;
		-n|--nomount) opts[nomount]=y; shift;;
		--) shift; break;;
		-u|--usage|*) usage;;
	esac
done
info() 	{ echo -ne " \e[1;32m* \e[0m$@\n"; }
error() { echo -ne " \e[1;31m* \e[0m$@\n"; }
die()   { error "$@"; break; }
[[ -n "$(uname -m | grep 64)" ]] && opts[arc]=64 || opts[arc]=32
[[ -n "${opts[sqfsdir]}" ]] || opts[sqfsdir]=/sqfsd
[[ -n "${opts[bsize]}" ]] || opts[bsize]=131072
[[ -n "${opts[comp]}" ]] || opts[comp]=gzip
[[ -n "${opts[exclude]}" ]] && opts[exclude]="-wildcards -regex -e ${opts[exclude]//:/ }"
squashd() {
	mkdir -p "$bdir"/{ro,rw} || die "failed to create $bdir/{ro,rw} dirs"
	mksquashfs /$dir $bdir.tmp.sfs -b ${opts[bsize]} -comp ${opts[comp]} \
		${opts[exclude]} >/dev/null || die "failed to build $dir.sfs img"
	if [[ "$dir" = lib${opts[arc]} ]]; then # move rc-svcdir and cachedir if mounted
		if [[ -n "$(mount -ttmpfs | grep /$dir/splash/cache)" ]]; then
			mount --move /$dir/splash/cache /var/cache/splash &>/dev/null &&
				local mcdir=yes || die "failed to move cachedir"
		fi
		if [[ -n "$(mount -ttmpfs | grep /$dir/rc/init.d)" ]]; then
			mount --move /$dir/rc/init.d /var/lib/init.d &>/dev/null &&
				local mrc=yes || die "failed to move rc-svcdir"
		fi
	fi
	if [[ -n "$(mount -taufs | grep -w $dir)" ]]; then 
		umount -l /$dir &>/dev/null || die "$dir: failed to umount aufs branch"
	fi
	if [[ -n "$(mount -tsquashfs | grep $bdir/ro)" ]]; then 
		umount -l $bdir/ro &>/dev/null || die "$dir: failed to umount sfs img"
	fi
	rm -fr "$bdir"/rw/* || die "failed to clean up $bdir/rw"
	[[ -e $bdir.sfs ]] && rm -f $bdir.sfs 
	mv $bdir.tmp.sfs $bdir.sfs || die "failed to move $dir.tmp.sfs img"
	if [[ "${opts[fstab]}" = "y" ]]; then
		echo "$bdir.sfs $bdir/ro squashfs nodev,loop,ro 0 0" >>/etc/fstab ||
			die "$dir: failed to write squashfs line"
		echo "$dir /$dir aufs nodev,udba=reval,br:$bdir/rw:$bdir/ro 0 0" >>/etc/fstab ||
			die "$dir: failed to write aufs line"
	fi
	if [[ -z "${opts[nomount]}" ]]; then
		mount $bdir.sfs $bdir/ro -tsquashfs -onodev,loop,ro &>/dev/null &&
		{
		if [[ "$dir" = "bin" ]]; then local cp=$bdir/ro/cp mv=$bdir/ro/mv rm=$bdir/ro/rm
		else local cp=cp mv=mv rm=rm; fi
		if [[ -n "${opts[remove]}" ]]; then
			$rm -rf /$dir/* || die "$dir:failed to clean up"
		fi
		if [[ -n "${opts[update]}" ]]; then
			$cp -aru $bdir/ro /${dir}ro && $mv /$dir{,rm}
			$mv /$dir{ro,} && $rm -fr /${dir}rm || die "$dir: failed to update"
		fi
		mount -onodev,udba=reval,br:$bdir/rw:$bdir/ro -taufs $dir /$dir &>/dev/null ||
			die "$dir: failed to mount aufs branch"
		} || die "failed to mount $dir.sfs"
	fi
	if [[ -n "$mcdir" ]]; then
		mount --move /var/cache/splash /$dir/splash/cache &>/dev/nul ||
			die "failed to move back cachedir"
	fi
	if [[ -n "$mrc" ]]; then
		mount --move /var/lib/init.d /$dir/rc/init.d &>/dev/null ||
			die "failed to move back rc-svcdir"
	fi
	echo -ne "\e[1;32m>>> ...sucessfully build squashed $dir\e[0m\n"
}
for dir in ${opts[sqfsd]//:/ }; do
	bdir="${opts[sqfsdir]}/$dir"
	if [[ -e /sqfsd/$dir.sfs ]]; then
		if [[ ${opts[offset]:-10} != 0 ]]; then
			ros=$(du -sk $bdir/ro | awk '{print $1}')
			rws=$(du -sk $bdir/rw | awk '{print $1}')
			if (( ($rws*100/$ros) < ${opts[offset]:-10} )); then
				info "$dir: skiping... there's an '-o' offset option to change the offset"
			else echo -ne "\e[1;32m>>> updating squashed $dir...\e[0m\n"; squashd; fi
		else echo -ne "\e[1;32m>>> updating squashed $dir...\e[0m\n"; squashd; fi
	else echo -ne "\e[1;32m>>> building squashed $dir...\e[0m\n"; squashd; fi			
done
unset bdir opt opts ros rws
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
