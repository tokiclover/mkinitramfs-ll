PACKAGE = mkinitramfs-ll
VERSION = $(shell grep revision= ${bin_prefix}|sed -e 's:revision=::')


prefix		= usr/local
bindir 		= ${DESTDIR}/${prefix}/sbin
bin_prefix	= mkifs-ll
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir		= ${DESTDIR}/${prefix}/share/$(PACKAGE)
docdir		= ${DESTDIR}/${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README ChangeLog KnownIssue

all: install install_sqfsd

install:
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)
	install -pm 644 ${bin_prefix}.conf.bash $(sys_confdir)
	install -pm 755 ${bin_prefix}.bash      $(bindir)
	install -pm 755 ${bin_prefix}_bb.bash   $(bindir)
	install -pm 755 ${bin_prefix}_gen.bash  $(bindir)
	install -pm 755 ${bin_prefix}_gpg.bash  $(bindir)
	install -pm 755 init                    $(datadir)

install_sqfsd:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount.initd   $(svc_initdir)/sqfsdmount
	install -pm 644 sqfsd/sqfsdmount.confd   $(svc_confdir)/sqfsdmount
	install -pm 755 sqfsd/sqfsd-rebuild.bash $(bindir)/sdr.bash

postinstall:

uall: unintsall uninstall_sqfsd

uninstall:
	rm -f $(bindir)/${bin_prefix}.bash
	rm -f $(bindir)/${bin_prefix}_bb.bash
	rm -f $(bindir)/${bin_prefix}_gen.bash
	rm -f $(bindir)/${bin_prefix}_gpg.bash
	rm -f $(datadir)/init
	rm -f $(sys_confdir)/${bin_prefix}.conf.bash

uninstall_sqfsd:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall:
