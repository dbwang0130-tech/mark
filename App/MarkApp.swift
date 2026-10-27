import SwiftUI

/// 极简 Markdown 阅读器：双击 .md 打开，交互参照「预览」。
@main
struct MarkApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            DocumentView(text: file.document.text, fileURL: file.fileURL)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ViewCommands()
            PrintCommands()
            CommandGroup(replacing: .help) { HelpButton() }
        }

        Settings {
            SettingsView()
        }

        Window("Mark 使用说明", id: "welcome") {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - 菜单

/// 显示 → 实际大小 / 放大 / 缩小
private struct ViewCommands: Commands {
    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ZoomButtons()
            Divider()
        }
    }
}

private struct ZoomButtons: View {
    @AppStorage("zoom") private var zoom = 1.0

    var body: some View {
        Button("实际大小") { zoom = 1 }
            .keyboardShortcut("0")
        Button("放大") { zoom = min(zoom + 0.1, 3) }
            .keyboardShortcut("+")
        Button("缩小") { zoom = max(zoom - 0.1, 0.5) }
            .keyboardShortcut("-")
    }
}

/// 文件 → 打印
private struct PrintCommands: Commands {
    @FocusedValue(\.webViewHolder) private var holder

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("打印…") { holder?.print() }
                .keyboardShortcut("p")
                .disabled(holder == nil)
        }
    }
}

private struct HelpButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Mark 使用说明") { openWindow(id: "welcome") }
    }
}
