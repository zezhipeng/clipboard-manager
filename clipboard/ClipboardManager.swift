import Foundation
import AppKit

class ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    
    init(content: String) {
        self.id = UUID()
        self.content = content
    }
}

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    private var maxItems: Int {
        UserDefaults.standard.integer(forKey: "maxItems")
    }
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var saveTimer: Timer?
    
    init() {
        lastChangeCount = pasteboard.changeCount
        // 设置默认值
        if UserDefaults.standard.integer(forKey: "maxItems") == 0 {
            UserDefaults.standard.set(100, forKey: "maxItems")
        }
        loadItems()
        startMonitoring()
    }
    
    private func startMonitoring() {
        // 使用更长的检查间隔，减少性能开销
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    private func checkForChanges() {
        // 使用 changeCount 来检测剪贴板是否真的发生变化
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount,
              let newString = pasteboard.string(forType: .string) else { return }
        
        lastChangeCount = currentChangeCount
        
        // 检查是否与最新的记录相同
        if items.first?.content != newString {
            addItem(newString)
        }
    }
    
    private func addItem(_ content: String) {
        let newItem = ClipboardItem(content: content)
        items.insert(newItem, at: 0)
        
        // 限制历史记录数量
        while items.count > maxItems {
            items.removeLast()
        }
        
        // 延迟保存，避免频繁写入
        scheduleSave()
    }
    
    private func scheduleSave() {
        // 取消之前的保存定时器
        saveTimer?.invalidate()
        
        // 创建新的定时器，延迟 1 秒后保存
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveItems()
        }
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        lastChangeCount = pasteboard.changeCount // 更新 changeCount
        deleteItem(item)
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        scheduleSave()
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "clipboardHistory")
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: "clipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
            // 确保加载的数据不超过当前设置的最大条数
            while items.count > maxItems {
                items.removeLast()
            }
            saveItems()
        }
    }
}
