PACKAGE     = mkinitramfs-ll
VERSION     = $(shell grep Header init | awk '{print $$4}')

prefix      = /usr/local
bindir      = ${DESTDIR}${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS        = AUTHORS BUGS COPYING README.textile

MODULES     = zfs zram
SCRIPTS     = xcpio

all:

instal_all: install install_svc install_bash install_zsh

install:
	$(shell) install -pd $(datadir)/usr/lib/{mdev,$(PACKAGE)}
	install -pm 644 busybox.cfg       $(datadir)
	install -pm 755 init              $(datadir)
	install -pd                       $(datadir)/scripts
	$(shell) for script in scripts/$(SCRIPTS); do \
		install -pm 755 $${script}    $(datadir)/scripts; \
	done
	$(shell) find usr -name '.keep' -exec install -Dpm 644 '{}' $(datadir)/'{}' \;
	$(shell) for module in $(MODULES); do \
		for file in modules/$${module}*; do \
			install -Dpm644 $${file} $(datadir)/$${file}; done; done
	$(shell) install -pm 644 {,$(datadir)/}usr/lib/$(PACKAGE)/functions
	$(shell) install -Dpm644 {,$(datadir)/}usr/root/.gnupg/gpg.conf
	$(shell) install -pm 644 {,$(datadir)/}usr/etc/mdev.conf
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/ide_links
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/usbdev
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/usbdisk_link

install_bash:
	install -pd $(datadir)
	$(shell) sed -e 's:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g' \
		-e 's,\./,,g' -i autogen.bash busybox.bash gnupg.bash $(PACKAGE).bash
	install -pd $(sys_confdir)
	install -pd $(bindir)
	$(shell) install -pm 755 {autogen,busybox,gnupg}.bash -t $(datadir)
	install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	install -pm 755 $(PACKAGE).bash   $(bindir)
	install -pm 755 svc/sdr.bash      $(bindir)

install_zsh:
	install -pd $(datadir)
	$(shell) sed -e 's:$(PACKAGE).conf:/etc/$(PACKAGE).conf:g' \
		-e 's,\./,,g' -i autogen.zsh busybox.zsh gnupg.zsh $(PACKAGE).zsh
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

clean_all: unintsall uninstall_bash uninstall_zsh uninstall_svc

clean:
	$(shell) rm -f $(datadir)/{busybox.cfg,init,usr/etc/mdev.conf,xcpio}
	$(shell) rm -f $(datadir)/usr/{root/.gnupg/gpg.conf,share/gnupg/options.skel}
	$(shell) find ${datadir}/usr -name '.keep' -exec rm -f '{}' \;
	$(shell) for file in 3d-zfs.sh; do \
		rm -f $(datadir)/$(PACKAGE).d/$${file}; \
	done
	$(shell) rm -f $(datadir)/usr/lib/mdev/{ide_links,usbdev,usbdisk_link}
	$(shell) rm -f $(datadir)/usr/lib/$(PACKAGE)/{functions,init}.sh
	$(shell) rmdir $(datadir)/usr/{lib/{mdev,$(PACKAGE)},etc/$(PACKAGE){,.d}}
	$(shell) rmdir $(datadir)/usr/{lib,{,s}bin,root/{.gnupg,},etc/{splash,}}
	$(shell) rmdir $(datadir)/usr/{share/{consolefonts,keymaps,gnupg,},}

clean_bash:
	rm -f $(bindir)/$(PACKAGE).bash
	$(shell) rm -f $(datadir)/{autogen,busybox,gnupg}.bash
	rm -f $(sys_confdir)/$(PACKAGE).conf

clean_zsh:
	rm -f $(bindir)/$(PACKAGE).zsh
	$(shell) rm -f $(datadir)/{autogen,busybox,gnupg}.zsh
	rm -f $(sys_confdir)/$(PACKAGE).conf

clean_svc:
	rm -f $(svc_confdir)/sqfsdmount
	rm -f $(svc_initdir)/sqfsdmount

postclean:
