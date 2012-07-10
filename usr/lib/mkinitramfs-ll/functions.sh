# $Id: /lib/mkinitramfs-ll/functions.sh, 2012/07/10 20:24:02 -tclover Exp $

_getopt() {
	for arg in $*; do
		for _opt in $(cat /proc/cmdline); do
			[ "$arg" = "${_opt%%=*}" ] && export $_opt && break
		done
	done
}

# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
