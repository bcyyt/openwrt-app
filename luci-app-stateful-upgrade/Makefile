include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-stateful-upgrade
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=openwrt-app

LUCI_TITLE:=LuCI support for stateful firmware upgrade
LUCI_DEPENDS:=+stateful-upgrade +luci-compat
LUCI_PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-stateful-upgrade
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
  PKGARCH:=all
endef

define Package/luci-app-stateful-upgrade/description
  LuCI page under System to upload firmware and keep pre-upgrade state.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-stateful-upgrade/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/stateful_upgrade.lua $(1)/usr/lib/lua/luci/controller/stateful_upgrade.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/stateful_upgrade
	$(INSTALL_DATA) ./luasrc/view/stateful_upgrade/overview.htm $(1)/usr/lib/lua/luci/view/stateful_upgrade/overview.htm
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-stateful-upgrade.json $(1)/usr/share/rpcd/acl.d/luci-app-stateful-upgrade.json
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-stateful-upgrade.json $(1)/usr/share/luci/menu.d/luci-app-stateful-upgrade.json
	$(INSTALL_DIR) $(1)/usr/share/stateful-upgrade
	$(INSTALL_DATA) ./po/zh_Hans/stateful_upgrade.po $(1)/usr/share/stateful-upgrade/stateful_upgrade.zh_Hans.po
endef

$(eval $(call BuildPackage,luci-app-stateful-upgrade))
