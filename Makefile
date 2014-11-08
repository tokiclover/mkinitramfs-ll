-include force.mk

PACKAGE     = mkinitramfs-ll
VERSION     = $(shell sed -nre '3s/(.*):/\1/p' ChangeLog)

prefix      = /usr/local
sbindir     = $(prefix)/sbin
sysconfdir  = /etc
svcconfdir  = $(sysconfdir)/conf.d
svcinitdir  = $(sysconfdir)/init.d
datadir	    = $(prefix)/share/$(PACKAGE)
docdir      = $(prefix)/share/doc/$(PACKAGE)-${VERSION}

INSTALL     = install
install_SCRIPT = $(INSTALL) -m 755
install_DATA   = $(INSTALL) -m 644
MKDIR_P     = mkdir -p

dist_EXTRA  = \
	AUTHORS \
	BUGS \
	COPYING \
	README.textile \
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

.PHONY: all base keep install install-doc install-dist install-bash install-zsh \
	install-zram install-squashd install-all

all:

instal-all: install install-squashd install-bash install-zsh install-zram
install: install-dir install-dist

install-dist: $(DISTFILES)
install-dir : $(DISTDIRS)
install-doc : $(dist_EXTRA)

$(dist_COMMON): .FORCE
	$(install_DATA) $@ $(DESTDIR)$(datadir)/$@
$(dist_EXTRA): .FORCE
	$(install_DATA) $@ $(DESTDIR)$(docdir)/$@
$(dist_HOOKS): .FORCE
	$(install_DATA) hooks/$@ $(DESTDIR)$(datadir)/hooks/$@
$(dist_SCRIPTS): .FORCE
	$(install_SCRIPT) $@ $(DESTDIR)$(datadir)/$@
$(base_DIRS): .FORCE
	$(MKDIR_P) $(DESTDIR)$@
$(keep_DIRS): .FORCE
	$(MKDIR_P) $(DESTDIR)$(datadir)/$@
	echo     > $(DESTDIR)$(datadir)/$@/.keep-$(@F)-dir

install-bash: install-scripts-bash
install-zsh : install-scripts-zsh
install-scripts-%sh:
	sed -e 's:"$${PWD}"/usr:${prefix}/share/"$${PKG[name]}"/usr:g' \
	    -e 's:"$${PKG\[name\]}".conf:/etc/"$${PKG[name]}".conf:g' \
	    -i scripts/busybox.$*sh scripts/gnupg.$*sh $(PACKAGE).$*sh
	$(install_SCRIPT) scripts/busybox.$*sh $(DESTDIR)$(datadir)/scripts
	$(install_SCRIPT) scripts/gnupg.$*sh   $(DESTDIR)$(datadir)/scripts
	$(install_SCRIPT) $(PACKAGE).$*sh      $(DESTDIR)$(sbindir)
	$(install_SCRIPT) svc/sdr.$*sh         $(DESTDIR)$(sbindir)
install-squashd: install-squashdir-mount-svc
install-zram: install-zram-svc install-zramdir-svc
install-%-svc:
	$(MKDIR_P) $(DESTDIR)$(svcconfdir)
	$(MKDIR_P) $(DESTDIR)$(svcinitdir)
	$(install_SCRIPT) svc/$*.initd $(DESTDIR)$(svcinitdir)/$*
	$(install_DATA)   svc/$*.confd $(DESTDIR)$(svcconfdir)/$*

.PHONY: unintsall uninstall-bash uninstall-zsh uninstall-squashd uninstall-zram

uninstall-all: uninstall-bash uninstall-zsh uninstall-squashd uninstall-zram unintsall

uninstall:
	rm -f $(DESTDIR)$(sysconfdir)/$(PACKAGE).conf
	for file in $(dist_EXTRA); do \
		rm -f $(DESTDIR)$(docdir)/$${file}; \
	done
	for file in $(dist_COMMON) $(dist_SCRIPTS); do \
		rm -f $(DESTDIR)$(datadir)/$${file}; \
	done
	for file in $(dist_HOOKS); do \
		rm -f $(DESTDIR)$(datadir)/hooks/*$${file}*; \
	done
	for dir in $(DISTDIRS); do \
		rmdir $(DESTDIR)/$${dir}; \
	done
uninstall-bash: uninstall-scripts-bash
uninstall-zsh : uninstall-scripts-zsh
uninstall-scripts-%sh:
	rm -f $(DESTDIR)$(sbindir)/$(PACKAGE).$*sh
	rm -f $(DESTDIR)$(datadir)/scripts/busybox.$*sh
	rm -f $(DESTDIR)$(datadir)/scripts/gnupg.$*sh
	rm -f $(DESTDIR)$(sbindir)/svc/sdr.$*sh
uninstall-squashd: uninstall-squashdir-mount-svc
uninstall-squashd: uninstall-zram-svc uninstall-zramdir-svc
uninstall-%-svc:
	rm -f $(DESTDIR)$(svcconfdir)/$*
	rm -f $(DESTDIR)$(svcinitdir)/$*
	-rmdir $(DESTDIR)$(svcconfdir)
	-rmdir $(DESTDIR)$(svcinitdir)

.PHONY: clean

clean:

