PACKAGE     = mkinitramfs-ll
VERSION     = $(shell grep Header init | awk '{print $4}')

prefix      = /usr/local
bindir      = ${DESTDIR}${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS        = AUTHORS COPYING README.textile KnownIssue

all: install install_svc install_bash install_zsh

install:
	install -pd $(datadir)/usr/lib/mdev
	install -pm 644 busybox.cfg       $(datadir)
	install -pm 755 init              $(datadir)
	install -pm 755 xcpio             $(datadir)
	$(shell) find usr -name '.keep' -exec install -Dpm 644 '{}' $(datadir)/'{}' \;
	$(shell) find $(PACKAGE).d -type f -exec install -Dp '{}' $(datadir)/'{}' \;
	install -pm 644 usr/etc/mdev.conf $(datadir)/usr/etc
	install -pm 755 usr/lib/mdev/ide_links    $(datadir)/usr/lib/mdev
	install -pm 755 usr/lib/mdev/usbdev       $(datadir)/usr/lib/mdev
	install -pm 755 usr/lib/mdev/usbdisk_link $(datadir)/usr/lib/mdev

install_bash:
	$(shell) sed -e "s:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g" -e 's,\./,,g' \
		-i autogen.bash busybox.bash gnupg.bash $(PACKAGE).bash
	install -pd $(sys_confdir)
	install -pd $(bindir)
	$(shell) install -pm 755 {autogen,busybox,gnupg}.bash -t $(datadir)
	install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	install -pm 755 $(PACKAGE).bash   $(bindir)
	install -pm 755 svc/sdr.bash      $(bindir)

install_zsh:
	$(shell) sed -e "s:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g" -e 's,\./,,g' \
		-i autogen.zsh busybox.zsh gnupg.zsh $(PACKAGE).zsh
	install -pd $(sys_confdir)
	install -pd $(bindir)
	$(shell) install -pm 755 {autogen,busybox,gnupg}.zsh -t $(datadir)
	install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	install -pm 755 $(PACKAGE).zsh    $(bindir)
	install -pm 755 svc/sdr.zsh       $(bindir)

install_svc:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 svc/sqfsdmount.initd $(svc_initdir)/sqfsdmount
	install -pm 644 svc/sqfsdmount.confd $(svc_confdir)/sqfsdmount

postinstall:

uall: unintsall uninstall_bash uninstall_zsh uninstall_svc

uninstall:
	rm -f $(datadir)/busybox.cfg
	rm -f $(datadir)/init
	$(shell) find ${datadir}/usr -name '.keep' -exec rm -f '{}' \;
	$(shell) rm -f usr/lib/mdev/{ide_links,usbdev,usbdisk_link}

uninstall_bash:
	rm -f $(bindir)/$(PACKAGE).bash
	$(shell) rm -f $(datadir)/{autogen,busybox,gnupg}.bash
	rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_zsh:
	rm -f $(bindir)/$(PACKAGE).zsh
	$(shell) rm -f $(datadir)/{autogen,busybox,gnupg}.zsh
	rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_svc:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postuninstall:
