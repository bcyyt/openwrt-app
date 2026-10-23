# 模块 luci-app-stateful-upgrade

LuCI 应用，菜单在系统下，依赖 `stateful-upgrade` 与 `luci-compat`。

**页面**: `luasrc/view/stateful_upgrade/overview.htm` 展示预览计数、固件上传、status 文案、最近 report。

**Controller**: `luasrc/controller/stateful_upgrade.lua`。上传写入固定路径 `/tmp/stateful-upgrade/firmware.bin` 后调用 `stateful-upgrade upgrade`。

**翻译**: `po/zh_Hans/stateful_upgrade.po`，安装时放到 `/usr/share/stateful-upgrade/`。

**ACL / menu**: `root/usr/share/rpcd/acl.d/luci-app-stateful-upgrade.json`、`root/usr/share/luci/menu.d/luci-app-stateful-upgrade.json`。
