PACKAGE     = mkinitramfs-ll
VERSION     = $(shell grep Header init | awk '{print $$4}')

prefix      = /usr/local
bindir      = ${DESTDIR}${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS        = AUTHORS BUGS COPYING README.textile ChangeLog

MODULES     = zfs zram
SCRIPTS     = xcpio

all:

instal_all: install install_svc install_bash install_zsh

install:
	$(shell) install -pd $(datadir)/usr/lib/{mdev,$(PACKAGE)}
	$(shell) install -pd $(datadir)/usr/etc/{splash,$(PACKAGE)}
	$(shell) install -pm 755 init        $(datadir)
	$(shell) install -pd                 $(datadir)/scripts
	$(shell) install -pm 644 busybox.cfg $(datadir)/scripts
	$(shell) for script in $(SCRIPTS); do \
		install -pm 755 scripts/$${script}    $(datadir)/scripts; done
	$(shell) find usr -name '.keep' -exec install -Dpm 644 '{}' $(datadir)/'{}' \;
	$(shell) for module in $(MODULES); do \
		for file in modules/*$${module}*; do \
			install -Dpm644 $${file} $(datadir)/usr/lib/$(PACKAGE)/$${file}; \
		done; done
	$(shell) install -pm 644 {,$(datadir)/}usr/lib/$(PACKAGE)/functions
	$(shell) install -Dpm644 {,$(datadir)/}usr/root/.gnupg/gpg.conf
	$(shell) install -pm 644 {,$(datadir)/}usr/etc/mdev.conf
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/ide_links
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/usbdev
	$(shell) install -pm 755 {,$(datadir)/}usr/lib/mdev/usbdisk_link

install_bash:
	$(shell) install -pd $(datadir)
	$(shell) sed -e 's:"$${PWD}"/usr:${prefix}/share/$(PACKAGE)/usr:g' \
		     -i busybox.bash gnupg.bash $(PACKAGE).bash
	$(shell) install -pd $(sys_confdir)
	$(shell) install -pd $(bindir)
	$(shell) install -pm 755 {busybox,gnupg}.bash -t $(datadir)/scripts
	$(shell) install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	$(shell) install -pm 755 $(PACKAGE).bash   $(bindir)
	$(shell) install -pm 755 svc/sdr.bash      $(bindir)

install_zsh:
	$(shell) install -pd $(datadir)
	$(shell) sed -e 's:$${PWD}/usr:${prefix}/share/$(PACKAGE)/usr:g' \
		     -i busybox.zsh gnupg.zsh $(PACKAGE).zsh
	$(shell) install -pd $(sys_confdir)
	$(shell) install -pd $(bindir)
	$(shell) install -pm 755 {busybox,gnupg}.zsh -t $(datadir)/scripts
	$(shell) install -pm 644 $(PACKAGE).conf   $(sys_confdir)
	$(shell) install -pm 755 $(PACKAGE).zsh    $(bindir)
	$(shell) install -pm 755 svc/sdr.zsh       $(bindir)

install_svc:
	$(shell) install -pd $(svc_confdir)
	$(shell) install -pd $(svc_initdir)
	$(shell) install -pm 755 svc/sqfsdmount.initd $(svc_initdir)/sqfsdmount
	$(shell) install -pm 644 svc/sqfsdmount.confd $(svc_confdir)/sqfsdmount

postinstall:

uninstall_all: unintsall uninstall_bash uninstall_zsh uninstall_svc

uninstall:
	$(shell) rm -f $(datadir)/{init,usr/etc/mdev.conf,scripts/{busybox.cfg,xcpio}}
	$(shell) rm -f $(datadir)/usr/{root/.gnupg/gpg.conf,share/gnupg/options.skel}
	$(shell) find ${datadir}/usr -name '.keep' -exec rm -f '{}' \;
	$(shell) for file in $(MODULES); do \
		rm -f $(datadir)/usr/lib/$(PACKAGE)/*$${file}*; done
	$(shell) rm -f $(datadir)/usr/lib/mdev/{ide_links,usbdev,usbdisk_link}
	$(shell) rm -f $(datadir)/usr/lib/$(PACKAGE)/functions
	$(shell) rmdir $(datadir)/usr/{lib/{mdev,$(PACKAGE)},etc/{$(PACKAGE),splash}}
	$(shell) rmdir $(datadir)/usr/{lib,{,s}bin,root/{.gnupg,},etc/{$(PACKAGE),splash,}}
	$(shell) rmdir $(datadir)/usr/{share/{consolefonts,keymaps,gnupg,},}

uninstall_bash:
	$(shell) rm -f $(bindir)/$(PACKAGE).bash
	$(shell) rm -f $(datadir)/scripts/{busybox,gnupg}.bash
	$(shell) rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_zsh:
	$(shell) rm -f $(bindir)/$(PACKAGE).zsh
	$(shell) rm -f $(datadir)/scripts/{busybox,gnupg}.zsh
	$(shell) rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_svc:
	$(shell) rm -f $(svc_confdir)/sqfsdmount
	$(shell) rm -f $(svc_initdir)/sqfsdmount

clean:
