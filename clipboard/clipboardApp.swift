import SwiftUI
import Combine

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
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard")
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
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "打开", action: #selector(togglePopover), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
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
        
        print("设置快捷键: \(finalKeyCode), 修饰键: \(finalModifiers)")
        
        // 添加本地监听器
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if Int(event.keyCode) == finalKeyCode && eventMods == modifierFlags {
                self?.togglePopover()
                return nil
            }
            return event
        }
        
        // 添加全局监听器
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            
            if Int(event.keyCode) == finalKeyCode && eventMods == modifierFlags {
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
