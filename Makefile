PACKAGE = mkinitramfs-ll
VERSION = $(grep Header init | sed -e 's:# $Header.*,v ::' -e 's:2012.*$::')

prefix      = usr/local
bindir      = ${DESTDIR}/${prefix}/sbin
bin_prefix  = mkifs-ll
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}/${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}/${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README.textile ChangeLog KnownIssue

all: install_init install_sqfsd_svc install_scripts_bash install_scripts_zsh

install:
	install -pd $(datadir)
	install -pm 755 init                   $(datadir)

install_bash:
	sed -e 's:\./${bin_prefix}:${bin_prefix}:g' \
		-e 's:${bin_prefix}.conf:/etc/${bin_prefix}.conf:g' \
		-e 's:autogen.bash:${bin_prefix}_autogen.bash:' \
		-e 's:autogen.bash:${bin_prefix}_busybox.bash:' \
		-e 's:autogen.bash:${bin_prefix}_gnupg.bash:' \
		-i ${bin_prefix}*.zsh
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 755 autogen.zsh             $(bindir)/${bin_prefix}_autogen.bash
	install -pm 755 busybox.zsh             $(bindir)/${bin_prefix}_busybox.bash
	install -pm 755 gnupg.zsh               $(bindir)/${bin_prefix}_gnupg.bash
	install -pm 644 ${bin_prefix}.conf.bash $(sys_confdir)
	install -pm 755 ${bin_prefix}.bash      $(bindir)
	install -pm 755 sqfsd_svc/sdr.bash      $(bindir)

install_zsh:
	sed -e 's:\./${bin_prefix}:${bin_prefix}:g' \
		-e 's:${bin_prefix}.conf:/etc/${bin_prefix}.conf:g' \
		-e 's:autogen.zsh:${bin_prefix}_autogen.zsh:' \
		-e 's:autogen.zsh:${bin_prefix}_busybox.zsh:' \
		-e 's:autogen.zsh:${bin_prefix}_gnupg.zsh:' \
		-i ${bin_prefix}*.zsh
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 755 autogen.zsh             $(bindir)/${bin_prefix}_autogen.zsh
	install -pm 755 busybox.zsh             $(bindir)/${bin_prefix}_busybox.zsh
	install -pm 755 gnupg.zsh               $(bindir)/${bin_prefix}_gnupg.zsh
	install -pm 644 ${bin_prefix}.conf.zsh  $(sys_confdir)
	install -pm 755 ${bin_prefix}.zsh       $(bindir)
	install -pm 755 sqfsd_svc/sdr.zsh       $(bindir)

install_svc:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd_svc/sqfsdmount.initd  $(svc_initdir)/sqfsdmount
	install -pm 644 sqfsd_svc/sqfsdmount.confd  $(svc_confdir)/sqfsdmount

postinstall:

uall: unintsall uninstall_bash uninstall_zsh uninstall_svc

uninstall:
	rm -f $(datadir)/init

uninstall_bash:
	rm -f $(bindir)/${bin_prefix}.bash
	rm -f $(bindir)/${bin_prefix}_busybox.bash
	rm -f $(bindir)/${bin_prefix}_autogen.bash
	rm -f $(bindir)/${bin_prefix}_gnupg.bash
	rm -f $(sys_confdir)/${bin_prefix}.conf.bash

uninstall_zsh:
	rm -f $(bindir)/${bin_prefix}.zsh
	rm -f $(bindir)/${bin_prefix}_busybox.zsh
	rm -f $(bindir)/${bin_prefix}_autoen.zsh
	rm -f $(bindir)/${bin_prefix}_gnupg.zsh
	rm -f $(sys_confdir)/${bin_prefix}.conf.zsh

uninstall_svc:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall:
