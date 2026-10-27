import Foundation
import MarkdownCore
import Quartz
import os

private let log = Logger(subsystem: "com.markdownext.Mark.QuickLook", category: "preview")
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    /// 超过该大小的文件只渲染开头部分，避免预览卡顿
    private let maxBytes = 4 * 1024 * 1024
    /// 内嵌本地图片的总大小上限
    private let maxImageBytes = 32 * 1024 * 1024

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        log.info("预览开始 \(url.lastPathComponent, privacy: .public)")
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let markdown = MarkdownRenderer.decodeText(data)

        var attachments: [String: QLPreviewReplyAttachment] = [:]
        var imageBytes = 0
        let baseDirectory = url.deletingLastPathComponent()
        let html = MarkdownRenderer.renderDocument(markdown, title: url.lastPathComponent, style: RenderSettings.load()) { src in
            // 相对路径 / file:// 图片作为附件内嵌，通过 cid: 引用
            guard let imageURL = MarkdownRenderer.localImageURL(src, relativeTo: baseDirectory),
                  let imageData = try? Data(contentsOf: imageURL),
                  imageBytes + imageData.count <= self.maxImageBytes else { return nil }
            imageBytes += imageData.count
            let key = "img\(attachments.count)"
            let type = UTType(filenameExtension: imageURL.pathExtension) ?? .image
            attachments[key] = QLPreviewReplyAttachment(data: imageData, contentType: type)
            return "cid:\(key)"
        }

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { reply in
            reply.stringEncoding = .utf8
            reply.attachments = attachments
            return Data(html.utf8)
        }
        reply.title = url.lastPathComponent
        log.info("预览完成 html=\(html.utf8.count) 字节, 图片=\(attachments.count)")
        return reply
    }
}
