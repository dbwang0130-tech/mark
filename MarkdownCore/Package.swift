// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkdownCore", targets: ["MarkdownCore"]),
        .executable(name: "mdrender", targets: ["mdrender"]),
    ],
    dependencies: [
        // apple/swift-cmark 的 gfm 分支（cmark-gfm），固定到具体提交
        .package(url: "https://github.com/apple/swift-cmark.git", revision: "a7ecfef490df1b17927ea828bc2a73cc0b69990d"),
    ],
    targets: [
        .target(
            name: "MarkdownCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ]
        ),
        .executableTarget(name: "mdrender", dependencies: ["MarkdownCore"]),
    ]
)
