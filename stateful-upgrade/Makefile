include $(TOPDIR)/rules.mk

PKG_NAME:=stateful-upgrade
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=openwrt-app
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/stateful-upgrade
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Stateful firmware upgrade with snapshot restore
  DEPENDS:=+busybox
  PKGARCH:=all
endef

define Package/stateful-upgrade/description
  Save installed plugins, custom binaries, root password and SSH
  settings before sysupgrade, then restore them on first boots.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/stateful-upgrade/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/stateful-upgrade $(1)/usr/sbin/stateful-upgrade
	$(INSTALL_DIR) $(1)/usr/lib/stateful-upgrade
	$(INSTALL_DATA) ./files/usr/lib/stateful-upgrade/*.sh $(1)/usr/lib/stateful-upgrade/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/stateful-upgrade $(1)/etc/init.d/stateful-upgrade
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/lib/upgrade/keep.d/stateful-upgrade $(1)/lib/upgrade/keep.d/stateful-upgrade
endef

define Package/stateful-upgrade/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/stateful-upgrade enable
exit 0
endef

$(eval $(call BuildPackage,stateful-upgrade))
