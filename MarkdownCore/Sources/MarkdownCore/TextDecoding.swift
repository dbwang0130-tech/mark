import Foundation

extension MarkdownRenderer {
    /// 把文件内容解码成字符串：UTF-16（带 BOM）→ UTF-8（容忍末尾截断）→ GB18030 → 有损 UTF-8
    public static func decodeText(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let s = String(data: data, encoding: .utf16) { return s }
        // 截断可能切在 UTF-8 多字节字符中间：去掉末尾最多 3 字节再试
        for trim in 0...min(3, data.count) {
            if let s = String(data: data.dropLast(trim), encoding: .utf8) { return s }
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        return String(data: data, encoding: gb18030) ?? String(decoding: data, as: UTF8.self)
    }

    /// Markdown 中引用的本地图片路径 → 文件 URL；网络地址、data:、cid: 返回 nil
    public static func localImageURL(_ src: String, relativeTo base: URL) -> URL? {
        let lower = src.lowercased()
        if lower.hasPrefix("http:") || lower.hasPrefix("https:") || lower.hasPrefix("data:") || lower.hasPrefix("cid:") {
            return nil
        }
        if lower.hasPrefix("file://") { return URL(string: src) }
        let path = src.removingPercentEncoding ?? src
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        if path.hasPrefix("~/") { return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath) }
        return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
    }
}
