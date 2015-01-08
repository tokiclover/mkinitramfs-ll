PACKAGE     = mkinitramfs-ll
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

prefix      = /usr/local
sbindir     = $(prefix)/sbin
sysconfdir  = /etc
svcconfdir  = $(sysconfdir)/conf.d
svcinitdir  = $(sysconfdir)/init.d
datadir     = $(prefix)/share/$(PACKAGE)
docdir      = $(prefix)/share/doc/$(PACKAGE)-${VERSION}
mandir      = $(prefix)/share/man

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
	zfs \
	mkswap-zfs\
	zram
dist_COMMON = \
	usr/etc/mdev.conf \
	usr/etc/$(PACKAGE)/minimal.applets \
	usr/etc/group \
	usr/etc/modprobe.d/zfs.conf \
	scripts/busybox-minimal.config \
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
DISTFILES   = $(dist_COMMON) $(dist_SCRIPTS) $(dist_HOOKS) $(dist_EXTRA)
.SECONDEXPANSION:
base_DIRS   = $(sbindir) $(sysconfdir) $(datadir) $(docdir)
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

.PHONY: all base keep install install-doc install-dist install-bash install-zsh \
	install-services install-all

all:

install-all: install install-services install-bash install-zsh
install: install-dir install-dist
install-dist: $(DISTFILES)
install-dir : $(keep_DIRS)
	$(MKDIR_P) $(base_DIRS:%=$(DESTDIR)%)
install-doc : $(dist_EXTRA)
	$(install_DATA) -D $(PACKAGE).1 $(DESTDIR)$(mandir)/man1/$(PACKAGE).1
	$(install_DATA) -D $(PACKAGE).8 $(DESTDIR)$(mandir)/man8/$(PACKAGE).8
install-services: install-squashdir-mount-svc \
	install-zram-svc install-tmpdir-svc

$(dist_COMMON): .FORCE
	$(install_DATA) $@ $(DESTDIR)$(datadir)/$@
$(dist_EXTRA): .FORCE
	$(install_DATA) $@ $(DESTDIR)$(docdir)/$@
$(dist_HOOKS): .FORCE
	$(install_DATA) hooks/$@ $(DESTDIR)$(datadir)/hooks/$@
$(dist_SCRIPTS): .FORCE
	$(install_SCRIPT) $@ $(DESTDIR)$(datadir)/$@
$(keep_DIRS): .FORCE
	$(MKDIR_P) $(DESTDIR)$(datadir)/$@
	echo     > $(DESTDIR)$(datadir)/$@/.keep-$(@F)-dir

install-scripts-%sh:
	sed -e 's:"\$${PWD}"/usr:${prefix}/share/"$${PKG[name]}"/usr:g' \
	    -e 's:"\$${PKG\[name\]}".conf:/etc/"$${PKG[name]}".conf:g' \
	    -i scripts/busybox.$*sh scripts/gnupg.$*sh $(PACKAGE).$*sh
	$(install_SCRIPT) scripts/busybox.$*sh $(DESTDIR)$(datadir)/scripts
	$(install_SCRIPT) scripts/gnupg.$*sh   $(DESTDIR)$(datadir)/scripts
	$(install_SCRIPT) $(PACKAGE).$*sh      $(DESTDIR)$(sbindir)
	$(install_SCRIPT) svc/sdr.$*sh         $(DESTDIR)$(sbindir)
	$(install_DATA)   $(PACKAGE).conf      $(DESTDIR)$(sysconfdir)
	ln -f -s $(PACKAGE).$*sh    $(DESTDIR)$(sbindir)/$(PACKAGE)
	ln -f -s sdr.$*sh           $(DESTDIR)$(sbindir)/sdr
install-%-svc:
	$(MKDIR_P) $(DESTDIR)$(svcconfdir)
	$(MKDIR_P) $(DESTDIR)$(svcinitdir)
	$(install_SCRIPT) svc/$*.initd $(DESTDIR)$(svcinitdir)/$*
	$(install_DATA)   svc/$*.confd $(DESTDIR)$(svcconfdir)/$*

.PHONY: unintsall uninstall-bash uninstall-zsh uninstall-squashd uninstall-zram

uninstall-all: uninstall-bash unintsall-doc uninstall-zsh uninstall-services unintsall
uninstall:
	rm -f $(DESTDIR)$(sysconfdir)/$(PACKAGE).conf
	rm -f $(dist_COMMON:%=$(DESTDIR)$(datadir)/%)
	rm -f $(dist_SCRIPTS:%=$(DESTDIR)$(datadir)/%)
	rm -f $(dist_HOOKS:%=$(DESTDIR)$(datadir)/hooks/%)
	for dir in $(keep_DIRS); do \
		rm -f $(DESTDIR)$(datadir)/$${dir}/.keep-*-dir; \
		rmdir $(DESTDIR)$(datadir)/$${dir}; \
	done
	for dir in usr/etc usr/lib usr/root usr/share usr; do \
		rmdir $(DSTDIR)$(datadir)/$${dir}; \
	done
	-rmdir $(base_DIRS:%=$(DESTDIR)%)
uninstall-doc:
	rm -f $(DESTDIR)$(mandir)/man1/$(PACKAGE).1
	rm -f $(DESTDIR)$(mandir)/man8/$(PACKAGE).8
	rm -f $(dist_EXTRA:%=$(DESTDIR)$(docdir)/%)
uninstall-services: uninstall-squashdir-mount-svc \
	uninstall-zram-svc uninstall-tmpdir-svc
uninstall-scripts-%sh:
	rm -f $(DESTDIR)$(sbindir)/$(PACKAGE).$*sh
	rm -f $(DESTDIR)$(datadir)/scripts/busybox.$*sh
	rm -f $(DESTDIR)$(datadir)/scripts/gnupg.$*sh
	rm -f $(DESTDIR)$(sbindir)/svc/sdr.$*sh
uninstall-%-svc:
	rm -f $(DESTDIR)$(svcconfdir)/$*
	rm -f $(DESTDIR)$(svcinitdir)/$*
	-rmdir $(DESTDIR)$(svcconfdir)
	-rmdir $(DESTDIR)$(svcinitdir)

.PHONY: clean

clean:

