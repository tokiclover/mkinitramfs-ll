#!/bin/bash
# $Id: mkinitramfs-ll/sqfsd/sdr.bash,v 0.7.0 2012/05/25 12:34:58 -tclover Exp $
revision=0.7.0
usage() {
  cat <<-EOF
  usage: ${0##*/} [--update|--remove] [-r|--sqfsdir=<dir>] -d[|--sqfsd=]<dir>:<dir>
  -r|--sqfsdir <dir>       override default value 'sqfsdir=/sqfsd', if not changed
  -d|--sqfsd <dir>         colon seperated list of directory-ies without the leading '/'
  -f|--fstab               whether to write the necessary mount lines to '/etc/fstab'
  -b|--bsize 131072        use [128k] 131072 bytes block size, which is the default values
  -c|--comp 'xz -Xbjc x86' use xz compressor, optionaly, one can append extra arguments...
  -e|--exclude :<dir>      collon separated list of directories to exlude from .sfs image
  -o|--offset <int>        offset used for rebuilding squashed directories, default is 10%
  -U|--update              update the underlying source directory e.g. bin:sbin:lib32:lib64
  -R|--remove              remove the underlying source directory e.g. usr:opt:\${PORTDIR}
  -n|--nomount             do not remount .sfs file nor aufs after rebuilding/updating 
  -u|--usage               print this help/usage and exit
  -v|--version             print version string and exit
	
  # squash directries which will speed up system and portage, and the underlying files 
  # system will take much less space especially if there are numerous small files.
  usages: [speed up your system with aufs+squahfs!]
  ${0##*/} -rm -d var/db:var/cache/edb
  # [re-]build system related squashed directories and update the sources directories
  ${0##*/} -up -d bin:sbin:lib32:lib64
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
		-v|--version) echo "${0##*/}-${revision}";;
		-o|--offset) opts[offset]="${2}"; shift 2;;
		-e|--exclude) opts[exclude]+=":${2}"; shift 2;;
		-r|--sqfsdir) opts[sqfsdir]="${2}"; shift 2;;
		-d|--sqfsd) opts[sqfsd]+=":${2}"; shift 2;;
		-a|--arch) opts[arch]="${2}"; shift 2;;
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
die()   { error "$@"; exit 1; }
[[ -n "$(uname -m | grep 64)" ]] && opts[arch]=64 || opts[arch]=32
[[ -n "${opts[sqfsdir]}" ]] || opts[sqfsdir]=/sqfsd
[[ -n "${opts[bsize]}" ]] || opts[bsize]=131072
[[ -n "${opts[comp]}" ]] || opts[comp]=gzip
[[ -n "${opts[exclude]}" ]] && opts[exclude]="-wildcards -regex -e ${opts[exclude]//:/ }"
sqfsd() 
{
	mkdir -p "${basedir}"/{ro,rw} || die "failed to create ${dir}/{ro,rw} dirs"
	mksquashfs /${dir} ${basedir}.tmp.sfs -b ${opts[bsize]} -comp ${opts[comp]} \
		${opts[exclude]} >/dev/null || die "failed to build ${dir}.sfs img"
	if [[ "${dir}" == lib${opts[arch]} ]]; then # move rc-svcdir and cachedir if mounted
		if [[ -n "$(mount -ttmpfs | grep /${dir}/splash/cache)" ]]; then
			mount -move /${dir}/splash/cache /var/cache/splash &> /dev/null \
			&& local mcachedir=yes || die "failed to move cachedir"
		fi
		if [[ -n "$(mount -ttmpfs | grep /${dir}/rc/init.d)" ]]; then
			mount -move /${dir}/rc/init.d /var/lib/init.d &> /dev/null \
			&& local mrcsvcdir=yes || die "failed to move rc-svcdir"
		fi
	fi
	if [[ -n "$(mount -t aufs | grep -w ${dir})" ]]; then 
		umount -l /${dir} &>/dev/null || die "failed to umount ${dir} aufs branch"
	fi
	if [[ -n "$(mount -t squashfs | grep ${basedir}/ro)" ]]; then 
		umount -l ${basedir}/ro &>/dev/null || die "failed to umount sfs img"
	fi
	rm -fr "${basedir}"/rw/* || die "failed to clean up ${basedir}/rw"
	[[ -e ${basedir}.sfs ]] && rm -f ${basedir}.sfs 
	mv ${basedir}.tmp.sfs ${basedir}.sfs || die "failed to move ${dir}.tmp.sfs img"
	if [[ "${opts[fstab]}" == "y" ]]; then local lfs lfa
		echo "${basedir}.sfs ${basedir}/ro squashfs nodev,loop,ro 0 0" \
			>> /etc/fstab || die "failed to write squashfs line"
		echo "${dir} /${dir} aufs nodev,udba=reval,br:${basedir}/rw:${basedir}/ro 0 0" \
			>> /etc/fstab || die "failed to write aufs line"
	fi
	if [[ -z "${opts[nomount]}" ]]; then
		mount ${basedir}.sfs ${basedir}/ro -t squashfs \
		-o nodev,loop,ro &> /dev/null || die "failed to mount ${dir}.sfs img"
		if [[ "${dir}" == "bin" ]]; then local cp=${opts[sqfsdir]}/bin/ro/cp
			local mv=${opts[sqfsdir]}/bin/ro/mv rm=${opts[sqfsdir]}/bin/ro/rm
		else local cp=cp mv=mv rm=rm; fi
		if [[ -n "${opts[remove]}" ]]; then
			${rm} -rf /${dir}/* || die "failed to clean up ${basedir}"
		fi
		if [[ -n "${opts[update]}" ]]; then
			${cp} -aru ${basedir}/ro /${dir}ro
			${mv} /${dir}{ro,} && ${rm} -fr /${dir}rm || info "failed to update ${dir}"
		fi
		mount -o nodev,udba=reval,br:${basedir}/rw:${basedir}/ro \
		-t aufs ${dir} /${dir} &> /dev/null || die "failed to mount ${dir} aufs branch."
	fi
	if [[ -n "${mcachedir}" ]]; then
		mount -move /var/cache/splash "/${dir}/splash/cache" &> /dev/nul \
			|| die "failed to move back cachedir"
	fi
	if [[ -n "${mrcsvcdir}" ]]; then
		mount -move /var/lib/init.d "/${dir}/rc/init.d" &> /dev/null \
			|| die "failed to move back rc-svcdir"
	fi
	echo -ne "\e[1;32m>>> ...sucessfully build squashed ${dir}\e[0m\n"
}
for dir in ${opts[sqfsd]//:/ }; do
	basedir="${opts[sqfsdir]}/${dir}"
	if [[ -e /sqfsd/${dir}.sfs ]]; then
		if [[ ${opts[offset]:-10} != 0 ]]; then
			ro_size=$(du -sk ${basedir}/ro | awk '{print $1}')
			rw_size=$(du -sk ${basedir}/rw | awk '{print $1}')
			if (( ( ${rw_size}*100/${ro_size} ) < ${opts[offset]:-10} )); then
				info "${dir}: skiping... there's an '-o' offset option to change the offset"
			else echo -ne "\e[1;32m>>> updating squashed ${dir}...\e[0m\n"; sqfsd; fi
		else echo -ne "\e[1;32m>>> updating squashed ${dir}...\e[0m\n"; sqfsd; fi
	else echo -ne "\e[1;32m>>> building squashed ${dir}...\e[0m\n"; sqfsd; fi			
done
unset basedir opt opts ro_size rw_size
# vim:fenc=utf-8:ci:pi:sts=0:sw=4:ts=4:
