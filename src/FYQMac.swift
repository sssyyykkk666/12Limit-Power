import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let backend = URL(fileURLWithPath: "/Library/Application Support/FYQMac")
    let control = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/FYQMacControl")
    let loginPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/local.fyqmac.menu.plist")
    var item: NSStatusItem!
    var menu = NSMenu()
    var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⚡"
        item.button?.toolTip = "FYQMac · Intel Mac 功耗控制"
        menu.delegate = self
        item.menu = menu
        rebuildMenu()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.request(self.currentProfile())
        }
        request(currentProfile())
    }
    func read(_ name: String) -> String {
        (try? String(contentsOf: backend.appendingPathComponent(name), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
    }
    func currentProfile() -> String {
        let current = read("selected.txt")
        return ["quiet", "balance", "original"].contains(current) ? current : "balance"
    }
    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }
    @discardableResult
    func row(_ title: String, _ action: Selector? = nil, tag: Int = 0) -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: "")
        row.target = self; row.tag = tag
        menu.addItem(row)
        return row
    }
    func rebuildMenu() {
        menu.removeAllItems()
        row("FYQMac · MacBook 2017").isEnabled = false
        let status = read("status.txt")
        let displayed = status.replacingOccurrences(of: "睿频 1", with: "睿频开启")
            .replacingOccurrences(of: "睿频 0", with: "睿频关闭")
            .replacingOccurrences(of: "已回读验证", with: "已生效")
        row(status.isEmpty ? "等待功耗控制服务…" : displayed).isEnabled = false
        menu.addItem(.separator())
        let titles = ["平衡：持续 ≤5W / 短时 ≤6W · 睿频开启", "节能：持续 ≤5W / 短时 ≤5W · 睿频关闭", "恢复安装前的原始设置"]
        let profiles = ["balance", "quiet", "original"]
        for i in 0..<3 {
            let r = row(titles[i], #selector(choose(_:)), tag: i)
            r.state = currentProfile() == profiles[i] ? .on : .off
        }
        menu.addItem(.separator())
        row("重新应用并刷新状态", #selector(refresh))
        row("查看最近一次读数", #selector(details))
        row("查看诊断日志", #selector(diagnose))
        menu.addItem(.separator())
        row("登录时启动菜单栏", #selector(toggleLogin)).state = FileManager.default.fileExists(atPath: loginPlist.path) ? .on : .off
        row("关于与使用说明", #selector(about))
        row("退出菜单栏", #selector(quit))
    }
    func request(_ profile: String) {
        guard ["balance", "quiet", "original"].contains(profile) else { return }
        do {
            try FileManager.default.createDirectory(at: control, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            // The root service only accepts the fixed profile on the first line.
            let data = "\(profile)\n\(Date().timeIntervalSince1970)\n".data(using: .utf8)!
            try data.write(to: control.appendingPathComponent("request"), options: .atomic)
            item.button?.toolTip = "已请求应用，打开菜单查看回读结果"
        } catch { show("无法提交设置", error.localizedDescription) }
    }
    @objc func choose(_ sender: NSMenuItem) { request(["balance", "quiet", "original"][sender.tag]) }
    @objc func refresh() { request(currentProfile()) }
    @objc func details() {
        let info = read("current-info.txt")
        var stamp = "未知"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: backend.appendingPathComponent("current-info.txt").path), let date = attrs[.modificationDate] as? Date {
            stamp = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
        }
        var summary = "尚无有效读数，请查看诊断日志。"
        let pattern = #"CPU Freq:\s*([0-9.]+)ghz.*?Power:pkg\s*([0-9.]+)w.*?Temp:\s*([0-9]+)\s*c"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: info, range: NSRange(info.startIndex..., in: info)) {
            let text = info as NSString
            summary = "CPU 频率：\(text.substring(with: match.range(at: 1))) GHz\nCPU 封装功耗：\(text.substring(with: match.range(at: 2))) W\nCPU 温度：\(text.substring(with: match.range(at: 3))) °C"
        }
        show("最近一次读数", summary + "\n\n采样时间：\(stamp)\n读数采集于最近一次应用设置，菜单不会持续轮询。")
    }
    @objc func diagnose() { NSWorkspace.shared.open(backend.appendingPathComponent("controller.log")) }
    @objc func toggleLogin() {
        do {
            if FileManager.default.fileExists(atPath: loginPlist.path) {
                try FileManager.default.removeItem(at: loginPlist)
            } else {
                try FileManager.default.createDirectory(at: loginPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
                let config: [String: Any] = ["Label": "local.fyqmac.menu", "ProgramArguments": [Bundle.main.executablePath!], "RunAtLoad": true, "ProcessType": "Interactive"]
                try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0).write(to: loginPlist, options: .atomic)
            }
            rebuildMenu()
        } catch { show("自动启动设置失败", error.localizedDescription) }
    }
    @objc func about() {
        show("FYQMac 1.0", "为 MacBook10,1 / Core m3-7Y32 定制的轻量菜单栏。\n\n基于开源 VoltageShift 1.25，保留原始功耗寄存器和睿频状态。功耗档位只会下调限值，不会提高到原始限值以上。\n\n配置由系统服务在开机时恢复，菜单在唤醒时重新提交配置。退出菜单不取消功耗限制；需要取消时先选择恢复原始设置。\n\n原生 AppKit，无联网、无常驻监控定时器。\n源码与卸载脚本：/Users/skyfu/Downloads/FYQMac")
    }
    func show(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message
        alert.addButton(withTitle: "好"); alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
