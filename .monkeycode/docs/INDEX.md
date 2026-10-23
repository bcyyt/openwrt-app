# openwrt-app 文档

## 项目概述

openwrt-app 是一组 OpenWrt 软件包，用于在上传并刷写固件时保存升级前状态，并在启动后恢复插件、自定义二进制、root 密码和 SSH 设置。

**目标用户**: OpenWrt 设备管理员

**核心价值**:

- 升级后仍能用原来的 root 密码和 SSH 登录
- 用户插件按升级前清单装回，多余非 Essential 插件卸掉
- 新固件未预装本插件时，keep.d 仍能带上恢复程序

## 技术选型

| 类别 | 选择 | 理由 |
|---|---|---|
| 恢复引擎 | POSIX ash | OpenWrt 默认 shell |
| Web | LuCI Lua + luci-compat | 同时覆盖 23.05 与 24.10 |
| 包管理 | 运行时检测 opkg/apk | 双版本固件 |
| 持久化 | sysupgrade keep.d | 官方备份机制 |

## 核心功能

### 快照

- **目的**: 刷写前冻结系统状态
- **描述**: `preview` 只输出 JSON；`snapshot` 写入 `/etc/stateful-upgrade/snapshot/`

### 升级

- **目的**: 接管 sysupgrade
- **描述**: 默认 `--test`，失败中止；`--force` 跳过测试

### 恢复

- **目的**: 启动后对齐升级前状态
- **描述**: 凭据/SSH/二进制/卸载一次完成；插件安装失败则 restoring 并下次开机重试

## 文档导航

- 架构设计：当前工作区 `/.monkeycode/docs/ARCHITECTURE.md`
- 接口定义：当前工作区 `/.monkeycode/docs/INTERFACES.md`
- 开发指南：当前工作区 `/.monkeycode/docs/DEVELOPER_GUIDE.md`
- 需求与设计：当前工作区 `/.monkeycode/specs/2026-10-23-stateful-firmware-upgrade/`
