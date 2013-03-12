#!/bin/sh
# $Id: mkinitramfs-ll/usr/lib/mkinitramfs-ll/init.sh,v 0.11.7 2013/03/12 09:36:38 -tclover Exp $
mkdir -p /lib/mkinitramfs-ll/bin
cat </init | sed '/^#.*$/d' | tail -n+4 | head -n314 |
	sed -e 's/debug\ rsh.*$/exit\ \$_ret/' >>/lib/mkinitramfs-ll/functions.sh
for helper in $(grep '()' /lib/mkinitramfs-ll/functions.sh | sed 's,().*$,,g'); do
	{
		echo '#!/bin/sh'
		echo 'source /lib/mkinitramfs-ll/functions.sh'
		echo '${0##*/} "$@"'
	} >/lib/mkinitramfs-ll/bin/$helper
	chmod +x /lib/mkinitramfs-ll/bin/$helper
done
# vim:fenc=utf-8:ft=sh:ci:pi:sts=0:sw=4:ts=4:

