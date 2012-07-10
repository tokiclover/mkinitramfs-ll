# $Id: /lib/mkinitramfs-ll/functions.sh, 2012/07/09 -tclover Exp $

_getopt() {
	for arg in $*; do
		for _opt in $(cat /proc/cmdline); do
			[ -n "$arg" = "${_opt%%=*}" ] && export $_opt && break
		done
	done
}

# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:
