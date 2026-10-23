# 开发指南

## 项目目的

openwrt-app 是 OpenWrt 软件包仓库，提供状态保持固件升级。它在路由器 sysupgrade 流程中负责快照与恢复，不替代 sysupgrade 本身。

**核心职责**:

- 升级前保存插件、自定义二进制、root 密码、SSH 设置
- 升级后按快照同步软件集合并保留 Essential 包
- 通过 LuCI 与 CLI 暴露同一套引擎

**相关系统**:

- OpenWrt sysupgrade / keep.d - 刷写与文件保留
- opkg / apk - 插件安装卸载
- LuCI - Web 管理界面

## 环境搭建

### 前置条件

- POSIX shell、tar、find、awk、sed
- 完整 ipk 构建需要 OpenWrt SDK 或 buildroot
- 本地逻辑验证：`sh tests/run.sh`

### 测试

```bash
sh tests/run.sh
```

测试通过 `STATEFUL_ROOT` 把根文件系统重定向到临时目录，并用 `tests/mocks/opkg`、`tests/mocks/sysupgrade` 替换真实命令。

### 构建 ipk

将本仓库加入 OpenWrt feeds 后：

```bash
./scripts/feeds update stateful_upgrade
./scripts/feeds install stateful-upgrade luci-app-stateful-upgrade
make package/stateful-upgrade/compile
make package/luci-app-stateful-upgrade/compile
```

## 项目结构说明

- `stateful-upgrade/files/usr/lib/stateful-upgrade/common.sh`：路径前缀、status、JSON 转义
- `pkg.sh`：opkg/apk 与 Essential
- `snapshot.sh`：preview / snapshot
- `restore.sh`：restore / status / report
- LuCI 只 exec CLI，不复制恢复逻辑

## 开发规范

- 恢复引擎保持 POSIX ash，避免 bash 数组
- 设备路径一律经 `su_path`，以便测试注入 `STATEFUL_ROOT`
- 固件路径在 LuCI 中固定为 `/tmp/stateful-upgrade/firmware.bin`
- Essential 列表改动需同步 `tests/02_restore.sh`

## 常见任务

增加 Essential 包名：编辑 `pkg.sh` 中 `ESSENTIAL_PACKAGES`。

增加 SSH 需要保存的路径：编辑 `snapshot_ssh` 与 `restore_ssh`。

## 构建与发布

产出为两个 OpenWrt 软件包，安装到设备后 enable `stateful-upgrade` init（postinst 会 enable）。LuCI 依赖 `stateful-upgrade` 与 `luci-compat`。
