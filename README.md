Header: mkinitramfs-ll/README.md,v 0.18.0 2015/01/20 Exp

> A lightweight, modular and yet powerfull initramfs generating tool
with RAID (ATA RAID & SOFTWARE RAID), dm-crypt LUKS, LVM(2), BTRFS, ZFS,
TuxOnIce/SwSusp hibernation, AUFS+SquashFS, ZRAM and bCache support

INTRODUCTION
-----------

**BIG FAT NOTE:**

    **SUPPORTED BLOCK DEVICE STACK: [RAID]+[LUKS]+[LVM] or [LUKS]+[BTRFS|ZFS]**

It is possible to add ZFS on the first stack variant, but it does not make any
sense and expect horrible performance with such a mix bag. And this variant is
not implemented although it could be done easily.
(The same goes for BTRFS support (require >=btrfs-progs-3.12))

The order of LUKS/LVM can be changed, that is LUKS+LVM or LVM+LUKS is possible.


GETTING AN INTRAMFS QUICKLY AND READY
-------------------------------------

An initramfs can be made in matter of secondes with locales settings
(keymap and consolefont) if a busybox binary is available.
media-fonts/terminus-font is recomanded to get a nice and neat interface
in early boot up.

app-crypt/gnupg-1.4.x is mandatory for GnuPG support (a binary along with
its options.skel file is required.)

And then run `mkinitramfs-ll.$SHELL -a -f$FONT -y$LINGUAS` to build an initramfs.
The appended font and keymap will be the default if there is no *keymap* kernel
cmdline argument.

Of course, one can append extra fonts and keymaps with `-f:ter-g12n -y:fr-latin1`
etc. and the `-a|--all` option depend on `mkinitramfs-ll.conf`
so one can put many sane default values there.

One can get more info on the scripts by running `$SCRIPT -?|-h|--help`

DOCUMENTATION
-------------

See mkinitramfs-ll(1) for more info on kernel command line options

See mkinitramfs-ll(8) for more info on the build script options

INSTALLATION
------------

`make DESTDIR=/tmp PREFIX=/usr/local install` to install initramfs files hierarchy;
`install-{,ba,z}sh-scripts` for POSIX, Bourne Again or Z shell build script;
`install-{squashd,tmpdir,zram}-svc` for extra init scripts service (refer to FILES
sub-section);
`install-all` for everything minus {ba,z}sh scripts...

WARING: POSIX build script cannot be used with {ba,z}sh build script because of
a configuration file mismatch (associative array usage.) Or else, a few quick
edits would do the trick!

COPYING
-------

**BIG FAT WARN:**

    **USE AT YOUR OWN RISK! EVERYTHING IS GIVEN "AS IS" (SEE COPYING FILE)**
    **Distributed under the 2-clause/new/simplified BSD License**

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
first (if squashded.) And this require a static busybox to function at all.

## ZRAM

Two init service scripts are available, one that can be used to set up zram
devices directly for space usage efficiency (compared to a regular tmpfs.)

Another one, an optional client of zram, handles temporary directory with an
optional saved state (tarball backup.)

The later can be used on a tmpfs based device instead of zram, configuration
edit is required (use zram by default.)

CONTRIBUTORS
------------

Thanks to:

Federico Zagarzazu (early init script with LUKS/Suspend2 support);
Jan Matějka aka yaccz for his suggestions (debug...);
Simon Buehler for debugging...;
And others;

GENTOO USERS NOTE
-----------------

An [ebuild][1] for Gentoo users.

Gentoo users can use provided scripts to build static busybox/gnupg.
(See in /scripts directory for extra scripts.)

`gnupg.sh` will build a binary in the current directory
(with a usr/bin/gpg and usr/share/gnupg/options.skel)
or else in /usr/local/mkiniramfs-ll directory if installed variant.
The same goes for `busybox.sh' which build a static binary.

[1]: https://github.com/tokiclover/bar-overlay
