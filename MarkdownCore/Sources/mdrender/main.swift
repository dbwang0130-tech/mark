// 命令行调试工具：mdrender input.md [output.html] [主题] [外观]

import Foundation
import MarkdownCore

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("用法: mdrender input.md [output.html] [system|github|solarized|nord|sepia] [system|light|dark]\n".data(using: .utf8)!)
    exit(1)
}
let input = URL(fileURLWithPath: args[1])
let markdown = (try? String(contentsOf: input, encoding: .utf8)) ?? ""
let start = DispatchTime.now()
let style = RenderStyle(theme: args.count > 3 ? Theme(rawValue: args[3]) ?? .system : .system,
                        appearance: args.count > 4 ? Appearance(rawValue: args[4]) ?? .system : .system)
let html = MarkdownRenderer.renderDocument(markdown, title: input.lastPathComponent, style: style)
let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
FileHandle.standardError.write(String(format: "渲染耗时 %.2f ms，输出 %d 字节\n", ms, html.utf8.count).data(using: .utf8)!)
if args.count >= 3 {
    try html.write(to: URL(fileURLWithPath: args[2]), atomically: true, encoding: .utf8)
} else {
    print(html)
}
