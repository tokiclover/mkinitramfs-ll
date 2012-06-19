#!/bin/zsh
# $Id: mkinitramfs-ll/svc/sdr.zsh,v 0.7.0 2012/06/19 13:37:54 -tclover Exp $
revision=0.7.0
usage() {
  cat <<-EOF
  usage: ${(%):-%1x} [-update|-remove] [-r|-sqfsdir<dir>] -d|-sqfsd:<dir>:<dir>

  -r|-sqfsdir <dir>        override default value 'sqfsdir=/sqfsd', if not changed
  -d|-sqfsd <dir>          colon seperated list of directory-ies without the leading '/'
  -f|-fstab                whether to write the necessary mount lines to '/etc/fstab'
  -b|-bsize 131072         use [128k] 131072 bytes block size, which is the default values
  -c|-comp 'xz -Xbjc x86'  use xz compressor, optionaly, one can append extra arguments...
  -e|-exclude <dir>        collon separated list of directories to exlude from .sfs image
  -o|-offset <int>         offset used for rebuilding squashed directories, default is 10%
  -U|-update               update the underlying source directory e.g. bin:sbin:lib32:lib64
  -R|-remove               remove the underlying source directory e.g. usr:opt:\${PORTDIR}
  -n|-nomount              do not remount .sfs file nor aufs after rebuilding/updating 
  -u|-usage                print this help/usage and exit
  -v|-version              print version string and exit
	
  usages:
  # squash directries which will speed up system and portage, and the underlying files 
  # system will take much less space especially if there are numerous small files.
  ${(%):-%1x} -remove -dvar/db:var/cache/edb
  # [re-]build system related squashed directories and update the sources directories
  ${(%):-%1x} -update -dbin:sbin:lib32:lib64
EOF
exit 0
}
if [[ $# = 0 ]] { usage
} else { zmodload zsh/zutil
	zparseopts -E -D -K -A opts r: sqfsdir: d: sqfsd: f fstab b: bsize: n nomount \
		c: comp: e: excl: o: offset: U update R remove u usage v version || usage
	if [[ $# != 0 ]] || [[ -n ${(k)opts[-u]} ]] || [[ -n ${(k)opts[-usage]} ]] { usage }
	if [[ -n ${(k)opts[-v]} ]] || [[ -n ${(k)opts[-version]} ]] {
		print "${(%):-%1x}-$revision"; exit 0 }
}
if [[ -n $(uname -m | grep 64) ]] { opts[-arch]=64 } else { opts[-arch]=32 }
:	${opts[-sqfsdir]:=${opts[-r]:-/sqfsd}}
:	${opts[-offset]:=$opts[-o]}
:	${opts[-arch]:=$opts[-a]}
:	${opts[-exclude]:=$opts[-e]}
:	${opts[-bsize]:=${opts[-b]:-131072}}
:	${opts[-comp]:=${opts[-c]:-gzip}}
info() 	{ print -P " %B%F{green}*%b%f $@" }
error() { print -P " %B%F{red}*%b%f $@" }
die()   { error $@; exit 1 }
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'
setopt NULL_GLOB
sqfsd()
{
	mkdir -p ${basedir}/{ro,rw} || die "failed to create ${dir}/{ro,rw} dirs"
	mksquashfs /${dir} ${basedir}.tmp.sfs -b ${opts[-bsize]} -comp ${=opts[-comp]} \
		${=opts[-exclude]:+-e ${(pws,:,)opts[-exclude]}} > /dev/null \
		|| die "failed to build ${dir}.sfs img"
	if [[ $dir == lib${opts[-arch]} ]] { # move rc-svcdir and cachedir if mounted
		mkdir -p /var/{lib/init.d,cache/splash}
		if [[ -n $(mount -ttmpfs | grep /${dir}/splash/cache) ]] { 
			mount -move /${dir}/splash/cache /var/cache/splash &> /dev/null \
			&& local mcachedir=yes || die "failed to move cachedir"
		}
		if [[ -n $(mount -ttmpfs | grep /${dir}/rc/init.d) ]] { 
			mount -move /${dir}/rc/init.d /var/lib/init.d &> /dev/null \
			&& local mrcsvcdir=yes || die "failed to move rc-svcdir"
		}
	}
	if [[ -n $(mount -t aufs | grep -w ${dir}) ]] {
		umount -l /${dir} &> /dev/null || die "failed to umount ${dir} aufs branch"
	}
	if [[ -n $(mount -t squashfs | grep ${basedir}/ro) ]] {
		umount -l ${basedir}/ro &>/dev/null || die "failed to umount sfs img" 
	}
	rm -fr ${basedir}/rw/* || die "failed to clean up ${basedir}/rw"
	[[ -e ${basedir}.sfs ]] && rm -f ${basedir}.sfs 
	mv ${basedir}.tmp.sfs ${basedir}.sfs || die "failed to move ${dir}.tmp.sfs img"
	if [[ -n ${(k)opts[-fstab]} || -n ${(k)opts[-fstab]} ]] {
		echo "${basedir}.sfs ${basedir}/ro squashfs nodev,loop,ro 0 0" \
			>> /etc/fstab || die "failed to write squasshfs line"
		echo "${dir} /${dir} aufs nodev,udba=reval,br:${basedir}/rw:${basedir}/ro 0 0" \
			>> /etc/fstab || die "failed to write aufs line" 
	}
	if [[ -n ${(k)opts[-n]} ]] || [[ -n ${(k)opts[-nomount]} ]] { continue } else {
		mount ${basedir}.sfs ${basedir}/ro -t squashfs \
		-o nodev,loop,ro &> /dev/null || die "failed to mount ${dir}.sfs img"
		if [[ "${dir}" == "bin" ]] { local cp=${opts[-sqfsdir]}/bin/ro/cp
			local mv=${opts[-sqfsdir]}/bin/ro/mv rm=${opts[-sqfsdir]}/bin/ro/rm
		} else { local cp=cp mv=mv rm=rm }
		if [[ -n ${(k)opts[-R]} ]] || [[ -n ${(k)opts[-remove]} ]] { 
			${rm} -rf /${dir}/* || die "failed to clean up ${basedir}"
		} 
		if [[ -n ${(k)opts[-U]} ]] || [[ -n ${(k)opts[-update]} ]] { 
			${cp} -aru ${basedir}/ro /${dir}ro
			${mv} /${dir}{ro,} && ${rm} -fr /${dir}rm || info "failed to update ${dir}"
		}
		mount -o nodev,udba=reval,br:${basedir}/rw:${basedir}/ro \
		-t aufs ${dir} /${dir} &> /dev/null || die "failed to mount ${dir} aufs branch"
	}
	if [[ -n ${mcachedir} ]] { 
		mount -move /var/cache/splash "/${dir}/splash/cache" &> /dev/nul \
			|| die "failed to move back cachedir"
	}
	if [[ -n ${mrcsvcdir} ]] { 
		mount -move /var/lib/init.d "/${dir}/rc/init.d" &> /dev/null \
			|| die "failed to move back rc-svcdir"
	}
	print -P "%F{green}>>> ...squashed ${dir} sucessfully [re]build%f"
}
for dir (${(pws,:,)opts[-sqfsd]} ${(pws,:,)opts[-d]}) {
	basedir=${opts[-sqfsdir]}/${dir}
	if [[ -e /sqfsd/${dir}.sfs ]] { 
		if [[ ${opts[-offset]:-10} != 0 ]] {
			ro_size=${$(du -sk ${basedir}/ro)[1]}
			rw_size=${$(du -sk ${basedir}/rw)[1]}
			if (( (${rw_size}*100/${ro_size}) <= ${opts[-offset]:-10} )) { 
				info "${dir}: skiping... there's \`-o' options to change the offset"
			} else { print -P "%F{green}>>> updating squashed ${dir}...%f"; sqfsd }
		} else { print -P "%F{green}>>> updating squashed ${dir}...%f"; sqfsd }
	} else { print -P "%F{green}>>> building squashed ${dir}...%f"; sqfsd }
}
unset basedir opts ro_size rw_size
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
