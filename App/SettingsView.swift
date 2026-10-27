import MarkdownCore
import SwiftUI

/// 设置（⌘,）：配色方案与外观，App 和空格预览共用
struct SettingsView: View {
    @AppStorage(RenderSettings.themeKey, store: RenderSettings.defaults) private var theme = Theme.system
    @AppStorage(RenderSettings.appearanceKey, store: RenderSettings.defaults) private var appearance = Appearance.system

    private static let sample = #"""
    ## 标题
    正文与 **粗体**、[链接](#)、`行内代码`，公式 $e^{i\pi} + 1 = 0$。

    > 简洁是复杂的最终形式。

    ```swift
    // 注释
    func greet(_ name: String) -> Int {
        let n = 42
        return n + "hi".count
    }
    ```
    """#

    var body: some View {
        Form {
            Picker("配色方案", selection: $theme) {
                ForEach(Theme.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("外观", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Section("预览") {
                MarkdownWebView(html: MarkdownRenderer.renderDocument(Self.sample, style: RenderStyle(theme: theme, appearance: appearance)),
                                zoom: 0.85, appearance: appearance)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .listRowInsets(EdgeInsets())
            }

            Text("对双击打开的窗口和 Finder 空格预览同时生效。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}
