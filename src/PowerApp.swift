import AppKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let backend = URL(fileURLWithPath: "/Library/Application Support/FYQMac")
    let control = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/FYQMacControl")
    let loginPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/local.fyqmac.menu.plist")
    var item: NSStatusItem!
    let menu = NSMenu()
    var window: NSWindow?
    var watcher: DispatchSourceFileSystemObject?
    var wakeObserver: NSObjectProtocol?
    var pending: String?
    var timeout: DispatchWorkItem?
    var statusLabel: NSTextField!
    var sampleLabel: NSTextField!
    var actualLabel: NSTextField!
    var pl1: NSTextField!
    var pl2: NSTextField!
    var step1: NSStepper!
    var step2: NSStepper!
    var turbo: NSButton!
    var login: NSButton!
    var tau: NSPopUpButton!
    var applyButton: NSButton!
    let windows = [0,1,2,4,8,16,28]
    var preview: Bool { CommandLine.arguments.contains("--preview") }
    func read(_ name: String) -> String {
        (try? String(contentsOf: backend.appendingPathComponent(name), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
    }
    func json(_ name: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: backend.appendingPathComponent(name)), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }
    func maxPower(_ key: String) -> Double { (json("capabilities.json")[key] as? NSNumber)?.doubleValue ?? 49 }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: "12Limit Power")
        item.button?.toolTip = "12Limit Power · 功耗控制"
        menu.delegate = self; item.menu = menu; rebuildMenu()
        if !preview {
            let fd = open(backend.path, O_EVTONLY)
            if fd >= 0 {
                let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
                source.setEventHandler { [weak self] in self?.updateStatus() }
                source.setCancelHandler { close(fd) }; source.resume(); watcher = source
            }
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.request("reapply") }
        }
        if !CommandLine.arguments.contains("--background") { showWindow() }
        if preview {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.6) {
                guard let view = self.window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                if CommandLine.arguments.contains("--self-test") { self.selfTest() }
                view.cacheDisplay(in: view.bounds, to: rep)
                let path = ProcessInfo.processInfo.environment["LIMIT_PREVIEW_PATH"] ?? "/Users/skyfu/Downloads/FYQMac/build/preview.png"
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                print("Window rendered; two power inputs, turbo, averaging window, login and presets available.")
                NSApp.terminate(nil)
            }
        }
    }
    func installMainMenu() {
        let main = NSMenu(); let appMenu = NSMenu(); let appRow = NSMenuItem(); appRow.submenu = appMenu; main.addItem(appRow)
        appMenu.addItem(withTitle: "退出 12Limit Power", action: #selector(quit), keyEquivalent: "q").target = self
        let edit = NSMenu(title: "编辑"); let editRow = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); editRow.submenu = edit; main.addItem(editRow)
        for (title,action,key) in [("剪切","cut:","x"),("复制","copy:","c"),("粘贴","paste:","v"),("全选","selectAll:","a")] { edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        NSApp.mainMenu = main
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func menuWillOpen(_ menu: NSMenu) { rebuildMenu() }
    @discardableResult func row(_ title: String, _ action: Selector? = nil, tag: Int = 0) -> NSMenuItem {
        let r = NSMenuItem(title: title, action: action, keyEquivalent: ""); r.target = self; r.tag = tag; menu.addItem(r); return r
    }
    func rebuildMenu() {
        menu.removeAllItems()
        row("12Limit Power", #selector(showWindow))
        row(read("status.txt").replacingOccurrences(of: "睿频 1", with: "睿频开").replacingOccurrences(of: "睿频 0", with: "睿频关")).isEnabled = false
        menu.addItem(.separator())
        for (i,title) in ["平衡 · 5 / 6 W", "节能 · 5 / 5 W · 关闭睿频", "上次自定义配置", "恢复原始设置"].enumerated() {
            let r = row(title, #selector(preset(_:)), tag: i)
            r.state = read("selected.txt") == ["balance","quiet","custom","original"][i] ? .on : .off
            if i == 2 { r.isEnabled = !read("custom.txt").isEmpty }
        }
        menu.addItem(.separator())
        row("刷新读数", #selector(refresh)); row("诊断日志", #selector(diagnose)); row("退出", #selector(quit))
    }
    func text(_ value: String, size: CGFloat = 13, color: NSColor = .labelColor, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value); label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
        label.setContentCompressionResistancePriority(.required, for: .vertical); return label
    }
    func horizontal(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let s = NSStackView(views: views); s.orientation = .horizontal; s.alignment = .centerY; s.spacing = spacing; return s
    }
    func spacer() -> NSView { let v = NSView(); v.setContentHuggingPriority(.defaultLow, for: .horizontal); return v }
    func button(_ title: String, _ action: Selector, tag: Int = 0) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; b.tag = tag; return b
    }
    func separator() -> NSBox { let b = NSBox(); b.boxType = .separator; return b }
    func powerRow(_ title: String, index: Int) -> NSStackView {
        let field = NSTextField(string: "5.000"); field.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium); field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 100).isActive = true
        field.target = self; field.action = #selector(normalizeFields)
        field.setAccessibilityLabel(title)
        let step = NSStepper(); step.minValue = 3.75; step.maxValue = maxPower(index == 1 ? "maxPL1" : "maxPL2"); step.increment = 0.125; step.valueWraps = false
        step.target = self; step.action = #selector(stepped(_:)); step.tag = index
        if index == 1 { pl1 = field; step1 = step } else { pl2 = field; step2 = step }
        return horizontal([text(title,size:14,weight:.medium),spacer(),field,text("W",color:.secondaryLabelColor),step])
    }
    @objc func showWindow() {
        if window == nil { buildWindow() }
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
        loadFields(); updateStatus()
        if !preview { request("refresh") }
    }
    func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x:0,y:0,width:620,height:700), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        w.title = "12Limit Power"; w.isReleasedWhenClosed = false; w.delegate = self; w.center(); window = w
        let content = NSView(); content.wantsLayer = true; content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor; w.contentView = content
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13; stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:24),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-24),stack.topAnchor.constraint(equalTo:content.topAnchor,constant:22)])
        func add(_ view: NSView, full: Bool = true) { stack.addArrangedSubview(view); if full { view.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive = true } }
        add(text("12Limit Power",size:26,weight:.semibold))
        add(text("12 英寸 MacBook · Core m3-7Y32 · 轻量功耗控制",color:.secondaryLabelColor))
        statusLabel = text("读取状态…",size:12,color:.secondaryLabelColor); add(statusLabel)
        actualLabel = text("",size:13,weight:.medium); add(actualLabel)
        sampleLabel = text("",size:13,color:.secondaryLabelColor); add(sampleLabel)
        add(separator())
        add(horizontal([text("功耗设置",size:17,weight:.semibold),spacer(),button("平衡",#selector(preset(_:)),tag:0),button("节能",#selector(preset(_:)),tag:1)]))
        add(powerRow("持续功耗 · PL1",index:1)); add(powerRow("短时功耗 · PL2",index:2))
        let max1=maxPower("maxPL1"),max2=maxPower("maxPL2")
        add(text(String(format:"步进 0.125W · PL1 3.75–%.3gW · PL2 ≥ PL1、≤ %.3gW",max1,max2),size:12,color:.secondaryLabelColor))
        add(text("无风扇机型建议持续 3.75–7W。固件原始 49W 是限值，并非可持续散热能力。封装限值也覆盖核显，不是整机功耗。",size:12,color:.secondaryLabelColor))
        turbo = NSButton(checkboxWithTitle: "允许 Intel 睿频", target:self, action:nil); add(turbo)
        tau = NSPopUpButton(); tau.addItems(withTitles:["沿用原始时间","1 秒","2 秒","4 秒","8 秒","16 秒","28 秒"])
        add(horizontal([text("持续功耗平均时间"),spacer(),tau]))
        add(text("较短时间会更快压低持续功耗；短时窗口沿用原始值。CPU 频率仍由系统动态调节。",size:12,color:.secondaryLabelColor))
        add(separator())
        add(text("硬件能力",size:15,weight:.semibold))
        add(text("CPU 指定频率 / 锁频：本机固件未接受倍率修改。\nGPU 独立调节：暂无本机验证有效的接口；共享封装功耗。",size:12,color:.secondaryLabelColor))
        applyButton = button("应用自定义",#selector(applyCustom)); applyButton.keyEquivalent = "\r"
        add(horizontal([button("保存为常用",#selector(saveFavorite)),button("载入常用",#selector(loadFavorite)),spacer(),applyButton]))
        add(horizontal([button("恢复原始设置",#selector(preset(_:)),tag:3),spacer(),button("刷新读数",#selector(refresh)),button("诊断",#selector(diagnose))]))
        login = NSButton(checkboxWithTitle: "登录时启动（窗口保持收起）", target:self, action:#selector(toggleLogin)); add(login)
        add(text("关闭窗口后保留菜单栏；退出应用不会取消已应用的功耗限值。读数按需采样，不持续轮询。",size:11,color:.tertiaryLabelColor))
        stack.layoutSubtreeIfNeeded()
        let desired=stack.fittingSize.height+44
        w.setContentSize(NSSize(width:620,height:max(700,desired))); w.center()
    }
    func loadFields() {
        let s=json("settings.json")
        let first: Double = (s["pl1"] as? NSNumber)?.doubleValue ?? 5.0
        let second: Double = (s["pl2"] as? NSNumber)?.doubleValue ?? 6.0
        pl1?.stringValue=String(format:"%.3f",first)
        pl2?.stringValue=String(format:"%.3f",second)
        turbo?.state=((s["turbo"] as? Bool) ?? true) ? .on : .off
        tau?.selectItem(at: windows.firstIndex(of:(s["tau"] as? Int) ?? 0) ?? 0)
        syncSteppers(); login?.state=FileManager.default.fileExists(atPath:loginPlist.path) ? .on : .off
    }
    func syncSteppers() { step1?.doubleValue=pl1?.doubleValue ?? 5; step2?.doubleValue=pl2?.doubleValue ?? 6 }
    @objc func stepped(_ sender: NSStepper) { (sender.tag == 1 ? pl1 : pl2)?.stringValue=String(format:"%.3f",sender.doubleValue) }
    @objc func normalizeFields() { syncSteppers() }
    func draft() throws -> (Int,Int,Int,Int) {
        guard let a=Double(pl1.stringValue),let b=Double(pl2.stringValue),a.isFinite,b.isFinite,
              a>=3.75,a<=maxPower("maxPL1"),b>=a,b<=maxPower("maxPL2"),abs(a*8-(a*8).rounded())<0.00001,abs(b*8-(b*8).rounded())<0.00001 else {
            throw NSError(domain:"12LimitPower",code:1,userInfo:[NSLocalizedDescriptionKey:"请输入范围内的数值，步进为 0.125W，并保证短时功耗不小于持续功耗。"])
        }
        return (Int((a*8).rounded()),Int((b*8).rounded()),turbo.state == .on ? 1 : 0,windows[tau.indexOfSelectedItem])
    }
    func selfTest() {
        pl1.stringValue="5.125"; pl2.stringValue="6.250"; turbo.state = .off; tau.selectItem(at:4)
        let value=try! draft(); precondition(value.0==41 && value.1==50 && value.2==0 && value.3==8)
        syncSteppers(); precondition(step1.doubleValue==5.125 && step2.doubleValue==6.25)
        step1.doubleValue=4.5; stepped(step1); precondition(pl1.stringValue=="4.500")
        for pair in [("2","6"),("5","4"),("49.125","49.125"),("5.1","6"),("nan","6")] {
            pl1.stringValue=pair.0; pl2.stringValue=pair.1
            precondition((try? draft()) == nil)
        }
        loadFields(); print("UI_SMOKE_PASS: input, stepping, turbo, averaging window and invalid values")
    }
    @objc func applyCustom() {
        do { let (a,b,t,w)=try draft(); request("custom \(a) \(b) \(t) \(w)") } catch { alert(error.localizedDescription) }
    }
    @objc func saveFavorite() {
        do { let(a,b,t,w)=try draft(); UserDefaults.standard.set([a,b,t,w],forKey:"favorite"); statusLabel.stringValue="常用配置已保存；应用后才会改变功耗。" } catch { alert(error.localizedDescription) }
    }
    @objc func loadFavorite() {
        guard let v=UserDefaults.standard.array(forKey:"favorite") as? [Int],v.count==4,let i=windows.firstIndex(of:v[3]) else { alert("尚未保存常用配置。");return }
        pl1.stringValue=String(format:"%.3f",Double(v[0])/8); pl2.stringValue=String(format:"%.3f",Double(v[1])/8); turbo.state=v[2] == 1 ? .on : .off; tau.selectItem(at:i); syncSteppers()
        statusLabel.stringValue="常用配置已载入；点击应用自定义生效。"
    }
    @objc func preset(_ sender: AnyObject) {
        let tag: Int
        if let r=sender as? NSMenuItem {tag=r.tag} else if let b=sender as? NSButton {tag=b.tag} else {return}
        if tag == 2 { let v=read("custom.txt"); if !v.isEmpty {request("custom "+v)}; return }
        request(["balance","quiet","custom","original"][tag])
    }
    func request(_ command: String) {
        if preview {return}
        guard pending == nil else {return}
        do {
            try FileManager.default.createDirectory(at:control,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let id=UUID().uuidString; pending=id
            try Data("\(command)\n\(id)\n".utf8).write(to:control.appendingPathComponent("request"),options:.atomic)
            applyButton?.isEnabled=false; statusLabel?.stringValue="等待硬件回读验证…"
            let work=DispatchWorkItem { [weak self] in
                guard let self=self,self.pending==id else{return}
                self.pending=nil; self.applyButton?.isEnabled=true; self.statusLabel?.stringValue="尚未收到验证结果，请刷新读数或查看诊断。"
            }; timeout=work; DispatchQueue.main.asyncAfter(deadline:.now()+15,execute:work)
        } catch { pending=nil; applyButton?.isEnabled=true; alert(error.localizedDescription) }
    }
    func updateStatus() {
        let s=read("status.txt")
        if let id=pending {
            if read("request-id.txt") == id {
                pending=nil; timeout?.cancel(); timeout=nil; applyButton?.isEnabled=true
                if s.contains("已回读验证") {loadFields()}
            } else { return }
        }
        statusLabel?.stringValue=s.replacingOccurrences(of:"睿频 1",with:"睿频开").replacingOccurrences(of:"睿频 0",with:"睿频关")
        let a=json("actual.json")
        if let p=a["pl1"] as? NSNumber,let q=a["pl2"] as? NSNumber {
            actualLabel?.stringValue=String(format:"硬件读回  ·  %.3g / %.3g W  ·  睿频%@",p.doubleValue,q.doubleValue,(a["turbo"] as? Bool) == true ? "开启":"关闭")
        }
        let info=read("current-info.txt")
        let pattern=#"CPU Freq:\s*([0-9.]+)ghz.*?Power:pkg\s*([0-9.]+)w.*?Temp:\s*([0-9]+)\s*c"#
        if let regex=try? NSRegularExpression(pattern:pattern),let m=regex.firstMatch(in:info,range:NSRange(info.startIndex...,in:info)) {
            let t=info as NSString
            let stamp=(try? FileManager.default.attributesOfItem(atPath:backend.appendingPathComponent("current-info.txt").path)[.modificationDate]) as? Date
            let time=stamp.map { DateFormatter.localizedString(from:$0,dateStyle:.none,timeStyle:.medium) } ?? "未知"
            sampleLabel?.stringValue="\(t.substring(with:m.range(at:1))) GHz   ·   \(t.substring(with:m.range(at:2))) W   ·   \(t.substring(with:m.range(at:3))) °C   ·   采样 \(time)"
        }
        rebuildMenu()
    }
    @objc func refresh() { request("refresh") }
    @objc func diagnose() { NSWorkspace.shared.open(backend.appendingPathComponent("controller.log")) }
    @objc func toggleLogin() {
        do {
            if login.state == .off { try FileManager.default.removeItem(at:loginPlist) }
            else {
                try FileManager.default.createDirectory(at:loginPlist.deletingLastPathComponent(),withIntermediateDirectories:true)
                let config:[String:Any]=["Label":"local.fyqmac.menu","ProgramArguments":[Bundle.main.executablePath!,"--background"],"RunAtLoad":true,"ProcessType":"Interactive"]
                try PropertyListSerialization.data(fromPropertyList:config,format:.xml,options:0).write(to:loginPlist,options:.atomic)
            }
        } catch {login.state=FileManager.default.fileExists(atPath:loginPlist.path) ? .on:.off; alert(error.localizedDescription)}
    }
    func alert(_ message: String) { NSApp.activate(ignoringOtherApps:true); let a=NSAlert();a.messageText="12Limit Power";a.informativeText=message;a.addButton(withTitle:"好");a.runModal() }
    @objc func quit() { NSApp.terminate(nil) }
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.run()
