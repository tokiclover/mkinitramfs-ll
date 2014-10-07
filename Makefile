PACKAGE     = mkinitramfs-ll
VERSION     = $(sed -nre '5,s/.*: ([0-9].*) .*/\1/p' init)

prefix      = /usr/local
bindir      = ${DESTDIR}${prefix}/sbin
sys_confdir	= ${DESTDIR}/etc
svc_confdir	= ${sys_confdir}/conf.d
svc_initdir	= ${sys_confdir}/init.d
datadir	    = ${DESTDIR}${prefix}/share/$(PACKAGE)
docdir      = ${DESTDIR}${prefix}/share/doc/$(PACKAGE)-${VERSION}

DOCS        = AUTHORS BUGS COPYING README.textile ChangeLog

HOOKS       = bcache zfs zram
FILES       = usr/etc/mdev.conf usr/etc/$(PACKAGE)/minimal.applets \
			  usr/lib/$(PACKAGE)/functions scripts/busybox-minimal.config \
			  usr/root/.gnupg/gpg.conf usr/share/gnupg/options.skel
EXEC_FILES  = init scripts/xcpio \
			  usr/lib/mdev/ide_links usr/lib/mdev/usbdev usr/lib/mdev/usbdisk_link


all:

instal_all: install install_aufs_squashfs install_bash install_zsh install_zram

install:
	install -pd $(datadir)/usr/etc/$(PACKAGE)
	install -pd $(datadir)/usr/lib/$(PACKAGE)
	install -pd $(datadir)/usr/etc/splash
	install -pd $(datadir)/usr/lib/mdev
	install -pd $(datadir)/usr/share/gnupg
	install -pd $(datadir)/usr/root/.gnupg
	install -pd $(datadir)/modules
	install -pd $(datadir)/scripts
	find . -name '.keep*' -exec install -Dpm 644 '{}' $(datadir)/'{}' \;
	$(shell) for file in $(EXEC_FILES); do \
		install -pm 755 $${file} $(datadir)/$${file}; \
	done
	$(shell) for file in $(FILES); do \
		install -pm 644 $${file} $(datadir)/$${file}; \
	done
	$(shell) for module in $(HOOKS); do \
		for file in modules/*$${module}*; do \
			install -pm 644 $${file} $(datadir)/$${file}; \
		done; done

install_bash:
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)/scripts
	sed -e 's:"$${PWD}"/usr:${prefix}/share/"$${PKG[name]}"/usr:g' \
	    -e 's:"$${PKG[name]}".conf:/etc/"$${PKG[name]}".conf:g' \
	    -i scripts/busybox.bash scripts/gnupg.bash $(PACKAGE).bash
	install -pm 755 scripts/busybox.bash $(datadir)/scripts
	install -pm 755 scripts/gnupg.bash   $(datadir)/scripts
	install -pm 644 $(PACKAGE).conf      $(sys_confdir)
	install -pm 755 $(PACKAGE).bash      $(bindir)
	install -pm 755 svc/sdr.bash         $(bindir)

install_zsh:
	install -pd $(sys_confdir)
	install -pd $(bindir)
	install -pd $(datadir)/scripts
	sed -e 's:$${PWD}/usr:${prefix}/share/$${PKG[name]}/usr:g' \
	    -e 's:"$${PKG[name]}".conf:/etc/$${PKG[name]}.conf:g' \
	    -i scripts/busybox.zsh scripts/gnupg.zsh $(PACKAGE).zsh
	install -pm 755 scripts/busybox.zsh $(datadir)/scripts
	install -pm 755 scripts/gnupg.zsh   $(datadir)/scripts
	install -pm 644 $(PACKAGE).conf     $(sys_confdir)
	install -pm 755 $(PACKAGE).zsh      $(bindir)
	install -pm 755 svc/sdr.zsh         $(bindir)

install_aufs_squashfs:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 svc/squashdir-mount.initd $(svc_initdir)/squashdir-mount
	install -pm 644 svc/squashdir-mount.confd $(svc_confdir)/squashdir-mount

install_zram:
	install -pd $(svc_confdir)
	install -pd $(svc_initdir)
	install -pm 755 svc/zram.initd $(svc_initdir)/zram
	install -pm 644 svc/zram.confd $(svc_confdir)/zram
	install -pm 755 svc/zramdir.initd $(svc_initdir)/zramdir
	install -pm 644 svc/zramdir.confd $(svc_confdir)/zramdir

postinstall:

uninstall_all: unintsall uninstall_bash uninstall_zsh uninstall_aufs_squashfs uninstall_zram

uninstall:
	find ${datadir}/usr -name '*.keep*' -exec rm -f '{}' \;
	$(shell) for file in $(EXEC_FILES); do \
		rm -f $(datadir)/$${file}; \
	done
	$(shell) for file in $(FILES); do \
		rm -f $(datadir)/$${file}; \
	done
	$(shell) for file in $(HOOKS); do \
		rm -f $(datadir)/modules/*$${file}*; \
	done
	rmdir $(datadir)/usr/etc/$(PACKAGE)
	rmdir $(datadir)/usr/lib/$(PACKAGE)
	rmdir $(datadir)/usr/etc/splash
	rmdir $(datadir)/usr/lib/mdev
	rmdir $(datadir)/scripts
	rmdir $(datadir)/usr/lib
	rmdir $(datadir)/usr/bin
	rmdir $(datadir)/usr/sbin
	rmdir $(datadir)/usr/.root/gnupg
	rmdir $(datadir)/usr/.root
	rmdir $(datadir)/usr/share/consolefonts
	rmdir $(datadir)/usr/share/gnupg
	rmdir $(datadir)/usr/share/keymaps

uninstall_bash:
	rm -f $(bindir)/$(PACKAGE).bash
	rm -f $(datadir)/scripts/busybox.bash
	rm -f $(datadir)/scripts/gnupg.bash
	rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_zsh:
	rm -f $(bindir)/$(PACKAGE).zsh
	rm -f $(datadir)/scripts/busybox.zsh
	rm -f $(datadir)/scripts/gnupg.zsh
	rm -f $(sys_confdir)/$(PACKAGE).conf

uninstall_aufs_squashfs:
	rm -f $(svc_confdir)/squashdir-mount
	rm -f $(svc_initdir)/squashdir-mount

uninstall_zram:
	rm -f $(svc_confdir)/zram
	rm -f $(svc_initdir)/zram

clean:
