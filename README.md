# openwrt-app

OpenWrt 状态保持升级插件：刷写固件前保存已安装插件、自定义二进制、root 密码和 SSH 设置，启动后再按快照恢复。新固件多带的非 Essential 插件会被卸载；缺的插件在软件源可用前每次开机重试。

## 软件包

- `stateful-upgrade`：CLI 与开机恢复引擎
- `luci-app-stateful-upgrade`：LuCI「系统 / 状态保持升级」页面

兼容 OpenWrt 23.05（opkg）与 24.10（apk 或 opkg）。

## 加入 feeds

```bash
echo "src-link stateful_upgrade /path/to/openwrt-app" >> feeds.conf.default
./scripts/feeds update stateful_upgrade
./scripts/feeds install stateful-upgrade luci-app-stateful-upgrade
make menuconfig
```

在 menuconfig 中启用：

- Utilities -> stateful-upgrade
- LuCI -> Applications -> luci-app-stateful-upgrade

## CLI

```bash
stateful-upgrade preview
stateful-upgrade snapshot
stateful-upgrade upgrade /tmp/firmware.bin
stateful-upgrade upgrade /tmp/firmware.bin --force
stateful-upgrade status
stateful-upgrade report
stateful-upgrade restore
```

`upgrade` 默认先执行 `sysupgrade --test`，失败则中止。`--force` 跳过测试。

## 恢复顺序

1. root 密码（只替换 root 行）
2. SSH 配置与密钥；重启失败则回退固件默认 SSH 配置
3. 自定义二进制
4. 卸载快照中没有的非 Essential 插件
5. 安装快照中缺失的插件；未装齐则保持 restoring，下次开机继续

## 测试

```bash
sh tests/run.sh
```
