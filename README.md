# FYQMac

为这台 2017 款 12 英寸 MacBook（MacBook10,1 / Intel Core m3-7Y32 / macOS 13.7.8）配置的中文功耗菜单栏。后端使用 [VoltageShift 1.25](https://github.com/sicreative/VoltageShift)，界面使用 Swift + AppKit。

## 使用

点击菜单栏 ⚡：

- 平衡：PL1 最高 5W，PL2 最高 6W，开启睿频。
- 节能：PL1/PL2 最高 5W，关闭睿频。
- 恢复原始设置：还原安装前备份的功耗寄存器，以及当时的睿频开关。
- 登录时启动菜单栏：控制下次登录是否显示菜单。
- 查看最近一次读数：显示最近一次应用设置时读取的温度、功耗和频率。不是实时监控。

功耗设置由系统启动服务在开机时恢复。菜单栏应用在唤醒后重新提交上次成功的配置。退出菜单栏不会取消功耗限制；需要取消限制时，先选“恢复原始设置”。

限值只向下调整，不超过安装前读取的原始限值。原始配置存放在 `/Library/Application Support/FYQMac/baseline.plist`，仅管理员可修改。功耗档位通过寄存器回读验证后才标记为成功。PL1 是持续平均功耗限值，PL2 是短时限值，并非整机插座功耗的硬上限。

## 安装位置

- 应用：`/Applications/FYQMac.app`
- 后端、备份、状态和日志：`/Library/Application Support/FYQMac`
- 开机配置：`/Library/LaunchDaemons/local.fyqmac.power.plist`
- 登录菜单栏配置：`~/Library/LaunchAgents/local.fyqmac.menu.plist`
- 请求队列：`~/Library/Application Support/FYQMacControl`

系统服务只在启动或收到请求时执行，然后退出。菜单栏无联网和周期性监控定时器。菜单不会改电压、温度保护、风扇或系统完整性保护配置。

## 源码与构建

`src/FYQMac.swift` 是菜单栏源码；`scripts/controller.sh` 是固定档位控制器。控制器只接受三个固定档位，不执行请求文件中的命令。机型、RAPL 功耗单位、原始值在首次使用前检查。

```sh
cd /Users/skyfu/Downloads/FYQMac
bash scripts/build-app.sh
```

此安装脚本针对当前用户 UID 501 和上述固定机型；不是通用 Mac 安装器。

## 验证

`bash scripts/verify-profiles.sh` 在本机依次应用节能、原始和平衡档，检查功耗限值、睿频开关、其他寄存器位保持原状，并验证完整恢复。最终留在平衡档。

这证明配置写入和回读一致，不能单独证明所有任务的卡顿已消失。固件或 macOS 的电源管理可能重新设置限值，可用菜单中的“重新应用并刷新状态”复查。

## 卸载

```sh
sudo bash /Users/skyfu/Downloads/FYQMac/scripts/uninstall.sh
```

卸载脚本先恢复并验证原始配置，再卸载驱动和移除应用、启动配置。若恢复或驱动卸载失败，保留文件便于继续处理。Git 和 Apple Command Line Tools 会保留。

## 上游与许可

VoltageShift 原版二进制及其源代码归原作者所有，使用 GPL-3.0；上游地址：https://github.com/sicreative/VoltageShift 。本项目源码也按 GPL-3.0 提供，见 LICENSE。

## 首个版本

v1.0.0：中文原生菜单栏、三个固定功耗档位、开机恢复、登录启动、唤醒后重应用、原始寄存器备份及回读校验。安装过程的临时排错文件和日志不纳入版本。

上游源代码快照：`sicreative/VoltageShift`，提交 `a4b02ebbcbdada286e2b49346405d57199b78eab`；随附官方 1.25 二进制及 GPL-3.0 许可证。
