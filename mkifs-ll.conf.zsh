# $Id: mkinitramfs-ll/mkifs-ll.conf.zsh, 2012/05/13 12:21:12 -tclover Exp $
#
# This is needed for building binaries!
if [[ -f /etc/make.conf ]] { source /etc/make.conf }
#
# opts is an associative array which hold pretty much every single option, so one
# could assign default values for pretty much everything: it's usually opts[--arg]
# <arg> being an options or a command line switch. opts[-arg] is a colon ':' 
# separated list for each option/arg that is a list.
#
# opts[--m<grp>] is a list of autoloaded modules, nls_cp437:vfat should be putted 
# to remdev group for vfat remdev users. if built as modules the script will 
# include them and nothing if not so one can leave as is. one could add a list
# of modules to opts[-mdep] modules dependencies or simply kernel modules which
# one could load at boot time with `imod' kernel cmdline argument.
opts[-mboot]+=:blowfish_common:blowfish_generic
opts[-mgpg]+=:cast5
opts[-msqfsd]+=:squashfs
opts[-mremdev]+=:nls_cp437:vfat
opts[-mtuxonice]+=:
#
# This option is list of binaries to include in the initramfs, library dependencies 
# will be copied over using `$(ldd /path/to/bin)' with a *single pass* meaning extra 
# $(ldd /library/dependency) may be necessary. binaries will be copied first from 
# $opts[-bindir] and then from $PATH. Binaries from $opts[-bindir] should have the 
# head path without the leading slash `/', otherwise they will be copied to `/'.
opts[-bin]+=:cryptsetup:fsck.ext4:fsck.jfs:fsck.reiserfs:fsck.xfs:v86d:usr/bin/gpg
#
opts[-font]+=:lat9w-14.psfu:ter-g14n.psf:ter-g14b.psf:ter-g14v.psf:ter-g12n.psf
opts[-keymap]+=:$opts[-bindir]/fr_l1-amd64.bin
opts[-mdep]+=:btrfs:jfs:xfs:i915:nouveau:radeon:drm:drm_kms_helper:ttm:uvesafb
opts[-mdep]+=:video:button:mxm-wmi:i2c-algo-bit
#
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=0:sw=4:ts=4:
