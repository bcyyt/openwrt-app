# 接口定义

## CLI `stateful-upgrade`

路径：`/usr/sbin/stateful-upgrade`

| 命令 | 输入 | 输出 | 失败行为 |
|---|---|---|---|
| `preview` | 无 | stdout JSON：plugin_count、binary_count、auth、ssh、pkg_mgr、plugins、binaries | 采集失败 exit 1 |
| `snapshot` | 无 | 写入 `/etc/stateful-upgrade/snapshot/`，status=pending | 采集失败 abort |
| `upgrade <image>` | 固件文件 | 先 snapshot，再 `sysupgrade --test`，通过后 `sysupgrade <image>` | 空文件或 test 失败中止 |
| `upgrade <image> --force` | 固件文件 | 跳过 --test | 空文件中止 |
| `restore` | 已有 snapshot | 按 progress 恢复；未装齐插件则 status=restoring | 快照残缺且存在 PENDING 时 status=failed |
| `status` | 无 | 一行：idle / pending / restoring / completed / failed | 无 status 文件时 idle |
| `report` | 无 | report.json；不存在则 `{}` | 无 |

测试可用环境变量：`STATEFUL_ROOT`、`STATEFUL_OVERLAY`、`STATEFUL_SKIP_NET=1`、`SYSUPGRADE_BIN`。

## 快照与报告文件

| 路径 | 内容 |
|---|---|
| `/etc/stateful-upgrade/status` | 任务状态 |
| `/etc/stateful-upgrade/snapshot/packages.txt` | `name<TAB>version` |
| `/etc/stateful-upgrade/snapshot/passwd.root` | passwd 中 root 行 |
| `/etc/stateful-upgrade/snapshot/shadow.root` | shadow 中 root 行 |
| `/etc/stateful-upgrade/snapshot/ssh/` | dropbear/sshd 配置、主机密钥、authorized_keys |
| `/etc/stateful-upgrade/snapshot/binaries.list` | 设备路径列表 |
| `/etc/stateful-upgrade/snapshot/binaries.tar.gz` | 自定义二进制 |
| `/etc/stateful-upgrade/progress/{auth,ssh,binaries,remove}` | 已完成步骤标记 |
| `/etc/stateful-upgrade/report.json` | installed / removed / skipped_essential / failed / binaries_restored / auth_restored / ssh_restored / install_pending |
| `/etc/stateful-upgrade/snapshot/CONSUMED` | 恢复完成标记 |

## LuCI

菜单：`admin/system/stateful_upgrade`，标题 Stateful Upgrade。

| 路径 | 作用 |
|---|---|
| `admin/system/stateful_upgrade` | overview 模板 |
| `.../preview` | 调用 CLI preview，application/json |
| `.../status` | `{"status":"..."}` |
| `.../report` | CLI report JSON |
| `.../upgrade` | 将表单字段 `image` 写到 `/tmp/stateful-upgrade/firmware.bin`，再执行 `stateful-upgrade upgrade` 该固定路径 |

固件上传不拼接用户文件名，避免命令注入。

ACL：`luci-app-stateful-upgrade`，允许 exec `/usr/sbin/stateful-upgrade`，写 `/tmp/stateful-upgrade/`。

## 开机钩子

`/etc/init.d/stateful-upgrade` START=99：后台执行 `stateful-upgrade restore`。

## 包管理探测

存在 `apk` 命令且 `STATEFUL_ROOT/etc/apk` 为目录则走 apk，否则 opkg。
