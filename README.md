# 12Limit Power

为 2017 款 12 英寸 MacBook（MacBook10,1、Intel HD Graphics 615）设计的轻量中文功耗控制工具。原生 Swift + AppKit 窗口与菜单栏，采用 [VoltageShift 1.25](https://github.com/sicreative/VoltageShift) 后端。前身 FYQMac 的恢复文件和配置目录保持兼容。

## 选择下载版本

| Release | CPU | GPU | 系统 / 架构 | 验证状态 |
| --- | --- | --- | --- | --- |
| [v1.3.0-m3](https://github.com/sssyyykkk666/12Limit-Power/releases/tag/v1.3.0-m3) | Core m3-7Y32 | Intel HD Graphics 615 | macOS 13 / Intel x86_64 | 基于原 m3 版本更新；新构建通过模拟测试及窗口自测，尚未重新在 m3 实机验证 |
| [v1.3.0-i7](https://github.com/sssyyykkk666/12Limit-Power/releases/tag/v1.3.0-i7) | Core i7-7Y75 | Intel HD Graphics 615 | macOS 13 / Intel x86_64 | macOS 13.7.8 实机驱动加载、基线捕获、原始设置恢复与回读通过；新构建通过模拟测试及窗口自测 |

下载对应 Release 中的 `12Limit-Power-1.3.0-m3.zip` 或 `12Limit-Power-1.3.0-i7.zip`，完整解压。不要只复制 `.app`：首次安装需要同包的脚本和驱动。`SHA256SUMS.txt` 可用于核对文件。

两个版本功能一致，安装器与后端校验 CPU，应用显示对应型号。它们共用配置目录，不能在同一台设备上作为两套独立服务并存。不支持 Apple Silicon、其他 MacBook 型号或其他 CPU。源码默认目标为 i7，发布包的 `target-cpu.txt` 指定各自目标。

## 功能与边界

- 独立设置持续封装功耗 PL1、短时封装功耗 PL2，以及 Intel 睿频开关。
- 功耗步进 0.125W，下限 3.75W；上限从本机安装前备份读取，PL2 必须不小于 PL1。
- PL1 平均时间可沿用原始值，或选择 1 / 2 / 4 / 8 / 16 / 28 秒；PL2 时间及保护位保留。
- 平衡默认 5 / 6W、允许睿频；节能默认 5 / 5W、关闭睿频。它们是保守起点，未宣称是所有任务的最佳参数。
- 平衡 / 节能分别编辑与保存；仅保存不写硬件，应用成功后才保存开机配置。支持常用自定义配置。
- 每次写入检查回读；失败时尝试恢复应用前配置并验证回退。恢复原始设置使用安装前备份。
- 手动刷新频率、封装功耗、温度和采样时间；无常驻监控计时器。启动恢复最后成功配置，唤醒后重新提交。

CPU 与核显共享封装功耗预算。当前可以约束共享预算，但**没有独立 GPU MHz 设置、固定 CPU GHz、降压或温度保护修改功能**。较低封装限值也可能影响图形任务性能。

无风扇机身建议从 3.75–7W 持续功耗范围试用。实测 i7 的原始 PL1/PL2 均为 49W；上游 m3 记录也为 49W。这是固件寄存器限值，不是可持续散热能力，安装时仍必须读取每台机器自己的基线。PL1 是平均封装功耗限制，不是整机耗电或瞬时功耗硬上限。

## 首次安装教程（按实际安装记录整理）

### 1. 检查机型并准备安装包

「关于本机」确认是 2017 年 12 英寸 Intel MacBook。终端可执行：

```sh
sysctl -n hw.model
sysctl -n machdep.cpu.brand_string
```

应显示 `MacBook10,1` 和所选版本对应的 `m3-7Y32` 或 `i7-7Y75`。完整解压下载的 ZIP，保留整个目录。发布包已经编译，无需安装 Xcode 或重新编译。

### 2. 在恢复模式允许此类内核扩展

本项目随附驱动在本次 Ventura 安装中被系统以 `Bad code signature` 拒绝。仅在普通桌面点击“允许”不能解决所有签名限制。[VoltageShift 上游安装说明](https://github.com/sicreative/VoltageShift#usage)要求在恢复模式放宽内核扩展签名限制。这会降低这一部分系统保护；其余 SIP 保护保持开启。

1. 保存工作，重新启动 Mac，立即按住 **⌘ Command + R**，直到进入恢复模式。
2. 在顶部菜单选择「实用工具 → 终端」。
3. 输入并执行：

   ```sh
   csrutil enable --without kext
   ```

4. 按命令提示确认，重启回正常桌面。
5. 在正常系统终端执行 `csrutil status`。本次机器显示 `Custom Configuration`，其中 `Kext Signing: disabled`，Filesystem、Debugging、DTrace、NVRAM、BaseSystem 等保护仍为 `enabled`。`Custom Configuration` 不等于操作失败；以具体字段为准。

不需要执行完全关闭 SIP 的 `csrutil disable`，也不需要修改 authenticated-root。此步骤必须本人在恢复模式完成，应用不会自动修改这些设置。

### 3. 安装并加载驱动

在解压目录中双击 **Install.command**。它会检查 CPU，将安装文件复制到临时目录，要求管理员认证，尝试加载驱动，保存本机原始设置并安装应用。

如果 macOS 拦截打开，先尝试右键文件选择「打开」，或在「系统设置 → 隐私与安全性」查看对应提示。应用使用本地临时签名，未经过 Apple 公证。

如果终端提示系统阻止扩展，在「系统设置 → 隐私与安全性」批准对应扩展，并按系统提示重启；然后再次运行同一个 `Install.command`。是否出现批准提示取决于当前系统状态，本次实机在恢复模式设置后可直接成功加载。

驱动是否已加载可通过以下命令检查：

```sh
ioreg -r -c VoltageShiftAnVMSR
```

成功时包含 `VoltageShiftAnVMSR`、`registered`、`matched`、`active`。空输出说明还没加载，不能继续当作安装完成。

### 4. 手动安装方式（需要时使用）

在终端先输入 `cd `（末尾留空格），将**解压后的目录**拖入终端，按回车。示例（目录名按实际版本调整）：

```sh
cd "$HOME/Downloads/12Limit-Power-1.3.0-i7"
bash Install.command
```

不要在用户主目录 `~` 直接执行 `bash scripts/setup-device.sh`，否则会出现 `No such file or directory`。

如需单独排查驱动加载，可在解压目录执行：

```sh
sudo /usr/bin/kextutil -v 1 "$PWD/vendor/VoltageShift/VoltageShift.kext"
```

已成功加载驱动后，可手动初始化：

```sh
sudo bash scripts/setup-device.sh
bash scripts/deploy-menu.sh
open '/Applications/12Limit Power.app'
```

输入 `sudo` 密码时终端不显示字符，输入完成按回车即可。不要把密码写入脚本或发到聊天中。

如果管理员进程读“下载”目录出现 `Operation not permitted`，使用本版 `Install.command`，它已包含临时目录安装处理；也可以先把完整解压目录移到 `/Users/Shared` 后再从该目录执行。不要只移动一个脚本。

### 5. 确认安装结果并开始使用

安装器先读取 MSR 单位，确认匹配后保存本机原始功耗与睿频寄存器。已有基线不会被覆盖。首次安装保持原始设置；升级保留最后选中的配置。

成功后应用位于 `/Applications/12Limit Power.app`，菜单栏出现闪电图标。打开窗口查看硬件读回值；点击「平衡」或「节能」才启用对应功耗配置。应看到「已回读验证」，再刷新查看采样读数。

本次 i7 记录：驱动加载成功；原始 PL1/PL2 为 49 / 49W，睿频开启；恢复原始设置与回读一致；单核 / 双核睿频倍率读数为 3.6 / 3.4GHz。倍率读数不是持续运行频率，也不表示应用支持写入这些倍率。

关闭窗口仍保留菜单栏；退出应用不会取消已经写入的限制。要取消限制，先点击「恢复原始设置」。

## 升级及原 m3 用户

使用对应 CPU 的新安装包运行 `Install.command`。它支持为原安装补充实际用户、UID 和 home 配置，保留已有原始基线及历史恢复文件。不要将另一台机器的 `baseline.plist` 拷贝过来，也不要为升级手动删除原始备份。

升级会先校验包内应用与目标 CPU 是否一致，再部署。旧版本队列残留刷新请求时，安装器会补做初始化，避免把“只刷新成功”误认为后端安装失败。

登录自动启动可在窗口切换。系统服务使用 root 管理的设备信息，仅接受安装账户的请求；不再写死作者用户名、源码目录或 UID 501。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| `No such file or directory` | 先进入完整解压目录；不要在 `~` 执行相对脚本路径。 |
| `Bad code signature` | 核对恢复模式设置及 `csrutil status`；重启后重试加载，保留完整错误输出。 |
| `VoltageShift driver is not loaded` | 先加载 / 批准驱动并按提示重启，再运行安装器。 |
| `Operation not permitted` | 使用 `Install.command` 的临时目录安装路径，或将完整目录移到 `/Users/Shared`。 |
| `Wrong package` / `CPU 不符` | 下载匹配 CPU 的 m3 或 i7 包，其他型号不支持。 |
| 后端尚未就绪 | 首次安装尚未完成，查看驱动状态和初始化结果。 |
| 失败或回读不一致 | 查看应用「诊断」与控制器日志；不要把未通过验证当作成功。 |

固件或系统可能再次调整功耗值，手动刷新只代表采样时刻。回读一致不能证明所有任务都更流畅；本版本未提供续航提升或降温幅度承诺。

## 构建与测试

源码默认 `target-cpu.txt` 为 `i7-7Y75`。单独构建另一版本前可改成 `m3-7Y32`：

```sh
bash scripts/build-app.sh
python3 -m unittest discover -s tests -v
```

本地构建需要 macOS 开发工具。产物为 `build/12Limit Power.app`，不自动安装。一次构建两个发行包：

```sh
bash scripts/package-releases.sh
```

输出到 `build/releases/`，每包包含已编译应用、安装器、脚本、源码、驱动和许可证。打包脚本不会改变本地默认 CPU；重复打包前移走旧 staging 目录。窗口预览自测不写硬件：

```sh
LIMIT_PREVIEW_PATH="$PWD/build/preview.png" 'build/12Limit Power.app/Contents/MacOS/12LimitPower' --preview --self-test
```

模拟测试覆盖两种 CPU、错误 CPU 拒绝、参数边界、时间编码、非目标位保留、预设保存 / 应用、原始恢复、重应用、只读刷新和回读失败后的回退。模拟测试不加载驱动、不写真实硬件。`verify-*.sh` 是实机写入测试，仅在已经正确安装并理解其最终恢复行为时使用。

## 文件位置与卸载

- 应用：`/Applications/12Limit Power.app`
- 原始备份、设备信息、日志与后端：`/Library/Application Support/FYQMac`
- 系统启动服务：`/Library/LaunchDaemons/local.fyqmac.power.plist`
- 用户登录服务：`~/Library/LaunchAgents/local.fyqmac.menu.plist`
- 请求队列：`~/Library/Application Support/FYQMacControl`

从完整安装包目录执行：

```sh
sudo bash scripts/uninstall.sh
```

卸载先恢复并验证原始配置，再卸载驱动与启动任务；失败时保留文件，便于排查。卸载后如需恢复默认 SIP 策略，进入恢复模式终端执行 `csrutil enable` 并重启。应用不会自动恢复 SIP。

## 开源参考与许可

- [VoltageShift](https://github.com/sicreative/VoltageShift)：实际使用的驱动与命令行后端；随附官方 1.25 分发包，内部 kext 版本标为 1.24。源码快照 `a4b02ebbcbdada286e2b49346405d57199b78eab`。
- [Turbo Boost Switcher](https://github.com/rugarciap/Turbo-Boost-Switcher)：参考 Intel 睿频开关方式，不提供独立核显限频。
- [LowPowerAutomator](https://github.com/danielalanbates/lowpowerautomator)：参考低电量触发思路；本机 `pmset -g custom` 未报告 `lowpowermode`，本版未集成该功能。
- [CPUTune](https://github.com/syscl/CPUTune)：HWP / 倍率控制研究路径，默认系统支持至 macOS 10.15，未直接移植到 Ventura。
- [TurboTune](https://github.com/tc466/TurboTune)：按 CPU 型号设置倍率的研究参考。原 m3 测试写入后读回原值，本版未开放锁频。
- [WhateverGreen](https://github.com/acidanthera/WhateverGreen)、[CPUFriend](https://github.com/acidanthera/CPUFriend)、[CPUFriendFriend](https://github.com/corpnewt/CPUFriendFriend)：仅研究，未安装或作为新依赖打包。
- [Stats](https://github.com/exelban/stats)：界面分区参考，未复制监控实现。

项目为 GPL-3.0，见 [LICENSE](LICENSE)。除随附 VoltageShift 外，上述参考项目未复制代码或打包为额外依赖。

## 版本历史

- v1.3.0-m3 / v1.3.0-i7：分别编译并校验 CPU，动态安装账户、本机基线初始化、后端未就绪提示、完整安装教程与临时目录安装器。
- v1.2.0：独立编辑与保存平衡 / 节能档位、保存与应用分离、动态菜单标签。
- v1.1.0：更名 12Limit Power，增加原生窗口、自定义功耗与平均时间、失败回退。
- v1.0.0：FYQMac 菜单栏、固定档位、启动恢复与回读验证。
