import SwiftUI

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var searchText = ""
    @State private var showingSettings = false
    @AppStorage("maxItems") private var maxItems = 100
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.items
        }
        return clipboardManager.items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索剪贴板历史", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 列表视图
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        ClipboardItemRow(item: item)
                            .onTapGesture {
                                clipboardManager.copyToClipboard(item)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    clipboardManager.deleteItem(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingSettings) {
            SettingsView(maxItems: $maxItems)
        }
    }
}

struct KeyRecorder: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var isRecording: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = RecorderView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? RecorderView {
            view.isRecording = isRecording
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: KeyRecorder
        
        init(_ parent: KeyRecorder) {
            self.parent = parent
        }
        
        func recordKey(keyCode: Int, modifiers: Int) {
            parent.keyCode = keyCode
            parent.modifiers = modifiers
            parent.isRecording = false
        }
    }
    
    class RecorderView: NSView {
        var isRecording = false {
            didSet {
                needsDisplay = true
                if isRecording {
                    window?.makeFirstResponder(self)
                }
            }
        }
        
        var delegate: Coordinator?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if isRecording {
                let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
                
                // 确保至少按了一个修饰键
                if !mods.isEmpty {
                    let keyCode = Int(event.keyCode)
                    let modifiers = Int(mods.rawValue)
                    delegate?.recordKey(keyCode: keyCode, modifiers: modifiers)
                }
            } else {
                super.keyDown(with: event)
            }
        }
        
        override func flagsChanged(with event: NSEvent) {
            needsDisplay = true
            super.flagsChanged(with: event)
        }
        
        override func draw(_ dirtyRect: NSRect) {
            let backgroundColor = isRecording ? NSColor.systemRed.withAlphaComponent(0.2) : NSColor.systemGray.withAlphaComponent(0.2)
            backgroundColor.setFill()
            dirtyRect.fill()
        }
    }
}

struct SettingsView: View {
    @Binding var maxItems: Int
    @Environment(\.dismiss) var dismiss
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = 768 // command + shift (256 + 512)
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode = 3 // F key
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.title2)
                .padding(.top)
            
            HStack {
                Text("最大历史记录数")
                Spacer()
                TextField("", value: $maxItems, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("全局快捷键")
                
                Button(action: {
                    isRecording.toggle()
                }) {
                    HStack {
                        Text(isRecording ? "按下新快捷键..." : shortcutDisplayName)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .overlay(
                    KeyRecorder(keyCode: $shortcutKeyCode, modifiers: $shortcutModifiers, isRecording: $isRecording)
                        .opacity(0.01) // 几乎透明但可点击
                )
                .background(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(5)
                
                Text("提示：快捷键必须包含至少一个修饰键 (⌘, ⌥, ⇧, ⌃)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Button("确定") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 300, height: 220)
        .background(.ultraThinMaterial)
    }
    
    var shortcutDisplayName: String {
        let modifierNames: [(NSEvent.ModifierFlags, String)] = [
            (.command, "⌘"),
            (.option, "⌥"),
            (.shift, "⇧"),
            (.control, "⌃")
        ]
        
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(shortcutModifiers))
        let modifierString = modifierNames.compactMap { modifierFlags.contains($0.0) ? $0.1 : nil }.joined()
        
        let keyName: String
        switch shortcutKeyCode {
        case 0: keyName = "A"
        case 1: keyName = "S"
        case 2: keyName = "D"
        case 3: keyName = "F"
        case 4: keyName = "H"
        case 5: keyName = "G"
        case 6: keyName = "Z"
        case 7: keyName = "X"
        case 8: keyName = "C"
        case 9: keyName = "V"
        case 11: keyName = "B"
        case 12: keyName = "Q"
        case 13: keyName = "W"
        case 14: keyName = "E"
        case 15: keyName = "R"
        case 16: keyName = "Y"
        case 17: keyName = "T"
        case 31: keyName = "O"
        case 32: keyName = "U"
        case 33: keyName = "Ü"
        case 34: keyName = "I"
        case 35: keyName = "P"
        case 37: keyName = "L"
        case 38: keyName = "J"
        case 40: keyName = "K"
        case 45: keyName = "N"
        case 46: keyName = "M"
        default: keyName = "Key(\(shortcutKeyCode))"
        }
        
        return "\(modifierString)\(keyName)"
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Text(item.content)
                .lineLimit(2)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "doc.on.doc")
                .foregroundColor(.gray)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
