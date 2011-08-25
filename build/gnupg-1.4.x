#!/bin/bash
CDIR=$(pwd)
mkdir -p bin

die() {
	echo "* $@"
	exit 1
}

. /etc/make.conf

cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die "eek"
GPG=$(emerge -pvO =app-crypt/gnupg-1.4*|grep -o "gnupg-[-0-9.r]*")
USE="nls static" ebuild $GPG.ebuild compile || die "eek!"
cd ${PORTAGE_TMPDIR:-/var/tmp}/portage/app-crypt/$GPG/work/gnupg* || die "eek!"
cp -a gpg $CDIR/bin/ || die "eek!"
cp g10/options.skel $CDIR/bin/ || die "eek!"
cd ${PORTDIR:-/usr/portage}/app-crypt/gnupg || die "eek"
ebuild $GPG.ebuild clean || die "eek!"
cd $CDIR || die "eek!"

unset CDIR
unset GPG
exit 0
