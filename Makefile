PACKAGE     = mkinitramfs-ll
VERSION     = $(shell grep Header init | awk '{print $4}')

prefix      = /usr/local
bindir      = ${DESTDIR}${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS=AUTHORS COPYING README.textile ChangeLog KnownIssue

all: install_init install_sqfsd_svc install_scripts_bash install_scripts_zsh

install:
	install -pd $(datadir)
	install -pm 644 busybox.cfg       $(datadir)
	install -pm 755 init              $(datadir)
	for file in $(shell find usr -name '.keep'); do \
		install -Dpm644 $${file} $(datadir)/$${file}; \
	done

install_bash:
	sed -e 's:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g' \
		-i autogen.zsh busybox.zsh gnupg.zsh $(PACKAGE).zsh
	sed -e 's:busybox.bash:$(PACKAGE)-busybox.bash:' \
		-e 's:gnupg.bash:$(PACKAGE)-gnupg.bash:' -e 's:\./::' \
		-i autogen.bash
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 755 autogen.bash      $(bindir)/$(PACKAGE)-autogen.bash
	install -pm 755 busybox.bash      $(bindir)/$(PACKAGE)-busybox.bash
	install -pm 755 gnupg.bash        $(bindir)/$(PACKAGE)-gnupg.bash
	install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	install -pm 755 $(PACKAGE).bash   $(bindir)
	install -pm 755 sqfsdsvc/sdr.bash $(bindir)

install_zsh:
	sed -e 's:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g' \
		-i autogen.bash busybox.bash gnupg.bash $(PACKAGE).zsh
	sed -e 's:busybox.zsh:$(PACKAGE)-busybox.zsh:' \
		-e 's:gnupg.zsh:$(PACKAGE)-gnupg.zsh:' -e 's:\./::' \
		-i autogen.zsh
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pm 755 autogen.zsh       $(bindir)/$(PACKAGE)-autogen.zsh
	install -pm 755 busybox.zsh       $(bindir)/$(PACKAGE)-busybox.zsh
	install -pm 755 gnupg.zsh         $(bindir)/$(PACKAGE)-gnupg.zsh
	install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	install -pm 755 $(PACKAGE).zsh    $(bindir)
	install -pm 755 sqfsdsvc/sdr.zsh  $(bindir)

install_svc:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 sqfsdsvc/sqfsdmount.initd $(svc_initdir)/sqfsdmount
	install -pm 644 sqfsdsvc/sqfsdmount.confd $(svc_confdir)/sqfsdmount

postinstall:

uall: unintsall uninstall_bash uninstall_zsh uninstall_svc

uninstall:
	rm -f $(datadir)/init

uninstall_bash:
	rm -f $(bindir)/$(PACKAGE).bash
	rm -f $(bindir)/$(PACKAGE)-busybox.bash
	rm -f $(bindir)/$(PACKAGE)-autogen.bash
	rm -f $(bindir)/$(PACKAGE)-gnupg.bash

uninstall_zsh:
	rm -f $(bindir)/$(PACKAGE).zsh
	rm -f $(bindir)/$(PACKAGE)-busybox.zsh
	rm -f $(bindir)/$(PACKAGE)-autoen.zsh
	rm -f $(bindir)/$(PACKAGE)-gnupg.zsh

uninstall_svc:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall:
