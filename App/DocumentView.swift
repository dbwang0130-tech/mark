import MarkdownCore
import SwiftUI
import UniformTypeIdentifiers
import WebKit

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

/// 只读的 Markdown 文档
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown] }

    let text: String

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        text = MarkdownRenderer.decodeText(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.featureUnsupported)
    }
}

struct DocumentView: View {
    let text: String
    let fileURL: URL?

    @AppStorage("zoom") private var zoom = 1.0
    @AppStorage(RenderSettings.themeKey, store: RenderSettings.defaults) private var theme = Theme.system
    @AppStorage(RenderSettings.appearanceKey, store: RenderSettings.defaults) private var appearance = Appearance.system
    @StateObject private var holder = WebViewHolder()
    @State private var html = ""

    var body: some View {
        MarkdownWebView(html: html, zoom: zoom, appearance: appearance, holder: holder)
            .frame(minWidth: 480, idealWidth: 820, minHeight: 360, idealHeight: 900)
            .focusedSceneValue(\.webViewHolder, holder)
            .toolbar {
                if let fileURL {
                    ShareLink(item: fileURL)
                }
            }
            // 设置里切换配色时重新渲染
            .task(id: RenderStyle(theme: theme, appearance: appearance)) {
                html = render(style: RenderStyle(theme: theme, appearance: appearance))
            }
    }

    private func render(style: RenderStyle) -> String {
        let base = fileURL?.deletingLastPathComponent()
        var imageBytes = 0
        return MarkdownRenderer.renderDocument(text, title: fileURL?.lastPathComponent ?? "", style: style) { src in
            // 本地图片转成 data: URI 内嵌，避免 WebView 读取本地文件的权限问题
            guard let base, let url = MarkdownRenderer.localImageURL(src, relativeTo: base),
                  let data = try? Data(contentsOf: url),
                  imageBytes + data.count <= 32 * 1024 * 1024 else { return nil }
            imageBytes += data.count
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
            return "data:\(mime);base64,\(data.base64EncodedString())"
        }
    }
}

// MARK: - WebView

/// 持有当前窗口的 WebView，供菜单命令（打印）使用
final class WebViewHolder: ObservableObject {
    weak var webView: WKWebView?

    func print() {
        guard let webView, let window = webView.window else { return }
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        let operation = webView.printOperation(with: info)
        operation.view?.frame = webView.bounds
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
}

private struct WebViewHolderKey: FocusedValueKey {
    typealias Value = WebViewHolder
}

extension FocusedValues {
    var webViewHolder: WebViewHolder? {
        get { self[WebViewHolderKey.self] }
        set { self[WebViewHolderKey.self] = newValue }
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let zoom: Double
    var appearance: Appearance = .system
    var holder: WebViewHolder?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        holder?.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.loadedHTML != html {
            let isReload = !coordinator.loadedHTML.isEmpty
            coordinator.loadedHTML = html
            if isReload {
                // 重新渲染（如切换配色）时保留滚动位置
                webView.evaluateJavaScript("window.scrollY") { y, _ in
                    coordinator.restoreScrollY = y as? Double
                    webView.loadHTMLString(html, baseURL: nil)
                }
            } else {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        // 强制浅色 / 深色时，滚动条等原生控件也跟着切换
        let name: NSAppearance.Name? = appearance == .light ? .aqua : appearance == .dark ? .darkAqua : nil
        if webView.appearance?.name != name { webView.appearance = name.map { NSAppearance(named: $0)! } }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML = ""
        var restoreScrollY: Double?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let y = restoreScrollY else { return }
            restoreScrollY = nil
            webView.evaluateJavaScript("window.scrollTo(0, \(y))")
        }

        /// 页内锚点（脚注）在 WebView 内跳转，其余链接交给系统默认 App
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url,
                  url.scheme != "about" else {
                decisionHandler(.allow)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}
