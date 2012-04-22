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

DOCS=AUTHORS COPYING README ChangeLog KnownIssue

all: install_init install_svcsquash install_scripts_zsh

install_init
	install -pd $(datadir)
	install -pm 755 init                   $(datadir)

install_scripts_zsh:
	sed -e 's:\./${bin_prefix}:${bin_prefix}:g' \
		-e 's:${bin_prefix}.conf:/etc/${bin_prefix}.conf:g' -i ${bin_prefix}*.zsh
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 644 ${bin_prefix}.conf.zsh $(sys_confdir)
	install -pm 755 ${bin_prefix}.zsh      $(bindir)
	install -pm 755 ${bin_prefix}.bb.zsh   $(bindir)
	install -pm 755 ${bin_prefix}.gen.zsh  $(bindir)
	install -pm 755 ${bin_prefix}.gpg.zsh  $(bindir)
	install -pm 755 sqfsd/sdr.zsh          $(bindir)

install_svcsquash:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsd/sqfsdmount.initd  $(svc_initdir)/sqfsdmount
	install -pm 644 sqfsd/sqfsdmount.confd  $(svc_confdir)/sqfsdmount

postinstall:

uall: unintsall_init uninstall_scripts_zsh  uninstall_svcsquash

uninstall_init:
	rm -f $(datadir)/init

uninstall_scripts_zsh:
	rm -f $(bindir)/${bin_prefix}.zsh
	rm -f $(bindir)/${bin_prefix}.bb.zsh
	rm -f $(bindir)/${bin_prefix}.gen.zsh
	rm -f $(bindir)/${bin_prefix}.gpg.zsh
	rm -f $(sys_confdir)/${bin_prefix}.conf.zsh

uninstall_svcsquash:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall:
