import SwiftUI

/// 使用说明窗口（帮助菜单）
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .padding(.bottom, 12)
            Text("Mark")
                .font(.title2.weight(.semibold))
            Text("版本 \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 14) {
                Feature(symbol: "eye", title: "按空格预览", detail: "在 Finder 中选中 .md 文件，按空格键即可快速查看。")
                Feature(symbol: "doc.text", title: "双击打开", detail: "双击 .md 文件在独立窗口中阅读，支持缩放、打印和共享。")
                Feature(symbol: "function", title: "公式与代码", detail: "支持 GFM 表格、任务列表、脚注、LaTeX 公式和代码高亮。")
                Feature(symbol: "puzzlepiece.extension", title: "启用扩展", detail: "如空格预览未生效，请在「登录项与扩展」的「快速查看」中打开本扩展。")
            }
            .padding(.top, 24)

            HStack {
                Button("打开扩展设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button("好") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, 28)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(width: 420)
    }
}

private struct Feature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
