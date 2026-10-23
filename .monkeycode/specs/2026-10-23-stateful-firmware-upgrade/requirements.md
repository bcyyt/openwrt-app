# Requirements Document

## Introduction

本功能为 OpenWrt 提供状态保持固件升级能力。管理员通过 LuCI 或 CLI 上传固件并执行升级后，系统恢复升级前的运行状态，覆盖已安装插件、自定义二进制、root 密码和 SSH 设置。新固件中存在但升级前快照中不存在的插件，在保留 Essential Plugin 的前提下被同步卸载，使升级后的用户软件集合与升级前一致。插件安装在软件源可用并成功前每次开机重试。系统同时兼容 OpenWrt 23.05 与 24.10，运行时适配 opkg 或 apk。

## Glossary

- **System**: OpenWrt 状态保持升级插件，包含 LuCI 管理界面、CLI 与升级前后的状态处理逻辑。
- **Administrator**: 已获得 OpenWrt 管理权限、可执行固件升级的操作者。
- **Firmware Image**: 管理员提供的 OpenWrt 固件文件，格式为 `.bin` 或 `.img`。
- **Pre-upgrade Snapshot**: 升级开始前采集的系统状态副本，包含插件清单、自定义二进制清单与内容、root 密码哈希、SSH 配置与密钥。
- **Plugin**: 由设备 Package Manager 记录为已安装的软件包。
- **Essential Plugin**: 维持 Web 管理、SSH、网络与防火墙基础能力的软件包，以及这些软件包的直接依赖。卸载同步时必须保留。
- **Custom Binary**: 位于 overlay 中、可执行、且不属于任何已安装软件包文件清单的文件。
- **Root Password State**: `/etc/passwd` 与 `/etc/shadow` 中 root 账户的认证信息。
- **SSH Settings**: SSH 服务配置、监听参数、root 登录策略，以及主机密钥与授权公钥。
- **Upgrade Job**: 一次完整的「采集快照 -> 刷写固件 -> 启动后恢复」流程。
- **CLI**: `/usr/sbin/stateful-upgrade` 命令行入口，供 Administrator 与 LuCI 调用。
- **Package Manager**: 设备上的 opkg 或 apk，由 System 在运行时检测。

## Requirements

### Requirement 1: 升级前采集快照

**User Story:** AS Administrator, I want 在确认升级前自动保存当前系统状态, so that 升级后能够按升级前状态恢复。

#### Acceptance Criteria

1. WHEN Administrator 确认开始固件升级, the System SHALL 在刷写固件前生成一份 Pre-upgrade Snapshot。
2. WHEN the System 生成 Pre-upgrade Snapshot, the System SHALL 记录当时全部已安装 Plugin 的名称与版本。
3. WHEN the System 生成 Pre-upgrade Snapshot, the System SHALL 记录 Custom Binary 的路径、权限、所有者与文件内容。
4. WHEN the System 生成 Pre-upgrade Snapshot, the System SHALL 记录 Root Password State。
5. WHEN the System 生成 Pre-upgrade Snapshot, the System SHALL 记录 SSH Settings。
6. IF Pre-upgrade Snapshot 采集失败, the System SHALL 中止本次 Upgrade Job 并在管理界面与 CLI 展示失败原因。

### Requirement 2: 固件上传与升级执行

**User Story:** AS Administrator, I want 通过管理界面或命令行上传固件并执行升级, so that 升级过程由插件统一接管快照与恢复。

#### Acceptance Criteria

1. WHEN Administrator 上传 Firmware Image, the System SHALL 校验文件存在、可读且大小大于 0。
2. IF Firmware Image 校验失败, the System SHALL 拒绝启动 Upgrade Job 并展示失败原因。
3. WHEN Administrator 确认升级且 Pre-upgrade Snapshot 已成功保存, the System SHALL 先执行 sysupgrade 镜像测试。
4. IF 镜像测试失败, the System SHALL 中止 Upgrade Job 并展示失败原因。
5. WHEN 镜像测试通过, the System SHALL 使用该 Firmware Image 执行系统升级。
6. WHEN Administrator 在 CLI 使用 --force 且快照已保存, the System SHALL 跳过镜像测试并执行系统升级。
7. WHEN the System 执行系统升级, the System SHALL 将 Pre-upgrade Snapshot 与恢复程序放置到升级后仍可读取的持久位置。

### Requirement 3: 恢复 root 密码与 SSH 设置

**User Story:** AS Administrator, I want 升级后继续使用原来的 root 密码和 SSH 设置, so that 升级后仍能用原有凭据登录管理设备。

#### Acceptance Criteria

1. WHEN 设备完成固件启动且检测到有效 Pre-upgrade Snapshot, the System SHALL 将 Root Password State 恢复为快照中的值。
2. WHEN 设备完成固件启动且检测到有效 Pre-upgrade Snapshot, the System SHALL 将 SSH Settings 恢复为快照中的值。
3. WHEN Root Password State 与 SSH Settings 恢复完成, the System SHALL 使 SSH 服务加载恢复后的配置。
4. IF Root Password State 或 SSH Settings 恢复失败, the System SHALL 记录失败原因并继续执行后续可独立完成的恢复步骤。

### Requirement 4: 按升级前清单同步插件

**User Story:** AS Administrator, I want 升级后的已安装插件与升级前一致, so that 原有功能保留，新固件多带的插件被去掉。

#### Acceptance Criteria

1. WHEN 设备完成固件启动且检测到有效 Pre-upgrade Snapshot, the System SHALL 安装快照中存在、当前系统缺失的 Plugin。
2. WHEN 设备完成固件启动且检测到有效 Pre-upgrade Snapshot, the System SHALL 卸载当前已安装、但不在快照中、且不属于 Essential Plugin 的 Plugin。
3. WHILE 同步插件, the System SHALL 保留全部 Essential Plugin。
4. IF 软件源不可用或仍有快照 Plugin 安装失败, the System SHALL 保持 Upgrade Job 为恢复中，并在下一次开机再次尝试安装。
5. WHEN 快照中的全部 Plugin 均已安装, the System SHALL 写出同步结果，内容包含成功安装列表、成功卸载列表、跳过的 Essential Plugin 列表与失败项。
6. IF 某个非 Essential Plugin 卸载失败, the System SHALL 记录该 Plugin 名称与失败原因，并继续处理剩余 Plugin。

### Requirement 5: 恢复自定义二进制

**User Story:** AS Administrator, I want 升级后仍能使用升级前自行放置的可执行文件, so that 不依赖软件包的工具不会丢失。

#### Acceptance Criteria

1. WHEN 设备完成固件启动且检测到有效 Pre-upgrade Snapshot, the System SHALL 将快照中的每个 Custom Binary 恢复到原路径。
2. WHEN the System 恢复 Custom Binary, the System SHALL 恢复该文件的权限与所有者。
3. IF 某个 Custom Binary 恢复失败, the System SHALL 记录该文件路径与失败原因，并继续恢复剩余 Custom Binary。

### Requirement 6: 升级过程可见性与结果确认

**User Story:** AS Administrator, I want 在升级前看到将要保存和同步的内容，并在升级后看到结果, so that 能够确认状态保持是否成功。

#### Acceptance Criteria

1. WHEN Administrator 打开升级页面或执行 preview, the System SHALL 展示当前将纳入快照的 Plugin 数量、Custom Binary 数量，以及 Root Password State 与 SSH Settings 的采集状态。
2. WHEN Upgrade Job 在启动后恢复阶段结束, the System SHALL 在管理界面与 report 输出中展示最近一次恢复的成功项、失败项与跳过的 Essential Plugin。
3. WHEN 管理界面或 status 子命令请求最近一次 Upgrade Job 状态, the System SHALL 返回该任务处于「待升级」「恢复中」「已完成」或「失败」中的一种。

### Requirement 7: 安全与可管理性边界

**User Story:** AS Administrator, I want 状态恢复不会导致设备失去网络或管理入口, so that 升级失败后仍能继续管理路由器。

#### Acceptance Criteria

1. WHILE 卸载 Plugin, the System SHALL 保留提供 Web 管理界面、SSH 服务、网络配置与防火墙基础能力的 Essential Plugin。
2. IF 恢复过程使 SSH 服务无法启动, the System SHALL 回退到当前固件自带的 SSH 默认配置，并保留已恢复的 Root Password State。
3. WHEN 快照中的全部 Plugin 均已安装且其余恢复步骤已执行, the System SHALL 将本次 Pre-upgrade Snapshot 标记为已消费。
4. WHILE Upgrade Job 处于恢复中, the System SHALL 在每次开机跳过已完成的凭据、SSH、二进制与卸载步骤，只重试尚未成功的插件安装。

### Requirement 8: 交付形态与版本兼容

**User Story:** AS Administrator, I want 用网页或命令行都能做状态保持升级, so that 在 OpenWrt 23.05 与 24.10 上都能使用。

#### Acceptance Criteria

1. WHEN Administrator 使用 LuCI 系统菜单中的状态保持升级页面, the System SHALL 提供固件上传、快照预览、确认升级与恢复结果展示。
2. WHEN Administrator 在 SSH 中调用 CLI, the System SHALL 提供 preview、snapshot、upgrade、restore、status 与 report 子命令。
3. WHEN 设备包管理器为 opkg 或 apk, the System SHALL 使用对应 Package Manager 完成插件清单采集、安装与卸载。
4. WHEN LuCI 在 OpenWrt 23.05 或 24.10 上加载本插件, the System SHALL 展示同一组升级与恢复功能。

## Confirmed Decisions

| 主题 | 选择 |
|---|---|
| 交付形态 | LuCI 管理界面 + 独立 CLI |
| 目标版本 | 同时兼容 OpenWrt 23.05 与 24.10 |
| 包管理器 | 运行时检测 opkg 或 apk |
| 插件卸载范围 | 同步用户插件，保留 Essential Plugin |
| LuCI 实现 | Lua controller/view，24.10 依赖 luci-compat |
| LuCI 菜单位置 | 系统 / 状态保持升级 |
| 无网络时的插件安装 | 保持恢复中，每次开机重试直到安装成功 |
| 刷写前镜像检查 | 默认 sysupgrade --test，失败则中止；CLI 可用 --force |
