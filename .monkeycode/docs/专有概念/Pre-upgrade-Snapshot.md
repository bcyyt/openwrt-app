# Pre-upgrade Snapshot

升级开始前写入 `/etc/stateful-upgrade/snapshot/` 的状态副本。

包含：

- 已安装插件名称与版本（`packages.txt`）
- root 在 passwd/shadow 中的单行记录
- dropbear/OpenSSH 配置、主机密钥、`authorized_keys`
- overlay 中无软件包归属的可执行文件（`binaries.list` + `binaries.tar.gz`）

`PENDING` 表示等待刷写或等待 restore。全部插件装回后写入 `CONSUMED`，之后 `restore` 直接把 status 设为 completed。

采集失败时 CLI 中止，不调用 sysupgrade。
