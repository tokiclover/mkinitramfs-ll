Header: mkinitramfs-ll/README.md,v 0.16.0 2015/01/01 Exp

A lightweight, modular and yet powerfull initramfs generating tool
with RAID (fake ATA software RAID or md-raid), dm-crypt LUKS, LVM[2],
TuxOnIce/swsusp hibernation, AUFS+SquashFS, ZFS, zram and bcache support
========================================================================

ITRODUCTION
-----------

BIG FAT NOTE: SUPPORTED BLOCK DEVICE STACK IS:
    [RAID]+[LUKS]+[LVM] or [LUKS]+[ZFS]

It is possible to add ZFS on the first stack variant, but it does not make any
sense and expect horrible performance with such a mix bag. And this variant is
not implemented although it could be done easily.

The order of LUKS/LVM can be changed, that is LUKS+LVM or LVM+LUKS is possible.


GETTING AN INTRAMFS QUICKLY AND READY
-------------------------------------

An initramfs can be made in matter of secondes with locales settings
(keymap and consolefont) if a busybox binary is available.
media-fonts/terminus-font is recomanded to get a nice and neat interface
in early boot up.

app-crypt/gnupg-1.4.x is mandatory for GnuPG support (a binary along with
its options.skel file is required.)

And then run `mkinitramfs-ll.$SHELL -a -fter-g14n -y$LINGUAS` to build an initramfs.
The appended font and keymap will be the default if there is no *ikmap* kernel
cmdline argument.

Of course, one can append extra fonts and keymaps with `-f:ter-g12n -y:fr-latin1`
etc. and the `-a|--all` option depend on `mkinitramfs-ll.conf`
so one can put many sane default values there.

One can get more info on the scripts by running `$SCRIPT -?|-h|--help`

DOCUMENTATION
-------------

See mkinitramfs-ll(1) for more on kernel command line options
See mkinitramfs-ll(8) for more on the build script options

COPYING
-------

BIG FAT WARN: USE AT YOUR OWN RISK! EVERYTHING IS GIVEN "AS IS", SEE COPYING FILE

Distributed under the 2-clause/new/simplified BSD License

FILES
-----
### /usr 

An image like directory with extra files required for the initramfs.
Extra files (binaries along with library dependencies), user scripts,
keymaps and fonts can be directly putted there.

### /scripts

Some extra scripts are available there, notably {busybox,gpg}.{ba,z}sh for
Gentoo Users.

A suspend/hibernation script along with an initramfs utility (decompress
and list) are available.

### /svc

## AUFS+SquashFS

An init service script along with a build script for squashed directory are
available. Managing system wide directories is problematic, so put `usr'
first (is squashded.) And this require a static busybox to function at all.

## ZRAM

Two init service scripts are available, one that can be used to set up zram
devices directly; and another one, a client, can be used on top of the first
to bind/mount directory on a backed zram device.

The later can be used on a tmpfs based device (a little edit on depend()
would suffice for that.)

GENTOO USERS NOTE
-----------------

An [ebuild][1] for Gentoo users.

Gentoo users can use provided scripts to build static busybox/gnupg.
(See in /scripts directory for extra scripts.)

@gnupg.{ba,z}sh@ will build a binary in the current directory
(with a usr/bin/gpg and usr/share/gnupg/options.skel)
or else in /usr/local/mkiniramfs-ll directory if installed variant.
The same goes for busybox.{ba,z}sh which build a static binary.

[1]: https://github.com/tokiclover/bar-overlay
