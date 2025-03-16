import SwiftUI
import Combine
import ApplicationServices

@main
struct clipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "YourStatusBarIconName")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        
        // 设置系统菜单
        setupMenu()
        
        // 设置全局快捷键
        setupShortcuts()
        
        // 监听设置变化
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupShortcuts()
            }
            .store(in: &cancellables)
        
        // 初始权限检查
        checkInitialPermissions()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "打开", action: #selector(togglePopover), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
        let shortcutGuideItem = NSMenuItem(title: "快捷键教程", action: #selector(showShortcutGuide), keyEquivalent: "")
        menu.addItem(shortcutGuideItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func setupShortcuts() {
        // 清除旧的监听器
        removeMonitors()
        
        // 获取保存的快捷键设置
        let keyCode = UserDefaults.standard.integer(forKey: "shortcutKeyCode")
        let modifiersValue = UserDefaults.standard.integer(forKey: "shortcutModifiers")
        
        // 如果没有保存的设置，使用默认值 (Command + Shift + F)
        let defaultModifiers = 768 // command + shift (256 + 512)
        let defaultKeyCode = 3 // F key
        
        let finalKeyCode = keyCode == 0 ? defaultKeyCode : keyCode
        let finalModifiers = modifiersValue == 0 ? defaultModifiers : modifiersValue
        
        // 转换为 ModifierFlags
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(finalModifiers))
        
        print("设置快捷键: \(finalKeyCode), 修饰键: \(finalModifiers), 原始值: \(modifierFlags.rawValue)")
        
        // 使用本地监听器确保权限正常
        if AXIsProcessTrusted() {
            print("有辅助功能权限，监听器将正常工作")
        } else {
            print("无辅助功能权限，请在系统偏好设置中授予权限")
            // 显示权限引导弹窗
            showAccessibilityPermissionAlert()
            
            // 请求辅助功能权限
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        
        // 添加本地监听器
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            print("检测到按键: \(event.keyCode), 修饰键: \(eventMods.rawValue)")
            
            if Int(event.keyCode) == finalKeyCode && eventMods.rawValue == UInt(finalModifiers) {
                print("快捷键匹配: \(finalKeyCode)")
                self?.togglePopover()
                return nil
            }
            return event
        }
        
        // 添加全局监听器
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if Int(event.keyCode) == finalKeyCode && eventMods.rawValue == UInt(finalModifiers) {
                print("全局快捷键触发: \(finalKeyCode)")
                self?.togglePopover()
            }
        }
    }
    
    func removeMonitors() {
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
    }
    
    // 新增权限引导弹窗方法
    func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "剪贴板管理器需要辅助功能权限才能使用全局快捷键功能。\n\n请按照以下步骤操作：\n1. 点击"打开系统设置"按钮\n2. 在"隐私与安全性"中找到"辅助功能"\n3. 在右侧列表中勾选"剪贴板管理器"应用\n4. 重启应用以使权限生效"
        alert.alertStyle = .warning
        
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后再说")
        
        // 使窗口置前
        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // 打开系统设置的辅助功能页面
                    if #available(macOS 13.0, *) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    } else {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                    }
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开系统设置的辅助功能页面
                if #available(macOS 13.0, *) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                } else {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
            }
        }
    }
    
    // 初始权限检查方法
    func checkInitialPermissions() {
        // 延迟1秒执行，确保UI已经加载完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if !AXIsProcessTrusted() {
                self?.showAccessibilityPermissionAlert()
            }
            
            // 检查是否首次启动应用
            let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if !hasLaunchedBefore {
                self?.showWelcomeGuide()
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }
        }
    }
    
    // 欢迎指引弹窗
    func showWelcomeGuide() {
        let alert = NSAlert()
        alert.messageText = "欢迎使用剪贴板管理器"
        alert.informativeText = "这是一个可以记录您剪贴板历史的便捷工具。\n\n基本使用：\n• 复制任何内容后，都会自动记录在历史中\n• 使用全局快捷键（默认为⌘⇧F）可以随时打开剪贴板历史\n• 点击任何历史记录可以再次复制使用\n• 在设置中可以自定义快捷键和最大历史记录条数\n\n开始使用吧！"
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "我知道了")
        
        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
    
    @objc func openSettings() {
        let settings = SettingsView(maxItems: Binding<Int>(
            get: { UserDefaults.standard.integer(forKey: "maxItems") },
            set: { UserDefaults.standard.set($0, forKey: "maxItems") }
        ))
        
        let hostingController = NSHostingController(rootView: settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = hostingController.view
        window.title = "设置"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    @objc func showShortcutGuide() {
        let alert = NSAlert()
        alert.messageText = "快捷键使用教程"
        alert.informativeText = "全局快捷键设置：\n\n1. 点击菜单栏中的设置选项\n2. 在设置窗口中，点击"全局快捷键"下的按钮\n3. 按下您想要设置的组合键（必须包含至少一个修饰键⌘⌥⇧⌃）\n4. 点击确定保存设置\n\n使用快捷键：\n在任何应用中按下您设置的快捷键组合，即可立即打开剪贴板历史。\n\n注意：快捷键功能需要辅助功能权限才能正常工作。"
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "我知道了")
        
        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
    
    deinit {
        removeMonitors()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// 辅助扩展
extension String {
    func fourCharCodeValue() -> UInt32 {
        var result: UInt32 = 0
        let chars = self.utf8
        var index = 0
        for char in chars {
            guard index < 4 else { break }
            result = result << 8 + UInt32(char)
            index += 1
        }
        while index < 4 {
            result = result << 8
            index += 1
        }
        return result
    }
}
