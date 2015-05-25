PACKAGE     = mkinitramfs-ll
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

PREFIX      = /usr/local
SBINDIR     = $(PREFIX)/sbin
SYS_CONFDIR = /etc
SVC_CONFDIR = $(SYS_CONFDIR)/conf.d
SVC_INITDIR = $(SYS_CONFDIR)/init.d
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
	scripts/minimal.config \
	usr/lib/$(PACKAGE)/functions \
	usr/lib/$(PACKAGE)/helpers \
	usr/root/.gnupg/gpg.conf \
	usr/share/gnupg/options.skel
dist_SCRIPTS= \
	init \
	scripts/suspend \
	scripts/xcpio \
	usr/lib/mdev/ide_links \
	usr/lib/mdev/dm_link
DISTFILES   = $(dist_COMMON) $(dist_SCRIPTS)
.SECONDEXPANSION:
base_DIRS   = $(SBINDIR) $(SYS_CONFDIR) \
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

.PHONY: all install install-dir install-dist install-scripts-bash \
	install-common install-extra install-hooks install-scripts \
	install-scripts-zsh install-services install-all

all:

install-all: intsall install-scripts-bash install-scripts-zsh install-services
install: install-dir install-dist
install-dist: $(DISTFILES) install-common install-hooks
install-dir : $(keep_DIRS)
	$(MKDIR_P) $(base_DIRS:%=$(DESTDIR)%)
install-doc : $(dist_EXTRA)
	$(install_DATA) -D $(PACKAGE).1 $(DESTDIR)$(mandir)/man1/$(PACKAGE).1
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

install-scripts-%:
	$(install_SCRIPT) $(PACKAGE).$* svc/sdr.$* $(DESTDIR)$(SBINDIR)
	$(install_DATA)   $(PACKAGE).conf      $(DESTDIR)$(SYS_CONFDIR)
	ln -f -s $(PACKAGE).$* $(DESTDIR)$(SBINDIR)/mkinitramfs
	ln -f -s sdr.$* $(DESTDIR)$(SBINDIR)/sdr
	sed -e 's:"\$${PWD}"/usr:${prefix}/share/"$${PKG[name]}"/usr:g' \
	    -e 's:"\$${PKG\[name\]}".conf:$(SYS_CONFDIR)/"$${PKG[name]}".conf:g' \
	    -i $(DESTDIR)$(SBINDIR)/$(PACKAGE).$*
install-%-svc:
	$(MKDIR_P) $(DESTDIR)$(SVC_CONFDIR) $(DESTDIR)$(SVC_INITDIR)
	$(install_SCRIPT) svc/$*.initd $(DESTDIR)$(SVC_INITDIR)/$*
	$(install_DATA)   svc/$*.confd $(DESTDIR)$(SVC_CONFDIR)/$*

.PHONY: uninstall uninstall-scripts-bash uninstall-scripts-zsh uninstall-squashd \
	uninstall-zram

uninstall-all: uninstall uninstall-services \
	uninstall-scripts-bash uninstall-scripts-zsh
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
		$(dist_EXTRA:%=$(DESTDIR)$(DOCDIR)/$(PACKAGE)-$(VERSION)/%)
uninstall-services: uninstall-squashdir-svc \
	uninstall-zram-svc uninstall-tmpdir-svc
uninstall-scripts-%:
	rm -f $(DESTDIR)$(SYS_CONFDIR)/$(PACKAGE).conf \
		$(DESTDIR)$(SBINDIR)/$(PACKAGE).$* \
		$(DESTDIR)$(SBINDIR)/sdr.$* \
		$(DESTDIR)$(SBINDIR)/mkinitramfs \
		$(DESTDIR)$(SBINDIR)/sdr
uninstall-%-svc:
	rm -f $(DESTDIR)$(SVC_CONFDIR)/$* $(DESTDIR)$(SVC_INITDIR)/$*
	-rmdir $(DESTDIR)$(SVC_CONFDIR) $(DESTDIR)$(SVC_INITDIR)

.PHONY: clean

clean:

