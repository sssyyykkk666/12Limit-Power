# 12Limit Power

为 2017 款 12 英寸 MacBook（MacBook10,1 / Intel Core m3-7Y32 / macOS 13.7.8）定制的轻量中文功耗控制应用。原生 **Swift + AppKit** 设置窗口与菜单栏，后端沿用 [VoltageShift 1.25](https://github.com/sicreative/VoltageShift)。前身是 FYQMac；v1.0.0 历史版本保留。

## 自定义与快捷控制

- 持续功耗 PL1、短时功耗 PL2：0.125W 步进。本机应用范围 3.75–49W，PL2 必须 ≥ PL1；上限读取安装前备份，后端禁止超过它。
- 允许 / 关闭 Intel 睿频，可与功耗独立组合。
- PL1 平均时间：沿用原始值，或 1 / 2 / 4 / 8 / 16 / 28 秒。PL2 时间、限值启用与保护位保持原状。
- 保存 / 载入一组常用配置；保存本身不会改变硬件。成功应用的自定义配置可从菜单栏再次使用。
- 平衡（5 / 6W、允许睿频）、节能（5 / 5W、关闭睿频）、恢复原始设置。
- 手动刷新频率、封装功耗、温度及采样时间；同时显示实际硬件限值。
- 系统启动时恢复最后成功配置；菜单应用在唤醒后重新提交。登录自动启动可切换，默认收起窗口。

双击 `/Applications/12Limit Power.app` 或点击菜单栏的应用名称打开窗口。关闭窗口仍保留菜单栏。退出应用不会取消限制；需要取消时先恢复原始设置。

[英特尔规格](https://www.intel.com/content/www/us/en/products/sku/97538/intel-core-m37y32-processor-4m-cache-up-to-3-00-ghz/specifications.html)列出的 TDP 为 4.5W，配置 TDP 范围为 3.75–7W。**本机原始 49W 是固件功耗限值，不代表无风扇机身能够持续散热 49W。** 窗口标出建议持续范围 3.75–7W；较高的值留给用户主动输入。PL1 是平均封装功耗限值，并非瞬时功耗或整机插座功耗的硬上限。

## 频率与 GPU 的实际限制

本机读出的睿频上限为单核 3.0GHz、双核 2.6GHz。参考 [TurboTune](https://github.com/tc466/TurboTune) 与 [Intel MSR 手册](https://www.intel.com/content/dam/develop/external/us/en/documents/335592-sdm-vol-4.pdf)，测试降低睿频倍率至 1.2 / 1.8GHz；写入后仍读回原始值，未通过验证，因此不开放指定频率或锁频功能。现有 VoltageShift 驱动的 MSR 读写只在当前执行核心进行，不能保证全核心 HWP 设置；未采用它做假性的全核心限频。

HD Graphics 615 与 CPU 共用封装功耗预算。暂未找到经本机验证有效的原生 macOS 独立 GPU 频率控制接口，因此窗口说明此项不可用。未改电压、GPU 电压、温度保护、风扇或 SIP 配置。

[CPUFriend](https://github.com/acidanthera/CPUFriend) / [CPUFriendFriend](https://github.com/corpnewt/CPUFriendFriend) 也经过研究：它们依赖内核电源数据注入，未安装到这台原生 Mac。界面分区参考 [Stats](https://github.com/exelban/stats) 的设计思路；未复制其代码或引入实时监控模块。

## 轻量与验证机制

无网络请求、无常驻监控定时器、无第三方 GUI 框架。目录事件通知更新状态；点击应用后只等待一次验证结果。功耗服务收到请求才执行并退出。每次写入都检查回读；失败时回退应用前的功耗及睿频，并验证回退。

输入只允许固定操作和四个整数，不执行用户提供的命令、路径、寄存器或代码。后端再次独立校验范围、步进、PL2/PL1 关系和平均时间。只在回读验证成功后保存开机配置。原始配置由管理员保护。

## 构建和升级

```sh
bash scripts/build-app.sh
sudo bash scripts/install-upgrade.sh
```

构建产物：`build/12Limit Power.app`。升级脚本面向当前用户 UID 501 和现有机型，不是通用 Mac 安装器；它保留安装前原始备份和 v1.0 恢复文件。首次部署仍需已批准的 VoltageShift 驱动及原始备份。

源码：`src/PowerApp.swift`；控制器：`scripts/controller.sh`；纯参数策略：`scripts/power-policy.pl`。

为保留历史备份、启动任务和设置的兼容性，内部服务标识与存储目录仍沿用 FYQMac：

- 应用：`/Applications/12Limit Power.app`
- 后端、原始备份和状态：`/Library/Application Support/FYQMac`
- 系统启动：`/Library/LaunchDaemons/local.fyqmac.power.plist`
- 登录启动：`~/Library/LaunchAgents/local.fyqmac.menu.plist`
- 请求队列：`~/Library/Application Support/FYQMacControl`

## 测试

```sh
python3 -m unittest discover -s tests -v
```

纯策略测试覆盖边界、畸形输入、时间编码与非目标寄存器位保留。模拟后端测试覆盖自定义、重应用、只读刷新、预设、完整恢复、参数拒绝及写入回读失败后的回退，测试不写真实硬件。`scripts/verify-profiles.sh` 是本机硬件预设测试；`scripts/verify-custom.sh` 检查本机自定义、平均时间、睿频、重应用、越界拒绝、只读刷新及完整恢复，最终留在平衡档。

固件或 macOS 可能再次调整限值。手动刷新显示采样时刻硬件值；重新应用需要选择档位。配置回读一致并不能证明所有任务的卡顿已经消失。

## 卸载

```sh
sudo bash scripts/uninstall.sh
```

先恢复并验证原始配置，再卸载驱动和启动任务。失败时保留文件。Git 和 Apple 开发工具保留。

## 许可与版本

GPL-3.0，见 LICENSE。VoltageShift 官方 1.25 二进制和上游源码随附；源码快照提交 `a4b02ebbcbdada286e2b49346405d57199b78eab`。研究参考的项目未被打包为新依赖。

- v1.0.0：FYQMac 菜单栏、固定档位、启动恢复和回读验证。
- v1.1.0：12Limit Power，增加原生窗口、自定义功耗与平均时间、独立睿频、常用配置、实际限值显示及失败回退。
