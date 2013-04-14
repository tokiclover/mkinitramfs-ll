# $Header: mkinitramfs-ll/usr/lib/functions.sh,v 0.12.2 2013/04/14 15:23:28 -tclover Exp $

# @FUNCTION: arg
# EXTERNAL
# @USAGE: <var> <char> <int> <opt>
# @DESCRIPTION: retrieve a value from a kernel cmdline
arg() {
	eval ${1}=$(echo "$2" | cut -d$3 -f${4:-:} $5)
}

# @FUNCTION: info
# @EXTTERNAL
# @USAGE: <srting>
# @DESCRIPTION: print message on stdout
info() {
	echo -ne "\033[1;32m * \033[0m$@\n"
}

# @FUNCTION: error
# @EXTERNAL
# @USAGE: <string>
# @DESCRIPTION: print error message on stdout
error() {
	echo -ne "\033[1;31m * \033[0m$@\n"
}

# @FUNCTION: msg
# @EXTERNAL
# @USAGE: [ -e | -i ] <string>
# @DESCRIPTION: manage message sent to stdout and to splash deamon
msg() {
	local _opt _msg
	while true; do
		case $1 in
			-e|-i) _opt=${1:0:2} _msg="${1#$_opt}"
				shift
				;;
			--) shift
				_msg="$@"
				shift $#
				break
				;;
			*) _msg="$@"
				shift $#
				break
				;;
		esac
	done

	case $_opt in
		-e) error "${_msg}"
			;;
		-i) info  "${_msg}"
			;;
	esac

	$SPLD && debug cmd "set message $_msg" && debug cmd "repaint"
}

# @FUNCTION: debug
# @EXTERNAL
# @USAGE: [ -d | -e ] <string>
# @DESCRIPTION: execute a command and log the command into $logfile
debug() {
	local _cmd _opt _ret
	while true; do
		case $1 in
			-d|-e|-i) _opt=${1:0:2} _msg="${1#$_opt}"
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

	$_cmd
	_ret=$?

	echo "[$_ret]: $_cmd" >>$LOGFILE
	
	if [ ! "$_ret" ]; then
		case $_opt in
			-d) die "${_msg:-cmd: $_cmd}"
				;;
			-e) msg -e "${_msg:-cmd: $_cmd}"
				;;
			-i) msg -i "${_msg:-cmd: $_cmd}"
				;;
		esac
	fi

	return "$_ret"
}

# @FUNCTION: rsh
# @EXTERNAL
# @DESCRIPTON: Rescue SHell
rsh() {
	if $SPLD; then
		debug openvt -c${CONSOLE#*tty} $sh -i -m 0<$CONSOLE 1>$CONSOLE 2>&1
	elif ack setsid; then
		debug setsid $sh -i -m 0<$CONSOLE 1>$CONSOLE 2>&1
	else
		debug $sh -i -m 0<$CONSOLE 1>$CONSOLE 2>&1
	fi
}

# @FUNCTION: die
# @EXTERNAL
# @USAGE: <msg>
# @DESCRIPTION: drop into a rescue shell after a command failure
die() {
	local _ret=$? _msg="Dropping into a rescueshell..."
	[ -n "$@" ] && msg -e "[$_ret]: $@"
	msg -i "$_msg"
	spld_stop
	debug rsh || debug exec $sh -i -m
}

# @FUNCTION: bck
# #EXTERNAL
# @USAGE: <bin>
# @DESCRIPTION: Binary ChecK
bck() {
	debug -d which $1 1>/dev/null 2>&1
}

# @FUNCTION: ack
# @EXTERNAL
# @USAGE: [<applets>]
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
# @USAGE: <kernel module(s)|module group>
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
# @USAGE: <kernel module(s) | module group>
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
# @USAGE: <kernel cmdline>
# @DESCRIPTION: get kernel command line options
_getopt() {
	for _arg in $*; do
		for _opt in $(cat /proc/cmdline); do
			[ "$_arg" = "${_opt%%=*}" ] && export $_opt && break
		done
	done
}

# @FUNCTION: spld_cmd
# @EXTERNAL
# @USAGE: <splash spld_cmd>
# @DESCRIPTION: send command or message to splash deamon
spld_cmd() {
	debug echo "$@" >$SPLASH_FIFO
}

# @FUNCTION: spld_verbose
# @EXTERNAL
# @DESCRIPTION: set splash deamon to verbose message
spld_verbose() {
	debug chvt ${CONSOLE:8:1}
	debug spld_cmd "set mode spld_verbose"
}

# @FUNCTION: spld_silent
# @EXTERNAL
# @DESCRIPTION: set splash deamon to silent, suppresse message
spld_silent() {
	debug chvt ${CONSOLE:8:1}
	debug spld_cmd "set mode silent"
}

# @FUNCTION: spld_stop
# @EXTERNAL
# @DESCRIPTION: stop splash deamon before dropping into a rescue shell
spld_stop() {
	$SPLD && SPLD=false
	debug spld_cmd "exit"
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
# @USAGE: <var>
# @DESCRIPTION: read line from stdin and drop to rescue shell if a line is sh[ell]
shread() {
	read _asw
	[ "$_asw" = "sh" ] || [ "$_asw" = "shell" ] && die
}

# @FUNCTION: blk
# @EXTERNAL
# @USAGE: <block device node | (part of) uuid | (part of) label>
# @DESCRIPTION: get block device
blk() {
	local _asw _blk=$(blkid | grep "$1" | cut -d: -f1)
	
	if [ ! -b "$_blk" ]; then
		msg -i "Insert $1 block device and press Enter"
		_blk=$(blkid | grep "$1" | cut -d: -f1)
		sleep 1

		while [ ! -b "$_blk" ]; do
			msg -i "Type in a valid block device e.g. \
				[ sda5 | UUID=<uuid> | LABEL=<label> ]"
			shread _asw
			sleep 1
			_blk=$(blkid | grep "$1" | cut -d: -f1)
			[ -n "$_blk" ] && [ -b "$_blk" ] && break
		done
	fi

	eval ${2:-BLK}=$_blk
}

# @VARIABLE: LBD
# @DESCRIPTION: Loop Back Device holder for ldk key mode, to be cleaned

# @VARIABLE: LBK
# @DESCRIPTION: Loop Back device Key holder for ldk key mode, like above,
# to be cleaned

# @FUNCTION: ldk
# @EXTERNAL
# @USAGE: <full path to file> plus a mapping indirectly given by <_fn>
# @DESCRIOTON: Decrypt LDk, dm-crypt LUKS crypted, key file
ldk() {
	[ -b "$1" ] && return

	if [ ! "$CLD" ]; then
		local _ld="$(debug -d losetup -f)"
		debug -d losetup "$_ld" "$1"
		LBD="$_ld:$LBD"
	else
		local _ld="$1"
	fi

	debug cryptsetup luksOpen "$_ld" "$_fn" && LBK="$_fn:$LBK"
}

# @VARIABLE: CLD
# @DESCRIPTION: an auto seted variable if >=cryptsetup-1.3 manage automaticaly
# Loop Back Device

# @FUNCTION: stk
# @EXTERNAL
# USAGE: <mode:dev:/path/to/file>
# @DESCRIPTION: SeT Key [file] mode for decryptiong
stk() {
	local _dv _fp _fn _kd _km
	arg "_fp" "$1" ":" "3" "-s"
	arg "_kd" "$1" ":" "2" "-s"
	arg "_km" "$1" ":" "1"
	_fn=${_fp##*/}

	if [ -z "$_km" ];then
		export keymode=none
		return
	elif [ "$_km" = "ldk" ];then
		[ -z "$CLD" ] &&
		[ $(cryptsetup --version | awk '{print $2}' | cut -d'.' -f2) -ge 3 ] &&
		CLD=true
	fi

	if [ "${_km:-pwd}" != "pwd" ]; then
		[ -n "$_kd" ] || die "device field empty"
		[ -n "$_fp" ] || die "file path field empty"

		if [ -z "$(mount | grep /mnt/tok)" ]; then
			[ -b "$_dv" ] || blk "$_kd" "_dv"
			debug -d mount -n -r "$_dv" /mnt/tok
		fi
		debug -d test -f "/mnt/tok/$_fp"
	fi

	case $_km in
		gpg) $ECK && debug -d bck gpg
			export keyfile="/mnt/tok$_fp" keymode=gpg
			;;
		reg) export keyfile="/mnt/tok$_fp" keymode=reg
			;;
		ldk) ldk "/mnt/tok$_fp"
			export keyfile="/dev/mapper/$_fn" keymode=ldk
			;;
		pwd) export keymode=pwd
			;;
		*) die "$_km: invalid key mode"
			;;
	esac
}

# @FUNCTION: dmclose
# @EXTERNAL
# @USAGE: <mapping>
# @DESCRIPTION: close dm-crypt mapping
dmclose() { 
	local IFS="${IFS}:" 
	for _p in $1; do 
		debug cryptsetup remove ${_p%-*}
	done
}

# @FUNCTION: dmc
# @EXTERNAL
# @USAGE: <dev> <var>
# @DESCRIPTION: get DM-Crypt LUKS block device or detached header
dmcrypt() {
	local _asw _ldh=$1
	while ! debug cryptsetup $_arg "$_ldh"; do
		msg -i "Type in a valid cyphertext device e.g. \
			[ sda5 | UUID=<uuid> | LABEL=<label> ], or avalid detached header"
		shread _asw
		debug blk "${_asw:-$1}" "_ldh"
	done

	eval ${2:-GLD}=$_ldh
}

# @FUNCTIOON: dmopen
# @EXTERNAL
# @USAGE: <map-dev+header>
# @DESCRIPTION: open dm-crypt LUKS block device
dmopen() { 
	$ECK && debug -d bck cryptsetup
	debug _modprobe dm-crypt

	local _arg=isLuks _ctx _dev _hdr _header
	arg "_map" "$1" "-" "1"
	arg "_hdr" "$1" "+" "2" "-s"
	blk "$(echo "$1" | cut -d'-' -f2 -s | cut -d'+' -f1)" "_dev"

	if [ -n "$_hdr" ]; then
		if [ -n "$(echo "$_hdr" | egrep '(UUID|LABEL|sd[a-z])')" ]; then 
			debug dmcrypt "$_hdr" "_header"
		elif [ -e "/mnt/tok/$_hdr" ]; then
			debug dmcrypt "header" "/mnt/tok/$_hdr" "_header"
		else
			die "header not found"
		fi
		_header="--header $_header"
	else
		debug dmcrypt "$_dev" "_dev"
	fi

	_arg="luksOpen $_dev $_map $_header"

	if [ "$keymode" = "gpg" ]; then 
		mv /dev/tty /dev/bak && cp -a /dev/console /dev/tty
		for _i in 1 2 3; do
			gpg -qd "$keyfile" | cryptsetup $_arg && break
			echo "[$?]: gpg -qd "$keyfile" | cryptsetup $_arg" >>$LOGFILE
		done
		rm /dev/tty && mv -f /dev/bak /dev/tty
	elif [ "$keymode" = "ldk" ] || [ "$keymode" = "reg" ]; then
		debug cryptsetup $_arg -d "$keyfile"
	fi

	_ctx=/dev/mapper/$_map
	[ -b "$_ctx" ] || debug -d cryptsetup $_arg
	debug -d test -b $_ctx && eval ${2:-CTX}=$_ctx
}

# @FUNCTION: lvopen
# @EXTERNAL
# @USAGE: <vg-lv> <map-crypted_pv>
# @DESCRIPTION: open LVM Logical Volume
lvopen() {
	$ECK && debug -d bck lvm
	debug _modprobe device-mapper
	local _lv=${1/-//}

	debug lvchange -ay $_lv ||
	{
		if [ -n "$2" ] && [ "$keymode" != "none" ]; then
			local _pv="$2" IFS="${IFS}:"
			[ -e "/mnt/tok/$_pv" ] && _pv="$(cat /mnt/tok/$_pv)"
			for _p in $_pv; do
				debug dmopen "${_p}"
			done
			debug vgchange -ay ${1%-*} || debug -d dmclose "$_pv"
		else
			die "$1 require a valid crypted physical volume"
		fi
	}

	if [ -b "/dev/mapper/$1" ]; then
		eval ${3-LV}=/dev/mapper/$1
	elif [ -b "/dev/$_lv" ]; then
		eval ${3-LV}=/dev/$_lv
	else
		die "$_lv VG/LV not found"
	fi
}

# @FUNCTION: mdopen
# @EXTERNAL
# @USAGE: <mdn-opt>
# @DESCRIPTION: open md-raid block device
mdopen() {
	local _dev _conf _opt _set _uuid
	arg "_dev" "$1" "+" "1"
	arg "_opt" "$1" "+" "2" "-s"
	[ -n "$(echo "$_opt" | grep -i uuid)" ] && _uuid=$_opt

	if [ -n "$_uuid" ] || [ -n "$(echo "$_opt" | egrep '^(\[|[0-9])')" ]; then
		[ -n "$(echo $_dev | grep dev)" ] || _dev=/dev/$_dev
		[ -b "$_dev" ] && return
		$ECK && debug -d bck mdadm
		debug _modprobe raid
	
		if [ -n "$_uuid" ]; then
			echo ARRAY $_dev $_uuid >>/etc/mdadm.conf
		else
			echo ARRAY $_dev devices=/dev/sd*${_opt:-*} >>/etc/mdadm.conf
		fi
		
		_conf=-c/etc/mdadm.conf
		debug -d mdadm --assemble ${_uuid:+-u${_uuid#*=}} $_conf $_dev
	else
		$ECK && debug -d bck dmraid
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
	eval ${2:-MD}=$_dev
}

# @FUNCTION: squashd
# @EXTERNAL
# @USAGE: indirectly given by isqfsd variable
# @DESCRIPTION: mount squashed, aufs+squashfs, dirs
squashd() {
	[ "${isqfsd%,*}" = "y" ] && sqfsdir="${sqfsdir:-/sqfsd}" ||
		sqfsdir=${isqfsd%,*}

	if [ "${isqfsd#*,}" = "y" ]; then sqfsd="${sqfsd:-usr:opt:bin:sbin}"
	elif [ "$(echo ${isqfsd#*,}|cut -d: -f1)" = "a" ]; then
		sqfsd="${sqfsd:-usr:opt:bin:sbin}:$(echo ${isqfsd#*,} | cut -c3-)"
	else
		sqfsd="$(echo ${isqfsd#*,} | cut -c3-)"
	fi

	local IFS="${IFS}:"
	debug -d test -d /newroot$sqfsdir
	debug _modprobe sqfsd
	cd /newroot

	for _dir in $sqfsd; do
		local _bdir="$sqfsdir"/$_dir
		debug -d test -f .$_bdir.sfs
		debug mkdir -p -m 0755 .$_bdir/rw .$_bdir/rr ./$_dir
		if [ -z "$(mount -t aufs | grep $_dir)" ]; then
			[ -z "$(mount -t squashfs | grep $_bdir/rr)" ] &&
   				debug -d mount -tsquashfs -onodev,loop,ro .$_bdir.sfs .$_bdir/rr &&
				mount -taufs -onodev,udba=reval,br:.$_bdir/rw:.$_bdir/rr $_dir $_dir
		fi
	done
}

# @FUNCTION: domount
# @EXTERNAL
# @UAGE: indirectly given by /etc/fstab
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
			msg -e "$_x not found in fstab"
			break
		fi
		blk "$_dev" "_dev"
		debug -d test -b $_dev
		[ -d /newroot/"$_mpt" ] || mkdir -p /newroot/"$_mpt"
		debug -d mount -t$_fs ${_opt:+-o$_opt} $_dev /newroot/$_mpt
	done
}

# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
