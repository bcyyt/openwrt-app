# 需求实施计划

- [x] 1. 建立软件包目录与 Makefile
  - 创建 `stateful-upgrade/` 与 `luci-app-stateful-upgrade/` 的 OpenWrt 包结构
  - 对应 Requirement 8 的双包交付与 23.05/24.10 兼容

- [x] 2. 实现路径、状态与 JSON 公共库
  - 编写 `files/usr/lib/stateful-upgrade/common.sh`
  - 支持 `STATEFUL_ROOT` 前缀以便测试，实现 status 读写与 JSON 转义
  - 对应 Requirement 6.3 的任务状态

- [x] 3. 实现包管理器适配与 Essential 判断
  - 编写 `pkg.sh`：检测 opkg/apk，列出/安装/卸载/文件归属
  - 固定 Essential 集合并并入控制文件 Essential 标记与直接依赖
  - 对应 Requirement 4.3、7.1、8.3

- [x] 4. 实现快照采集
  - 编写 `snapshot.sh`：插件清单、root 密码行、SSH 文件、自定义二进制 tar
  - 实现 `preview` 与 `snapshot`，采集失败则中止
  - 对应 Requirement 1、5 的采集侧、6.1

- [x] 5. 实现 restore 与开机重试
  - 编写 `restore.sh`：按 progress 恢复密码、SSH、二进制、卸载、安装
  - 安装未完成保持 restoring；SSH 失败回退固件默认配置
  - 对应 Requirement 3、4、5、7

- [x] 6. 实现 CLI 入口、sysupgrade 与 keep.d
  - 编写 `/usr/sbin/stateful-upgrade` 子命令：preview、snapshot、upgrade、restore、status、report
  - 默认 `sysupgrade --test`，`--force` 跳过；keep.d 持久化快照与恢复程序
  - 编写 init.d 开机调用 restore
  - 对应 Requirement 2、8.2

- [x] 7. 实现 LuCI 页面
  - Lua controller、overview 模板、rpcd ACL、menu.d、中文 po
  - 页面提供预览、上传、升级、status/report 展示
  - 对应 Requirement 6、8.1、8.4

- [x] 8. 检查点 - 确保所有测试通过
  - 确保所有测试通过,如有疑问请询问用户

- [x]* 8.1 编写 POSIX shell 夹具测试
  - 覆盖 preview/snapshot、Essential 卸载保护、root 行替换、安装失败重试、--test 失败不刷写

- [x] 9. 更新仓库 README 使用说明
  - 说明 feed 接入、CLI 与 LuCI 用法
