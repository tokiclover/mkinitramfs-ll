# $Id: /lib/mkinitramfs-ll/functions.sh,v 0.10.8 2012/07/30 13:59:49 -tclover Exp $
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:

_getopt() {
	for arg in $*; do
		for _opt in $(cat /proc/cmdline); do
			[ "$arg" = "${_opt%%=*}" ] && export $_opt && break
		done
	done
}

