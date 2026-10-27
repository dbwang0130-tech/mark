# Mark

极简的 macOS Markdown 阅读器 + Finder 快速查看（空格预览）扩展。纯原生实现，不打包任何 JS 库。

- **空格预览**：在 Finder 中选中 `.md` 按空格即可预览
- **双击阅读**：独立的极简阅读窗口，支持缩放（⌘+ / ⌘- / ⌘0）、打印、共享
- **GFM**：表格、任务列表、删除线、自动链接、脚注、YAML front matter
- **LaTeX 公式**：`$...$`、`$$...$$`、`\(...\)`、`\[...\]`、` ```math `，转换成 MathML 交给系统 WebKit 原生排版
- **代码高亮**：40 多种语言，自研的轻量词法高亮
- **配色方案**：系统 / GitHub / Solarized / Nord / 纸墨，可选跟随系统、浅色、深色；阅读器与空格预览共用设置（⌘,）
- **本地图片**：支持相对路径引用的图片

## 实现

| 部分 | 方案 |
|---|---|
| Markdown 解析 | [cmark-gfm](https://github.com/apple/swift-cmark)（Apple 维护的 gfm 分支） |
| LaTeX | 自研 LaTeX → MathML 转换器（`MarkdownCore/Sources/MarkdownCore/Math`） |
| 代码高亮 | 自研按字节扫描的高亮器（`MarkdownCore/Sources/MarkdownCore/Highlight`） |
| 预览扩展 | Quick Look data-based preview，输出静态 HTML |
| 阅读器 | SwiftUI `DocumentGroup` + `WKWebView` |

## 构建

需要 Xcode 26+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
./build.sh          # 构建、签名并安装到 /Applications/Mark.app，同时注册 Quick Look 扩展
```

签名使用 `project.yml` 中的 `DEVELOPMENT_TEAM`。用自己的开发者账号构建时，需要把以下位置的团队 ID `586LZ975EV` 换成你自己的：

- `project.yml`
- `App/App.entitlements`、`QuickLook/QuickLook.entitlements`（App Group）
- `MarkdownCore/Sources/MarkdownCore/Theme.swift`（`RenderSettings.suiteName`）

渲染核心可以单独用命令行调试：

```bash
cd MarkdownCore
swift build -c release
.build/release/mdrender ../Samples/demo.md out.html [system|github|solarized|nord|sepia] [system|light|dark]
```

## 目录

```
App/            阅读器（SwiftUI）
QuickLook/      Quick Look 预览扩展
MarkdownCore/   渲染核心（Swift Package）：Markdown → HTML、LaTeX → MathML、代码高亮、配色
Tools/          图标源文件（icon.svg）与生成脚本
Samples/        示例文档
```

## 许可

MIT
