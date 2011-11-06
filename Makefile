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

all: install install_extras install_sqfsd

install:
	sed -e 's:\./${bin_prefix}\.conf:/etc/${bin_prefix}.conf:g' -i ${bin_prefix}
	sed -e 's:\./${bin_prefix}\.conf:/etc/${bin_prefix}.conf:g' -i ${bin_prefix}_bb
	sed -e 's:\./${bin_prefix}\.conf:/etc/${bin_prefix}.conf:g' \
		-e 's:\.\/mk:mk:g' -i ${bin_prefix}_gen
	sed -e 's:\./${bin_prefix}\.conf:/etc/${bin_prefix}.conf:g' -i ${bin_prefix}_gpg
	sed -e 's:\$$BINDIR/fr_l1-amd64.bin::' -i ${bin_prefix}.conf
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)
	install -pm 644 ${bin_prefix}.conf 	$(sys_confdir)
	install -pm 755 ${bin_prefix} 		$(bindir)
	install -pm 755 ${bin_prefix}_bb 	$(bindir)
	install -pm 755 ${bin_prefix}_gen 	$(bindir)
	install -pm 755 ${bin_prefix}_gpg 	$(bindir)
	install -pm 755 init 			$(datadir)

install_sqfsd:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount 	$(svc_initdir)
	install -pm 644 sqfsd/sqfsdmount.conf 	$(svc_confdir)/sqfsdmount
	install -pm 755 sqfsd/sqfsd-rebuild 	$(bindir)/sdr

postinstall:

uall: unintsall uninstall_extras uninstall_sqfsd

uninstall:
	rm -f $(bindir)/${bin_prefix}
	rm -f $(bindir)/${bin_prefix}_bb
	rm -f $(bindir)/${bin_prefix}_gen
	rm -f $(bindir)/${bin_prefix}_gpg
	rm -f $(datadir)/init
	rm -f $(sys_confdir)/${bin_prefix}.conf

uninstall_sqfsd:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

uninstall_extras:
	rm -f $(datadir)/bin/applets
	rm -f $(datadir)/misc/share/gnupg/options.skel

postuninstall:

