# 模块 stateful-upgrade

OpenWrt 工具包。安装 CLI、shell 库、init 脚本和 keep.d 清单。

**Makefile**: `stateful-upgrade/Makefile`，PKGARCH=all，postinst 在真机上 enable init。

**CLI 子命令**: preview、snapshot、upgrade、restore、status、report。实现见 `files/usr/sbin/stateful-upgrade`，逻辑在 `files/usr/lib/stateful-upgrade/`。

**Essential**: `pkg.sh` 固定集合，加上 `Essential: yes` 以及已安装 Essential 包的直接依赖。卸载同步时跳过这些包。

**自定义二进制扫描路径**（相对 overlay upper）：`bin`、`sbin`、`usr/bin`、`usr/sbin`、`usr/local`、`opt`。
