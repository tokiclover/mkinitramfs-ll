# $Header: mkinitramfs-ll/usr/lib/functions.sh,v 0.12.0 2013/04/09 12:57:08 -tclover Exp $

# @FUNCTION: info
# @EXTTERNAL
# @DESCRIPTION: print message on stdout
info() {
	echo -ne "\033[1;32m * \033[0m$@\n"
}


# @FUNCTION: error
# @EXTERNAL
# @DESCRIPTION: print error message on stdout
error() {
	echo -ne "\033[1;31m * \033[0m$@\n"
}

# @FUNCTION: debug
# @INTERNAL
# @DESCRIPTION: execute a command and log the command into $logfile
debug() {
	local _cmd _opt _ret
	while [ $# > 0 ]; do
		case $1 in
			-d*|-e*|-i*) _opt=${1:0:2} _msg="${1#$_opt}"
				shift
				;;
			--) shift
				_cmd="$@"
				shift $#
				break
				;;
			*) _cmd="$@"
				shift $#
				break
				;;
		esac
	done
	$_cmd; _ret=$?
	echo "[$_ret]: $_cmd" >>$logdir$logfile
	if [ ! "$_ret" ]; then
		case $_opt in
			-d) die   "${_msg:-cmd: $_cmd}"
				;;
			-e) error "${_msg:-cmd: $_cmd}"
				;;
			-i) info  "${_msg:-cmd: $_cmd}"
				;;
		esac
	fi
	return "$_ret"
}

# @FUNCTION: rsh
# @EXTERNAL
# @DESCRIPTON: Rescue SHell
rsh() {
	export PS1='-(rsh:$(tty | cut -c6-):$PWD)-# ' PS2='-> '
	if $spld; then
		debug openvt -c${console#*tty} $sh -i -m 0<$console 1>$console 2>&1
	elif ack setsid; then
		debug setsid $sh -i -m 0<$console 1>$console 2>&1
	else
		debug $sh -i -m 0<$console 1>$console 2>&1
	fi
}

# @FUNCTION: die
# @INTERNAL
# @DESCRIPTION: drop into a rescue shell after a command failure
die() {
	local _ret=$? _msg="Dropping into a rescueshell..."
	[ -n "$@" ] && error "[$_ret]: $@" && msg "[$_ret]: $@"
	info "$_msg"
	msg "$_msg"
	_stop
	debug rsh || debug exec $sh -i -m
}

# @FUNCTION: bck
# #INTERNAL
# @DESCRIPTION: Binary ChecK
bck() {
	debug -d which $1 1>/dev/null 2>&1
}

# @FUNCTION: ack
# @INTERNAL
# @DESCRIPTION: busybox Applets ChecK
ack() {
	local _app _applets="$@"
	[ -n "$_applets" ] || [ -f /etc/mkinitramfs-ll/busybox.app ] &&
		_applets="$(cat /etc/mkinitramfs-ll/busybox.app)" ||
		debug -d busybox --install -s && return
	for _app in $_applets; do 
		[ -h "$_app" ] && [ "$(readlink $_app)" = "/bin/busybox" ] ||
			debug -d busybox --install -s && break
	done
}

# @FUNCTION: _rmmod
# @EXTERNAL
# @DESCRIPTION: ReMove kernel MODules from a file liste or...
_rmmod() {
	[ -f "/etc/mkinitramfs-ll/module.$1" ] &&
		local _module="$(cat /etc/mkinitramfs-ll/module.$1)" ||
		local _module="$*"
	for _m in $_module; do 
		debug rmmod $_m 1>/dev/null 2>&1
	done
}

# @FUNCTION: _modprobe
# @EXTERNAL
# @DESCRIPTION: insert kernel MODules from a file liste or...
_modprobe() {
	[ -f "/etc/mkinitramfs-ll/module.$1" ] &&
		local _module="$(cat /etc/mkinitramfs-ll/module.$1)" ||
		local _module="$*"
	for _m in $_module; do 
		debug modprobe $_m 1>/dev/null 2>&1
	done
}

# @FUNCTION: _getopt
# @EXTERNAL
# @DESCRIPTION: get kernel command line options
_getopt() {
	for arg in $*; do
		for _opt in $(cat /proc/cmdline); do
			[ "$arg" = "${_opt%%=*}" ] && export $_opt && break
		done
	done
}

# @FUNCTION: cmd
# @EXTERNAL
# @DESCRIPTION: send command or message to splash deamon
cmd() {
	debug echo "$@" >$SPLASH_FIFO
}

# @FUNCTION: verbose
# @EXTERNAL
# @DESCRIPTION: set splash deamon to verbose message
verbose() {
	debug chvt ${console:8:1}
	debug cmd "set mode verbose"
}

# @FUNCTION: silent
# @EXTERNAL
# @DESCRIPTION: set splash deamon to silent
silent() {
	debug chvt ${console:8:1}
	debug cmd "set mode silent"
}

# @FUNCTION: msg
# @EXTERNAL
# @DESCRIPTION: send message to splash deamon
msg() {
	$spld && debug cmd "set message $@" && debug cmd "repaint"
}

# @FUNCTION: _stop
# @EXTERNAL
# @DESCRIPTION: stop splash deamon before dropping into a rescue shell
_stop() {
	$spld && spld=false
		debug cmd "exit"
}

# @VARIABLE: BOOT_MSG
# @EXTERNAL
# @DESCRIPTION: splash boot message

# @VARIABLE: SPLASH_FIFO
# @EXTERAL
# @DESCRIPTION: splash fifo file

# @VARIABLE: cachedir
# @EXTERNAL
# @DESCRIPTION: splash cache dir

# @FUNCTION: shread
# @EXTERNAL
# @DESCRIPTION: read line from stdin and drop to rescue shell if a line is sh[ell]
shread() {
	read _asw
	[ "$_asw" = "sh" ] || [ "$_asw" = "shell" ] && die
}

# @FUNCTION: blk
# @EXTERNAL
# @DESCRIPTION: get block device
blk() {
	eval $2=$(blkid | grep "${1#*=}" | cut -d: -f1)
}

# @FUNCTION: gev
# @EXTERNAL
# @DESCRIPTION: Get removable or dm-crypt LUKS block dEVices
gev() {
	local _asw _opt msg
	msg="Type in a valid dev e.g. [ sda5 | UUID=<uuid> | LABEL=<label> ]"
	case $1 in
		-r|-remd) _opt=remd
			shift
			;;
		-l|-luks) _opt=luks
			shift
			;;
	esac

	debug blk "$1" "$2"
	info "Insert $1 [removable] device and press Enter, or else"
	if [ "$_opt" = "remd" ]; then
		while true; do
			info "${msg/dev/removable device}"
			shread _asw
			sleep 1
			debug blk "${_asw:-$1}" "_dv"
			[ -n "$_dv" ] && [ -b "$_dv" ] && break
		done
	elif [ "$_opt" = "luks" ]; then
		while ! debug cryptsetup $_arg "$dev"; do
			info "${msg/dev/cyphertext or header}"
			shread _asw
			debug blk "${_asw:-$1}" "dev"
		done
	fi
}

# @FUNCTION: dlk
# @EXTERNAL
# @DESCRIOTON: Decrypt LDk, dm-crypt LUKS crypted, key file
dlk() {
	[ -b "$1" ] && return

	if [ ! "$cld" ]; then
		local _ld="$(debug -d losetup -f)"
		debug -d losetup "$_ld" "$1"
		ldv="$_ld:$ldv"
	else
		local _ld="$1"
	fi

	debug cryptsetup luksOpen "$_ld" "$_fn" && ldk="$_fn:$ldk"
}

# @FUNCTION: stk
# @EXTERNAL
# @DESCRIPTION: SeT Key [file] mode for decryptiong
stk() {
	local _fp="$(echo "$1" | cut -d: -s -f3)"
	local _kd="$(echo "$1" | cut -d: -s -f2)"
	local _km="$(echo "$1" | cut -d: -f1)"
	local _dv _fn=${_fp##*/}

	if [ "$_km" != "none" ];then
		if [ -z "$cld" ]; then
			local _v=$(cryptsetup --version | awk '{print $2}')
			[ $(echo "$_v" | cut -d'.' -f2) -ge 3 ] && cld=0
			[ $(echo "$_v" | cut -d'.' -f2) -ge 4 ] && cdh=0
			[ "$cdh" ] && [ $(echo "$_v" | cut -d'.' -f3) -ge 2 ] && cid=0
		fi
	else
		export kmode=none
		return
	fi
	
	if [ "${_km:-pwd}" != "pwd" ]; then
		[ -n "$_kd" ] || die "ik$2=$_km:$_kd:$_fp device field empty"
		[ -n "$_fp" ] || die "ik$2=$_km:$_kd:$_fp filepath field empty"
		debug blk "$_kd" "_dv"
		if [ -z "$(mount | grep /mnt/tok)" ]; then
			[ -b "$_dv" ] || debug -d gev -r "$_kd" "_dv"
			debug -d mount -n -r "$_dv" /mnt/tok
		fi
		debug -d test -f "/mnt/tok/$_fp"
	fi

	case ${_km:-pwd} in
		gpg) $eck && debug -d bck gpg
			export kfile="/mnt/tok$_fp" kmode=gpg
			;;
		reg) export kfile="/mnt/tok$_fp" kmode=reg
			;;
		ldk) dlk "/mnt/tok$_fp"
			export kfile="/dev/mapper/$_fn" kmode=ldk
			;;
		pwd) export kmode=pwd
			;;
		*) die "$_km: invalid key mode"
			;;
	esac
}

# @FUNCTION: dmclose
# @EXTERNAL
# @DESCRIPTION: close dm-crypt mapping
dmclose() { 
	[ -n "$2" ] && debug -d vgchange -an ${2%-*}
	local IFS="${IFS}:" 

	for _p in $1; do 
		debug cryptsetup luksClose ${_p%-*} $header ||
		debug cryptsetup remove ${_p%-*} $header
	done
}

# @FUNCTION: gld
# @EXTERNAL
# @DESCRIPTION: Get dm-crypt LUKS block device
gld() {
	if [ -e "$1" ]; then 
		dev=$1
	else
		[ "$cid" ] && [ -n "$(echo "$1" | grep -i UUID)" ] ||
			debug -d gev $2 "$1" "dev"
	fi
}

# @FUNCTIOON: dmopen
# @EXTERNAL
# @DESCRIPTION: open dm-crypt LUKS block device
dmopen() { 
	$eck && debug -d bck cryptsetup
	debug _modprobe dm-crypt

	local _arg=isLuks _header _msg
	local _map=$(echo "$1" | cut -d'-' -f1)
	local _dev=$(echo "$1" | cut -d'-' -f2 | cut -d'+' -f1)
	local _hdr="$(echo "$1" | cut -d'+' -f2 -s)"

	if [ -n "$_hdr" ]; then
		if [ -n "$(echo "$_hdr" | egrep '(UUID|LABEL|sd[a-z])')" ]; then 
			debug gld "$_hdr" -l
		elif [ -e "/mnt/tok/$_hdr" ]; then debug gld "/mnt/tok/$_hdr" -l
		else die "$_hdr detached header doesn't exist."; fi
		_header="--header $dev"
		debug gld "$_dev"
	else
		debug gld "$_dev" -l
	fi
	
	_dev=$dev
	debug -d cryptsetup $_arg "$_dev" "$_header" 
	_arg="luksOpen $_dev $_map $_header"
	_msg="there are still 3 pwd mode attempts"

	if [ "$kmode" = "gpg" ]; then 
		mv /dev/tty /dev/bak && cp -a /dev/console /dev/tty
		for _i in 1 2 3; do
			gpg -qd "$kfile" | cryptsetup $_arg && break || info "$_msg"
			echo "[$?]: gpg -qd "$kfile" | cryptsetup $_arg" >>$logdir$logfile
		done
		rm /dev/tty && mv -f /dev/bak /dev/tty
	elif [ "$kmode" = "ldk" ] || [ "$kmode" = "reg" ]; then
		debug cryptsetup $_arg -d "$kfile" || info "$_msg"
	fi

	ctxt=/dev/mapper/$_map
	[ -b "$ctxt" ] || debug -d cryptsetup $_arg
	debug -d test -b $ctxt && eval ${2:-ctxt}=$ctxt
}

# @FUNCTION: lvopen
# @EXTERNAL
# @DESCRIPTION: open LVM Logical Volume
lvopen() {
	$eck && debug -d bck lvm
	debug _modprobe device-mapper
	local _lv=${1/-//}

	debug lvchange -ay $_lv ||
	{
		if [ -n "$2" ] && [ "$kmode" != "none" ]; then
			local _pv="$2" IFS="${IFS}:"
			[ -e "/mnt/tok/$_pv" ] && _pv="$(cat /mnt/tok/$_pv)"
			for _p in $_pv; do
				debug dmopen "${_p}"
			done
			debug vgchange -ay ${1%-*} || debug -d dmclose "$_pv" "$1"
		else
			die "$1 require a valid crypted physical volume"
		fi
	}

	if [ -b "/dev/mapper/$1" ]; then
		eval ${3-lv}=/dev/mapper/$1
	elif [ -b "/dev/$_lv" ]; then
		eval ${3-lv}=/dev/$_lv
	else
		die "$_lv VG/LV not found"
	fi
}

# @FUNCTION: mdopen
# @EXTERNAL
# @DESCRIPTION: open md-raid block device
mdopen() {
	local _dev=${1%+*} _conf _opt=$(echo "$1" | cut -d+ -f2 -s) _set _uuid
	[ -n "$(echo "$_opt" | grep -i uuid)" ] && _uuid=$_opt

	if [ -n "$_uuid" ] || [ -n "$(echo "$_opt" | egrep '^[0-9]')" ]; then
		[ -n "$(echo $_dev | grep dev)" ] || _dev=/dev/$_dev
		[ -b "$_dev" ] && return
		$eck && debug -d bck mdadm
		debug _modprobe raid
	
		if [ -n "$_uuid" ]; then
			echo ARRAY $_dev $_uuid >>/etc/mdadm.conf
		else
			echo ARRAY $_dev devices=/dev/sd*${_opt:-*} >>/etc/mdadm.conf
		fi
		
		_conf=-c/etc/mdadm.conf
		debug -d mdadm --assemble ${_uuid:+-u${_uuid#*=}} $_conf $_dev
	else
		$eck && debug -d bck dmraid
		debug _modprobe dm-raid
		_dev=$(dmraid -r | grep "$_dev" | cut -d: -f1)
		[ -b "$_dev" ] && return

		for _f in $(echo "$_opt" | sed 's/:/ /g'); do
			_set+=" $(dmraid -s -c $_f)"
		done
		
		for _s in ${_dev##*/} $_set; do
			debug -d dmraid -ay -i -I $_s
		done
	fi

	debug -d test -b $_dev
	eval ${2:-md}=$_dev
}

# @FUNCTION: squashd
# @EXTERNAL
# @DESCRIPTION: mount squashed, aufs+squashfs, dirs
squashd() {
	local IFS="${IFS}:"
	debug -d test -n $sqfsd
	debug -d test -d /newroot$sqfsdir
	debug _modprobe sqfsd
	cd /newroot

	for _dir in $sqfsd; do
		local _bdir="$sqfsdir"/$_dir
		debug -d test -f .$_bdir.sfs
		debug mkdir -p -m 0755 .$_bdir/rw .$_bdir/rr .$_dir
		if [ -z "$(mount -t aufs | grep $_dir)" ]; then
			[ -z "$(mount -t squashfs | grep $_bdir/rr)" ] &&
   				debug -d mount -tsquashfs -onodev,loop,ro .$_bdir.sfs .$_bdir/rr
			mount -taufs -onodev,udba=reval,br:.$_bdir/rw:.$_bdir/rr $_dir $_dir
		fi
	done
}

# @FUNCTION: domount
# @EXTERNAL
# @DESCRIPTION: mount, /usr for example, extra block device using /etc/fstab
# before switching root
domount() {
	local _fs _dev _mpt _opt _x _y _z IFS="${IFS}:"
	for _x in $imount; do
		_y="$(grep $_x /newroot/etc/fstab)"
		if [ -n "${y}" ]; then
			 _fs=$(echo "$_y" | awk '{print $3}')
			_dev=$(echo "$_y" | awk '{print $1}')
			_mpt=$(echo "$_y" | awk '{print $2}')
			_opt=$(echo "$_y" | awk '{print $4}')
		else
			error "$_x not found in fstab"
			break
		fi
		debug blk "$_dev" "_dev"
		debug -d test -b $_dev
		[ -d /newroot/"$_mpt" ] || mkdir -p /newroot/"$_mpt"
		debug -d mount -t$_fs ${_opt:+-o$_opt} $_dev /newroot/$_mpt
	done
}

# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
