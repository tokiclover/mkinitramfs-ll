PACKAGE = initramfs-ll
VERSION = $(shell grep revision= mkinitramfs-ll|sed -e 's:revision=::')


prefix		= usr/local
bindir 		= ${DESTDIR}/${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir		= ${DESTDIR}/${prefix}/share
docdir		= ${DESTDIR}/${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README ChangeLog

clean:

install:
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)/$(PACKAGE)
	install -pm 755 misc/$(PACKAGE).conf    $(sys_confdir)
	install -pm 755 mkinitramfs 		$(bindir)
	install -pm 755 mk$(PACKAGE) 		$(bindir)
	install -pm 755 mk$(PACKAGE)_bb 	$(bindir)
	install -pm 755 mk$(PACKAGE)_gen 	$(bindir)
	install -pm 755 mk$(PACKAGE)_gpg 	$(bindir)
	install -pm 755 init 			$(datadir)/$(PACKAGE)

install_sqfsd:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount 	$(svc_initdir)
	install -pm 644 sqfsd/sqfsdmount.conf 	$(svc_confdir)/sqfsdmount

install_extras:
	install -pd $(datadir)/$(PACKAGE)/misc/share/gnupg
	install -pd $(datadir)/$(PACKAGE)/bin
	install -pm 644 bin/applets $(datadir)/$(PACKAGE)/bin
	install -pm 644 misc/share/gnupg/options.skel $(datadir)/misc/share/gnupg

postinstall:

uninstall:
	rm -f $(bindir)/mkinitramfs
	rm -f $(bindir)/mk$(PACKAGE)
	rm -f $(bindir)/mk$(PACKAGE)_bb
	rm -f $(bindir)/mk$(PACKAGE)_gen
	rm -f $(bindir)/mk$(PACKEGE)_gpg
	rm -f $(datadir)/init
	rm -f $(docdir)/$(PACKAGE).conf

uninstall_sqfsd:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

uninstall_extras:
	rm -f $(datadir)/$(PACKAGE)/bin/applets
	rm -f $(datadir)/$(PACKAGE)/misc/share/gnupg/options.skel

postuninstall:

