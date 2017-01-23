PACKAGE     = mkinitramfs-ll
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

PREFIX      = /usr/local
SBINDIR     = $(PREFIX)/sbin
SYSCONFDIR = /etc
SVCCONFDIR = $(SYSCONFDIR)/conf.d
SVCINITDIR = $(SYSCONFDIR)/init.d
DATADIR     = $(PREFIX)/share
DOCDIR      = $(DATADIR)/doc
MANDIR      = $(DATADIR)/man

INSTALL     = install
install_SCRIPT = $(INSTALL) -m 755
install_DATA   = $(INSTALL) -m 644
MKDIR_P     = mkdir -p

dist_EXTRA  = \
	AUTHORS \
	BUGS \
	COPYING \
	README.md \
	ChangeLog
dist_HOOKS  = \
	bcache \
	undo-bcache \
	btrfs \
	zfs \
	mkswap-zfs\
	zram
dist_COMMON = \
	usr/etc/mdev.conf \
	usr/etc/group \
	usr/etc/modprobe.d/zfs.conf \
	scripts/minimal.applets \
	usr/lib/$(PACKAGE)/functions \
	usr/lib/$(PACKAGE)/helpers \
	usr/root/.gnupg/gpg.conf \
	usr/share/gnupg/options.skel
dist_SCRIPTS= \
	init \
	scripts/busybox.sh \
	scripts/gnupg.sh \
	scripts/suspend \
	scripts/xcpio \
	usr/lib/mdev/ide_links \
	usr/lib/mdev/dm_link
DISTFILES   = $(dist_COMMON) $(dist_SCRIPTS)
.SECONDEXPANSION:
base_DIRS   = $(SBINDIR) $(SYSCONFDIR) \
	$(MANDIR)/man5 $(MANDIR)/man8 \
	$(DATADIR)/$(PACKAGE) $(DOCDIR)/$(PACKAGE)-$(VERSION)
keep_DIRS   = \
	hooks scripts \
	usr/bin usr/sbin \
	usr/etc/$(PACKAGE) \
	usr/etc/splash usr/etc/modprobe.d \
	usr/lib/mdev usr/lib/$(PACKAGE) \
	usr/root/.gnupg usr/share/gnupg \
	usr/share/consolefonts \
	usr/share/keymaps
DISTDIRS    = $(base_DIRS) $(keep_DIRS)

.FORCE:

all:

install-all: install install-services install-sh-scripts
install: install-dir install-dist
install-dist: $(DISTFILES) install-doc install-hooks
		sed -e 's:\$${PWD}.*/usr:$(DATADIR)/$(PACKAGE)/usr:g' \
			-i $(DESTDIR)$(DATADIR)/$(PACKAGE)/scripts/*.sh
install-dir : $(keep_DIRS)
	$(MKDIR_P) $(base_DIRS:%=$(DESTDIR)%)
install-doc : install-extra
	for man in man5/$(PACKAGE).5 man8/$(PACKAGE).8; do \
		sed -e 's|@SYSCONFDIR@|$(SYSCONFDIR)|g' -e 's|@DATADIR@|$(DATADIR)|g' \
			$${man#*/} >$(DESTDIR)$(MANDIR)/$${man}; \
	done
install-services: install-squashdir-svc install-zram-svc install-tmpdir-svc

$(dist_COMMON): .FORCE
	$(install_DATA) $@ $(DESTDIR)$(DATADIR)/$(PACKAGE)/$@
install-extra:
	$(install_DATA) $(dist_EXTRA) $(DESTDIR)$(DOCDIR)/$(PACKAGE)-$(VERSION)
install-hooks:
	$(install_DATA) $(dist_HOOKS:%=hooks/%) $(DESTDIR)$(DATADIR)/$(PACKAGE)/hooks
$(dist_SCRIPTS): .FORCE
	$(install_SCRIPT) $@ $(DESTDIR)$(DATADIR)/$(PACKAGE)/$@
$(keep_DIRS): .FORCE
	$(MKDIR_P) $(DESTDIR)$(DATADIR)/$(PACKAGE)/$@
	echo     > $(DESTDIR)$(DATADIR)/$(PACKAGE)/$@/.keep-$(@F)-dir

install-%-scripts:
	$(install_SCRIPT) $(PACKAGE).$* svc/sdr.$* $(DESTDIR)$(SBINDIR)
	if test $* = sh; then \
		$(install_DATA) $(PACKAGE).conf.in-sh $(DESTDIR)$(SYSCONFDIR)/$(PACKAGE).conf; \
		sed -e 's:\$${PWD}.*/usr:$(DATADIR)/\$${package}/usr:g' \
		    -e 's:\./\$${package}.conf:$(SYSCONFDIR)/\$${package}.conf:g' \
			-i $(DESTDIR)$(SBINDIR)/$(PACKAGE).sh; \
	else \
		$(install_DATA) $(PACKAGE).conf.in    $(DESTDIR)$(SYSCONFDIR)/$(PACKAGE).conf; \
		sed -e 's:"\$${PWD}"/usr:$(DATADIR)/$${PKGINFO[name]}/usr:g' \
		    -e 's:"\$${PKGINFO\[name\]}".conf:$(SYSCONFDIR)/$${PKGINFO[name]}.conf:g' \
			-i $(DESTDIR)$(SBINDIR)/$(PACKAGE).$*; \
	fi
	ln -f -s $(PACKAGE).$* $(DESTDIR)$(SBINDIR)/mkinitramfs
	ln -f -s sdr.$* $(DESTDIR)$(SBINDIR)/sdr
install-%-svc:
	$(MKDIR_P) $(DESTDIR)$(SVCCONFDIR) $(DESTDIR)$(SVCINITDIR)
	$(install_SCRIPT) svc/$*.initd $(DESTDIR)$(SVCINITDIR)/$*
	$(install_DATA)   svc/$*.confd $(DESTDIR)$(SVCCONFDIR)/$*

uninstall-all: uninstall uninstall-services uninstall-sh-scripts
uninstall: uninstall-dist
	for dir in $(keep_DIRS); do \
		rm -f $(DESTDIR)$(DATADIR)/$(PACKAGE)/$${dir}/.keep-*-dir; \
		rmdir $(DESTDIR)$(DATADIR)/$(PACKAGE)/$${dir}; \
	done
	-for dir in usr/etc usr/lib usr/root usr/share usr; do \
		rmdir $(DESTDIR)$(DATADIR)/$(PACKAGE)/$${dir}; \
	done
	-rmdir $(base_DIRS:%=$(DESTDIR)%)
uninstall-dist: uninstall-doc
	rm -f $(dist_COMMON:%=$(DESTDIR)$(DATADIR)/$(PACKAGE)/%) \
		$(dist_SCRIPTS:%=$(DESTDIR)$(DATADIR)/$(PACKAGE)/%) \
		$(dist_HOOKS:%=$(DESTDIR)$(DATADIR)/$(PACKAGE)/hooks/%)
uninstall-doc:
	rm -f $(DESTDIR)$(MANDIR)/man1/$(PACKAGE).1 \
		$(DESTDIR)$(MANDIR)/man8/$(PACKAGE).8 \
		$(dist_EXTRA:%=$(DESTDIR)$(DOCDIR)/$(PACKAGE)-$(VERSION)/%)
uninstall-services: uninstall-squashdir-svc \
	uninstall-zram-svc uninstall-tmpdir-svc
uninstall-%-scripts:
	rm -f $(DESTDIR)$(SYSCONFDIR)/$(PACKAGE).conf \
		$(DESTDIR)$(SBINDIR)/$(PACKAGE).$* \
		$(DESTDIR)$(SBINDIR)/sdr.$* \
		$(DESTDIR)$(SBINDIR)/mkinitramfs \
		$(DESTDIR)$(SBINDIR)/sdr
uninstall-%-svc:
	rm -f $(DESTDIR)$(SVCCONFDIR)/$* $(DESTDIR)$(SVCINITDIR)/$*
	-rmdir $(DESTDIR)$(SVCCONFDIR) $(DESTDIR)$(SVCINITDIR)

.PHONY: clean

clean:

