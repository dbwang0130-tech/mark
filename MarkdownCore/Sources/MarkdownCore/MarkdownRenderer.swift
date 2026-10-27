import Foundation
import cmark_gfm
import cmark_gfm_extensions

public enum MarkdownRenderer {
    /// 图片地址改写：传入 Markdown 中的原始 src，返回替换后的 src（nil 表示不改）
    public typealias ImageResolver = (String) -> String?

    /// 渲染成完整 HTML 文档
    public static func renderDocument(_ markdown: String, title: String = "", style: RenderStyle = RenderStyle(),
                                      imageResolver: ImageResolver? = nil) -> String {
        let body = renderBody(markdown, imageResolver: imageResolver)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <meta name="color-scheme" content="\(style.appearance.colorScheme)">
        <title>\(escapeXML(title))</title>
        <style>\(Stylesheet.css(style))</style>
        </head><body><article class="markdown-body">
        \(body)
        </article></body></html>
        """
    }

    /// 只渲染 <body> 内的 HTML 片段
    public static func renderBody(_ markdown: String, imageResolver: ImageResolver? = nil) -> String {
        var text = markdown
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        var prefix = ""
        if let (frontMatter, rest) = splitFrontMatter(text) {
            prefix = codeBlockHTML(frontMatter, language: "yaml", extraClass: " front-matter")
            text = rest
        }

        let (protected, segments) = MathExtractor.extract(text)
        let html = renderCommonMark(protected, imageResolver: imageResolver)
        return prefix + MathExtractor.substitute(html, segments: segments)
    }

    // MARK: - cmark-gfm

    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]
    private static let registerExtensions: Void = cmark_gfm_core_extensions_ensure_registered()

    private static func renderCommonMark(_ markdown: String, imageResolver: ImageResolver?) -> String {
        _ = registerExtensions
        let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }
        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }
        var source = markdown
        source.withUTF8 { buf in
            buf.withMemoryRebound(to: CChar.self) { cmark_parser_feed(parser, $0.baseAddress, $0.count) }
        }
        guard let doc = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(doc) }

        // 收集需要替换的节点（遍历中不能直接改树）
        var codeBlocks: [UnsafeMutablePointer<cmark_node>] = []
        if let iter = cmark_iter_new(doc) {
            while true {
                let event = cmark_iter_next(iter)
                if event == CMARK_EVENT_DONE { break }
                guard event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iter) else { continue }
                let type = cmark_node_get_type(node)
                if type == CMARK_NODE_CODE_BLOCK {
                    codeBlocks.append(node)
                } else if type == CMARK_NODE_IMAGE, let resolver = imageResolver,
                          let url = cmark_node_get_url(node).map({ String(cString: $0) }),
                          let replaced = resolver(url) {
                    cmark_node_set_url(node, replaced)
                }
            }
            cmark_iter_free(iter)
        }

        for node in codeBlocks {
            let info = cmark_node_get_fence_info(node).map { String(cString: $0) } ?? ""
            let code = cmark_node_get_literal(node).map { String(cString: $0) } ?? ""
            let language = info.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "{" }).first.map(String.init) ?? ""
            let html: String
            if language == "math" || language == "latex-math" || language == "katex" {
                let result = TeXToMathML.convert(code, display: true)
                let tag = result.tag.map { "<span class=\"math-tag\">\(escapeXML($0))</span>" } ?? ""
                html = "<div class=\"math-display\">\(result.mathML)\(tag)</div>\n"
            } else {
                html = codeBlockHTML(code, language: language)
            }
            guard let replacement = cmark_node_new(CMARK_NODE_HTML_BLOCK) else { continue }
            cmark_node_set_literal(replacement, html)
            cmark_node_replace(node, replacement)
            cmark_node_free(node)
        }

        guard let out = cmark_render_html(doc, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(out) }
        return String(cString: out)
    }

    // MARK: - 代码块

    static func codeBlockHTML(_ code: String, language: String, extraClass: String = "") -> String {
        let lang = language.lowercased()
        let body = lang.isEmpty ? nil : SyntaxHighlighter.highlight(code, language: lang)
        let langAttr = lang.isEmpty ? "" : " data-lang=\"\(escapeXML(lang))\""
        let codeClass = lang.isEmpty ? "" : " class=\"language-\(escapeXML(lang))\""
        return "<pre class=\"code-block\(extraClass)\"\(langAttr)><code\(codeClass)>\(body ?? SyntaxHighlighter.escape(code))</code></pre>\n"
    }

    // MARK: - YAML front matter

    private static func splitFrontMatter(_ text: String) -> (String, String)? {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else { return nil }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var index = 1
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "---" || line == "..." {
                let front = lines[1..<index].joined(separator: "\n")
                // 只有看起来像 YAML（含 key: value）才当作 front matter，避免误判开头的分隔线
                guard front.contains(":") else { return nil }
                let rest = lines[(index + 1)...].joined(separator: "\n")
                return (front, rest)
            }
            index += 1
        }
        return nil
    }
}
