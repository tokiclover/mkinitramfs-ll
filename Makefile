PACKAGE = initramfs-ll
VERSION = $(shell grep revision= mkinitramfs-ll|sed -e 's:revision=::')


prefix		= usr/local
bindir 		= ${DESTDIR}/${prefix}/sbin
bin_prefix	= mkifs-ll
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir		= ${DESTDIR}/${prefix}/share
docdir		= ${DESTDIR}/${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README ChangeLog KnownIssue

clean:

install:
	sed -e 's:\$$MISC/${bin_prefix}:/etc/${bin_prefix}:g' -i ${bin_prefix}
	sed -e 's:\$$MISC/${bin_prefix}:/etc/${bin_prefix}:g' -i ${bin_prefix}_bb
	sed -e 's:\$$MISC/${bin_prefix}:/etc/${bin_prefix}:g' \
		-e 's:\.\/mk:mk:g' -i ${bin_prefix}_gen
	sed -e 's:\$$MISC/${bin_prefix}:/etc/${bin_prefix}:g' -i ${bin_prefix}_gpg
	sed -e 's|:\t\$${WORKDIR:=\$$(pwd)}|WORKDIR=/${prefix}/share/${PACKAGE}|' \
		-e 's:\$$BIN/fr_l1-amd64.bin::' -i misc/${bin_prefix}.conf
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)/$(PACKAGE)
	install -pm 644 misc/${bin_prefix}.conf $(sys_confdir)
	install -pm 755 ${bin_prefix} 		$(bindir)
	install -pm 755 ${bin_prefix}_bb 	$(bindir)
	install -pm 755 ${bin_prefix}_gen 	$(bindir)
	install -pm 755 ${bin_prefix}_gpg 	$(bindir)
	install -pm 755 init 			$(datadir)/$(PACKAGE)

install_sqfsd:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount 	$(svc_initdir)
	install -pm 644 sqfsd/sqfsdmount.conf 	$(svc_confdir)/sqfsdmount
	install -pm 755 sqfsd/sqfsd-rebuild 	$(bindir)/sdr

install_extras:
	install -pd $(datadir)/$(PACKAGE)/misc/share/gnupg
	install -pd $(datadir)/$(PACKAGE)/bin
	install -pm 644 bin/applets $(datadir)/$(PACKAGE)/bin
	install -pm 644 misc/share/gnupg/options.skel $(datadir)/$(PACKAGE)/misc/share/gnupg

postinstall:

uninstall:
	rm -f $(bindir)/${bin_prefix}
	rm -f $(bindir)/${bin_prefix}_bb
	rm -f $(bindir)/${bin_prefix}_gen
	rm -f $(bindir)/${bin_prefix}_gpg
	rm -f $(datadir)/init
	rm -f $(docdir)/${bin_prefix}.conf

uninstall_sqfsd:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

uninstall_extras:
	rm -f $(datadir)/$(PACKAGE)/bin/applets
	rm -f $(datadir)/$(PACKAGE)/misc/share/gnupg/options.skel

postuninstall:

