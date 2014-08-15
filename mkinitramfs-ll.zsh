#!/bin/zsh
# $Id: mkinitramfs-ll/mkinitramfs-ll.zsh,v 0.13.1 2014/08/08 11:40:11 -tclover Exp $
basename=${(%):-%1x}

# @FUNCTION: usage
# @DESCRIPTION: print usages message
usage() {
  cat <<-EOF
  $basename-0.13.1
  usage: $basename [-a|-all] [-f|-font [font]] [-y|-keymap [keymap]] [options]

  -a, -all                 short hand or forme of '-f -g -l -L -q -t -y -M:zfs:zram'
  -f, -font[:ter-v14n]     include a colon separated list of fonts to the initramfs
  -k, -kv3.4.4-git         build an initramfs for kernel 3.4.4-git, or else \$(uname -r)
  -F, -firmware[:file]     append firmware file or directory (relative to /lib/firmware),
                           or else full path, or the whole /lib/firmware dir if empty
  -c, -comp['gzip -9']     use 'gzip -9' command instead default compression command
  -L, -luks                add LUKS support, require a sys-fs/cryptsetup[static] binary
  -l, -lvm                 add LVM support, require a static sys-fs/lvm2[static] binary
  -b, -bin:<bin>           include a colon separated list of binar-y-ies to the initramfs
  -d, -usrdir[usr]         use usr dir for user extra files, binaries, scripts, fonts...
  -g, -gpg                 add GnuPG support, require a static gnupg-1.4.x and 'options.skel'
  -p, -prefix[initrd-]     use 'initrd-' initramfs prefix instead of default ['initramfs-']
  -M, -module:<name>       include <name> module or script from modules directory
  -m, -kmod[:<mod>]        include a colon separated list of kernel modules to the initramfs
      -mtuxonice[:<mod>]   include a colon separated list of kernel modules to tuxonice group
      -mremdev[:<mod>]     include a colon separated list of kernel modules to remdev  group
      -msquashd[:<mod>]    include a colon separated list of kernel modules to squashd group
      -mgpg[:<mod>]        include a colon separated list of kernel modules to gpg     group
      -mboot[:<mod>]       include a colon separated list of kernel modules to boot   group
  -s, -splash[:<theme>]    include a colon separated list of splash themes to the initramfs
  -t, -toi                 add tuxonice support for splash, require tuxoniceui_text binary
  -q, -squashd             add AUFS+squashfs, {,u}mount.aufs, or squashed dir support
  -r, -regen               regenerate a new initramfs from an old dir with newer init
  -y, -keymap:fr-latin1    include a colon separated list of keymaps to the initramfs
  -K, -keeptmp             keep temporary files instead of removing the tmpdir
  -h, -help                print this help or usage message and exit

  usage: build an initramfs for kernel \$(uname -r) if run without an argument
  usgae: generate an initramfs with LUKS, GnuPG, LVM2 and AUFS+squashfs support
  $basename -a -k$(uname -r)
EOF
exit $?
}

# @FUNCTION: error
# @DESCRIPTION: print error message to stdout
function error()
{
    print -P " %B%F{red}*%b%f $@"
}
# @FUNCTION: info
# @DESCRIPTION: print info message to stdout
unction info()
{
    print -P " %B%F{green}*%b%f $@"
}
# @FUNCTION: warn
# @DESCRIPTION: print warning message to stdout
function warn()
{
	print -P " %B%F{red}*%b%f $@"
}
# @FUNCTION: die
# @DESCRIPTION: call error() to print error message before exiting
function die()
{
	local ret=$?
	error $@
	exit $ret
}
alias die='die "%F{yellow}%1x:%U${(%):-%I}%u:%f" $@'

# @FUNCTION: mktmp
# @DESCRIPTION: make tmp dir or file in ${TMPDIR:-/tmp}
# @ARG: -d|-f [-m <mode>] [-o <owner[:group]>] [-g <group>] TEMPLATE
function mktmp()
{
	local tmp=${TMPDIR:-/tmp}/$1-XXXXXX
	mkdir -p ${mode:+-m$mode} $tmp ||
	die "mktmp: failed to make $tmp"
	print "$tmp"
}

# @FUNCTION: adn
# @DESCRIPTION: ADd the essential Nodes to be able to boot
function adn()
{
	[[ -c dev/console ]] || mknod -m 600 dev/console c 5 1 || die
	[[ -c dev/urandom ]] || mknod -m 666 dev/urandom c 1 9 || die
	[[ -c dev/random ]]  || mknod -m 666 dev/random  c 1 8 || die
	[[ -c dev/mem ]]     || mknod -m 640 dev/mem     c 1 1 && chmod 0:9 || die
	[[ -c dev/null ]]    || mknod -m 666 dev/null    c 1 3 || die
	[[ -c dev/tty ]]     || mknod -m 666 dev/tty     c 5 0 || die
	[[ -c dev/zero ]]    || mknod -m 666 dev/zero    c 1 5 || die

	for nod ($(seq 0 6)) [[ -c dev/tty${n} ]] ||
		mknod -m 600 dev/tty${nod} c 4 ${n} || die
}

setopt EXTENDED_GLOB NULL_GLOB
zmodload zsh/zutil
zparseopts -E -D -K -A opts a all q squashd g gpg l lvm t toi c:: comp:: \
	k: kv: m+:: kmod+:: f+:: font+:: s:: splash:: h help M: module: \
	b:: bin:: p:: prefix:: y:: keymap:: d:: usrdir:: mboot+:: F:: firmware:: \
	mgpg+:: mremdev+:: msquashd+:: mtuxonice+:: L luks r regen K keetmp ||
	usage

if [[ -n ${(k)opts[-h]} ]] || [[ -n ${(k)opts[-help]} ]] { usage }

# @VARIABLE: opts [associative array]
# @DESCRIPTION: declare if not declared while arsing options,
# hold almost every single option/variable
if [[ $# < 1 ]] { typeset -A opts }

if [[ -f mkinitramfs-ll.conf ]] {
	source mkinitramfs-ll.conf 
} else {
	die "no mkinitramfs-ll.conf found"
}

# @VARIABLE: opts[-kv]
# @DESCRIPTION: kernel version to pick up
:	${opts[-kv]:=${opts[-k]:-$(uname -r)}}
# @VARIABLE: opts[-prefix]
# @DESCRIPTION: initramfs prefx name <$prefix-$kv.$ext>
:	${opts[-prefix]:=${opts[-p]:-initramfs-}}
# @VARIABLE: opts[-usrdir]
# @DESCRIPTION: usr dir path, to get extra files
:	${opts[-usrdir]:=${opts[-d]:-${PWD}/usr}}
# @VARIABLE: opts[-comp]
# @DESCRIPTION: compression command
:	${opts[-comp]:=${opts[-c]:-xz -9 --check=crc32}}
# @VARIABLE: opts[-initrmafs]
# @DESCRIPTION: full to initramfs compressed image
:	${opts[-initramfs]:=${opts[-prefix]}${opts[-kv]}}
# @VARIABLE: opts[-arch]
# @DESCRIPTION: kernel architecture
:	${opts[-arch]:=$(uname -m)}
# @VARIABLE: opts[-arc]
# @DESCRIPTION: kernel bit lenght supported
:	${opts[-arc]:=$(getconf LONG_BIT)}
# @VARIABLE: opts[-tmpdir]
# @DESCRIPTION: tmp dir where to generate initramfs
# an initramfs compressed image
:	${opts[-tmpdir]:=$(mktmp ${opts[-initramfs]:t})}

if [[ -n ${(k)opts[-a]} ]] || [[ -n ${(k)opts[-all]} ]] { 
	opts[-f]=; opts[-g]=; opts[-l]=; opts[-q]=; opts[-t]=; opts[-L]=; opts[-y]=;
	opts[-M]+=:zfs:zram;
}

if [[ -n ${(k)opts[-y]} ]] || [[ -n ${(k)opts[-keymap]} ]] {
	[[ -e /etc/conf.d/keymaps ]] &&
	opts[-y]+=:$(sed -nre 's,^keymap="([a-zA-Z].*)",\1,p' /etc/conf.d/keymaps)
}

if [[ -n ${(k)opts[-f]} ]] || [[ -n ${(k)opts[-font]} ]] {
	[[ -e /etc/conf.d/consolefont ]] &&
	opts[-f]+=:$(sed -nre 's,^consolefont="([a-zA-Z].*)",\1,p' /etc/conf.d/consolefont)
}

case ${opts[-comp][(w)1]} in
	bzip2)	opts[-initramfs]+=.cpio.bz2;;
	gzip) 	opts[-initramfs]+=.cpio.gz;;
	xz) 	opts[-initramfs]+=.cpio.xz;;
	lzma)	opts[-initramfs]+=.cpio.lzma;;
	lzip)	opts[-initramfs]+=.cpio.lz;;
	lzop)	opts[-initramfs]+=.cpio.lzo;;
	lz4)    opts[-initramfs]+=.cpio.lz4;;
esac

# @FUNCTION: docpio
# @DESCRIPTION: generate an initramfs image
function docpio()
{
	local initramfs=${1:-/boot/${opts[-initramfs]}}
	find . -print0 | cpio -0 -ov -Hnewc | ${=opts[-comp]} > ${initramfs}
}

if [[ -f /boot/${opts[-initramfs]} ]] {
	mv /boot/${opts[-initramfs]}{,.old}
}

print -P "%F{green}>>> building ${opts[-initramfs]}...%f"
pushd ${opts[-tmpdir]} || die "no ${opts[-tmpdir]} tmpdir found"

if [[ -n ${(k)opts[-regen]} ]] || [[ -n ${(k)opts[-r]} ]] {
	cp -af ${opts[-usrdir]}/lib/mkinitramfs-ll/functions lib/mkinitramfs-ll &&
	cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
	docpio /boot/${opts[-initramfs]} || die
	print -P "%F{green}>>> regenerated ${opts[-initramfs]}...%f" && exit
} else {
	rm -fr *
}

if [[ -d ${opts[-usrdir]} ]] {
	cp -ar ${opts[-usrdir]} . &&
	mv -f {usr/,}root &&
	mv -f {usr/,}etc &&
	mv -f usr/lib lib${opts[-arc]} || die
} else {
	die "${opts[-usrdir]} dir not found"
}
mkdir -p usr/{{,s}bin,share/{consolefonts,keymaps},lib${opts[-arc]}} || die
mkdir -p {,s}bin dev proc sys newroot mnt/tok etc/{mkinitramfs-ll,splash} || die
mkdir -p run lib${opts[-arc]}/{modules/${opts[-kv]},mkinitramfs-ll} || die
ln -sf lib{${opts[-arc]},} &&
	pushd usr && ln -sf lib{${opts[-arc]},} && popd || die

cp -a /dev/{console,random,urandom,mem,null,tty{,[0-6]},zero} dev/ || adn
if [[ ${${(pws:.:)opts[-kv]}[1]} -eq 3 ]] &&
	[[ ${${(pws:.:)opts[-kv]}[2]} -ge 1 ]] {
	cp -a {/,}dev/loop-control 1>/dev/null 2>&1 ||
		mknod -m 600 dev/loop-control c 10 237 || die
}

cp -af ${opts[-usrdir]}/../init . && chmod 775 init || die
[[ -d root ]] && chmod 0700 root || mkdir -m700 root || die

for bin (dmraid mdadm zfs)
	if [[ -n $(echo ${opts[-b]} | grep $bin) ]] ||
	[[ -n $(echo ${opts[-bin]} | grep $bin) ]] { opts[-mgrp]+=:$bin }
opts[-mgrp]=${opts[-mgrp]/mdadm/raid}

for mod (${(pws,:,)opts[-M]} ${(pws,:,)opts[-module]}) {
	cp -a ${opts[-usrdir]:h}/modules/*$mod* lib/mkinitramfs-ll/
	opts[-bin]+=:${opts[-b$mod]}
	opts[-mgrp]+=:$mod
}
cp -ar {/,}lib/modules/${opts[-kv]}/modules.dep ||
	die "failed to copy modules.dep"

[ -f /etc/issue.logo ] && cp {/,}etc/issue.logo

if [[ -n ${(k)opts[-F]} ]] || [[ -n ${(k)opts[-firmware]} ]] { 
:   ${opts[-firmware]:=${opts[-F]:-/lib/firmware}}
	mkdir -p lib/firmware
	for f (${(pws,:,)opts[-firmware]}) {
		if [[ -e $f ]] || [[ -d $f ]] {
			cp -a $f lib/firmware/ || warn "failed to copy $f firmware"
		} elif [[ -e /lib/firmware/$f ]] || [[ -d /lib/firmware/$f ]] {
			cp -a {/,}lib/firmware/$f || warn "failed to copy $f firmware"
		} else { warn "failed to copy $f firmware" }
	}
}

if [[ -x usr/bin/busybox ]] {
	mv -f {usr/,}bin/busybox
} elif [[ $(which busybox) != "busybox not found" ]] &&
	[[ $(ldd $(which busybox)) == *"not a dynamic executable" ]] {
	cp -a $(which busybox) bin/
} elif [[ $(which bb) != "bb not found" ]] {
	cp -a $(which bb) bin/busybox
} else { die "no suitable busybox/bb binary found" }

if [[ ! -f etc/mkinitramfs-ll/busybox.app ]] {
	bin/busybox --list-full >etc/mkinitramfs-ll/busybox.app || die
}
while read line; do
	ln -fs /bin/busybox $line
done <etc/mkinitramfs-ll/busybox.app

if [[ -n ${(k)opts[-L]} ]] || [[ -n ${(k)opts[-luks]} ]] { 
	opts[-bin]+=:cryptsetup opts[-mgrp]+=:dm-crypt
}

if [[ -n ${(k)opts[-gpg]} ]] || [[ -n ${(k)opts[-g]} ]] {
	opts[-mgrp]+=:gpg
	if [[ -x usr/bin/gpg ]] { :;
	} elif [[ $($(which gpg) --version | grep 'gpg (GnuPG)' | cut -c13) = 1 ]] {
		opts[-bin]+=:$(which gpg)
	} else { die "there's no usable gpg/gnupg-1.4.x" }
}

if [[ -n ${(k)opts[-lvm]} ]] || [[ -n ${(k)opts[-l]} ]] {
	opts[-bin]+=:lvm opts[-mgrp]+=:device-mapper
	pushd sbin
	for lpv ({vg,pv,lv}{change,create,re{move,name},s{,can}} \
		{lv,vg}reduce lvresize vgmerge) ln -sf lvm ${lpv} || die
	popd
}

if [[ -n ${(k)opts[-squashd]} ]] || [[ -n ${(k)opts[-q]} ]] { 
	opts[-bin]+=:mount.aufs:umount.aufs opts[-mgrp]+=:squashd
}

# @FUNCTION: domod
# @DESCRIPTION: copy kernel module
function domod()
{
	local mod module ret
	for mod ($*) {
		module=(/lib/modules/${opts[-kv]}/**/${mod}.(ko|o))
		if [[ -n ${module} ]] { 
			mkdir -p .${module:h} && cp -ar {,.}${module} ||
				die "failed to copy ${module} module"
		} else {
			warn "${mod} does not exist"
			((ret=${ret}+1))
		}
	}
	return ${ret}
}

for keymap (${(pws,:,)opts[-keymap]} ${(pws,:,)opts[-y]}) {
	if [[ -f usr/share/keymaps/${keymap}-${opts[-arch]}.bin ]] { :;
	} elif [[ -f ${keymap} ]] { cp -a ${keymap} usr/share/keymaps/
	} else { 
		loadkeys -b -u ${keymap} > usr/share/keymaps/${keymap}-${opts[-arch]}.bin ||
			die "failed to build ${keymap} keymap"
	}
}

for font (${(pws,:,)opts[-font]} ${(pws,:,)opts[-f]}) {
	if [[ -f usr/share/consolefonts/${font} ]] { :;
	} elif [[ -f ${font} ]] { cp -a ${font} usr/share/consolefonts/
	} else {
		for file (/usr/share/consolefonts/${font}*.gz) {
			cp ${file} . 
			gzip -d ${file:t}
		}
		mv ${font}* usr/share/consolefonts/
	}
}

if [[ -n ${opts[-splash]} ]] || [[ -n ${opts[-s]} ]] { 
	opts[-bin]+=:splash_util.static:fbcondecor_helper
	
	if [[ -n ${(k)opts[-toi]} ]] || [[ -n ${(k)opts[-t]} ]] {
		opts[-bin]+=:tuxoniceui_text
	}
	
	for theme (${(pws,:,)opts[-splash]} ${(pws,:,)opts[-s]})
		if [[ -d etc/splash/${theme} ]] { :;  
		} elif [[ -d /etc/splash/${theme} ]] { cp -ar {/,}etc/splash/${theme}
		} elif [[ -d ${theme} ]] { cp -r ${theme} etc/splash/ 
		} else { warn "splash themes does not exist" }
}

# @FUNCTION: docp
# @DESCRIPTION: follow and copy link until binary/library is copied
function docp()
{
	local link=${1} prefix
	[[ -n ${link} ]] || return
	cp -a {,.}${link}

	[[ -h ${link} ]] &&
	while true; do
	    prefix=${link%/*}
		link=$(readlink ${link})
		[[ ${link%/*} == ${link} ]] && link=${prefix}/${link}
		cp -a {,.}${link} || die
		[[ -h ${link} ]] || break
	done

	return 0
}

# @FUNCTION: dobin
# @DESCRIPTION: copy binary with libraries if not static
function dobin()
{
	local lib
	docp ${bin} || return

	[[ "$(ldd ${bin})" == "not a dynamic executable" ]] && return 0

	for lib ($(ldd ${bin} | sed -nre 's,.* ((/usr|)/lib.*/.*.so.*) .*,\1,p'))
		mkdir -p .${lib%/*} && docp ${lib} || die
}

for bin (${(pws,:,)opts[-bin]} ${(pws,:,)opts[-b]}) {
	for b ({usr/,}{,s}bin/${bin}) { [[ -x ${b} ]] && continue 2 }

	[[ -x ${bin} ]] && dobin ${bin}
	bin=$(which ${bin} 2>/dev/null)
	dobin ${bin} || warn "no ${bin} binary found"
}

for module (${(pws,:,)opts[-kmod]} ${(pws,:,)opts[-m]}) domod ${module}
for grp (${(pws,:,)opts[-mgrp]})
	for mod (${(pws,:,)opts[-m${grp}]})
		domod ${mod} && echo ${mod} >>etc/mkinitramfs-ll/${grp}

for lib (/usr/lib/gcc/**/lib*.so*) {
	ln -fs $lib     lib/$lib:t
	ln -fs $lib usr/lib/$lib:t
}

docpio /boot/${opts[-initramfs]} || die

print -P "%F{green}>>> ${opts[-initramfs]} initramfs built%f"

[[ -n ${(k)opts[-K]} ]] || [[ -n ${(k)opts[-keeptmp]} ]] || rm -rf ${opts[-tmpdir]}

unset opts

# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
