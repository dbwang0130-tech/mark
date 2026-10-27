// 由 Tools/icon.svg 生成 App 图标（Icon Composer 的 .icon 格式）。
// SVG 第一个 path 是圆角底板：只取它的颜色作为图标背景，形状交给系统遮罩；
// 其余 path（白色 M）渲染成字形图层。
// 用法：swift Tools/make_icon.swift Tools/icon.svg App/AppIcon.icon

import AppKit

let svgURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconDir = URL(fileURLWithPath: CommandLine.arguments[2])
let assets = iconDir.appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: iconDir)
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

let svg = try! String(contentsOf: svgURL, encoding: .utf8)
guard let first = svg.range(of: #"<path[^>]*>(</path>)?"#, options: .regularExpression) else {
    fatalError("SVG 中没有 path")
}
let backgroundPath = String(svg[first])
let glyphSVG = svg.replacingCharacters(in: first, with: "")

// 背景色：#RRGGBB → extended-srgb
let hex = backgroundPath.range(of: #"#[0-9A-Fa-f]{6}"#, options: .regularExpression).map { String(backgroundPath[$0].dropFirst()) } ?? "000000"
let rgb = stride(from: 0, to: 6, by: 2).map { i -> String in
    let start = hex.index(hex.startIndex, offsetBy: i)
    let value = Double(Int(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!) / 255
    return String(format: "%.5f", value)
}
let background = "extended-srgb:\(rgb.joined(separator: ",")),1.00000"

// 字形图层：1024×1024 透明 PNG
let glyph = NSImage(data: Data(glyphSVG.utf8))!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
glyph.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("glyph.png"))

let json = """
{
  "fill" : { "solid" : "\(background)" },
  "groups" : [
    {
      "layers" : [
        {
          "glass" : true,
          "hidden" : false,
          "image-name" : "glyph.png",
          "name" : "glyph",
          "position" : { "scale" : 1, "translation-in-points" : [ 0, 0 ] }
        }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.5 }
    }
  ],
  "supported-platforms" : { "squares" : "shared" }
}
"""
try! json.write(to: iconDir.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
print("背景色 #\(hex)，字形已写入 \(assets.path)/glyph.png")
