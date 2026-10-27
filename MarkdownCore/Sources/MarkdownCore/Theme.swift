import Foundation

// MARK: - 渲染样式

/// 配色方案
public enum Theme: String, CaseIterable, Identifiable, Sendable {
    case system, github, solarized, nord, sepia

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "系统"
        case .github: "GitHub"
        case .solarized: "Solarized"
        case .nord: "Nord"
        case .sepia: "纸墨"
        }
    }

    var light: Palette {
        switch self {
        case .system: .systemLight
        case .github: .githubLight
        case .solarized: .solarizedLight
        case .nord: .nordLight
        case .sepia: .sepiaLight
        }
    }

    var dark: Palette {
        switch self {
        case .system: .systemDark
        case .github: .githubDark
        case .solarized: .solarizedDark
        case .nord: .nordDark
        case .sepia: .sepiaDark
        }
    }

    /// 正文字体（纸墨用衬线体）
    var bodyFont: String {
        switch self {
        case .sepia: #"ui-serif, "New York", "Songti SC", serif"#
        default: #"-apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif"#
        }
    }
}

/// 外观：跟随系统 / 始终浅色 / 始终深色
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    /// <meta name="color-scheme"> / CSS color-scheme 的取值
    var colorScheme: String {
        switch self {
        case .system: "light dark"
        case .light: "light"
        case .dark: "dark"
        }
    }
}

public struct RenderStyle: Equatable, Sendable {
    public var theme: Theme
    public var appearance: Appearance

    public init(theme: Theme = .system, appearance: Appearance = .system) {
        self.theme = theme
        self.appearance = appearance
    }
}

// MARK: - App 与 Quick Look 扩展共享的设置

public enum RenderSettings {
    /// App Group：App 与扩展都在沙盒中，通过同一个 suite 共享设置
    public static let suiteName = "586LZ975EV.com.markdownext.Mark"
    public static let themeKey = "theme"
    public static let appearanceKey = "appearance"

    public static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    public static func load() -> RenderStyle {
        let d = defaults
        return RenderStyle(theme: d.string(forKey: themeKey).flatMap(Theme.init) ?? .system,
                           appearance: d.string(forKey: appearanceKey).flatMap(Appearance.init) ?? .system)
    }
}

// MARK: - 调色板

struct Palette {
    var fg, fgMuted, bg, separator, link, fill, codeBg, rowAlt, mark, error: String
    var kw, type, str, num, com, lit, fn, meta, pre, variable, tag, attr, builtin: String
    var addFg, addBg, delFg, delBg: String

    var cssVariables: String {
        """
        --fg: \(fg); --fg-muted: \(fgMuted); --bg: \(bg); --separator: \(separator); --link: \(link);
        --fill: \(fill); --code-bg: \(codeBg); --row-alt: \(rowAlt); --mark: \(mark); --error: \(error);
        --hl-kw: \(kw); --hl-type: \(type); --hl-str: \(str); --hl-num: \(num); --hl-com: \(com);
        --hl-lit: \(lit); --hl-fn: \(fn); --hl-meta: \(meta); --hl-pre: \(pre); --hl-var: \(variable);
        --hl-tag: \(tag); --hl-attr: \(attr); --hl-bi: \(builtin);
        --hl-add-fg: \(addFg); --hl-add-bg: \(addBg); --hl-del-fg: \(delFg); --hl-del-bg: \(delBg);
        """
    }
}

extension Palette {
    // 系统：macOS 语义色 + Xcode「Default (Light/Dark)」代码配色
    static let systemLight = Palette(
        fg: "-apple-system-label", fgMuted: "-apple-system-secondary-label", bg: "-apple-system-text-background",
        separator: "-apple-system-separator", link: "-apple-system-blue", fill: "rgba(0, 0, 0, .04)",
        codeBg: "rgba(0, 0, 0, .06)", rowAlt: "-apple-system-odd-alternating-content-background",
        mark: "-apple-system-find-highlight-background", error: "-apple-system-red",
        kw: "#9b2393", type: "#3900a0", str: "#c41a16", num: "#1c00cf", com: "#5d6c79", lit: "#9b2393",
        fn: "#6c36a9", meta: "#815f03", pre: "#643820", variable: "#326d74", tag: "#0b4f79", attr: "#0f68a0",
        builtin: "#6c36a9", addFg: "-apple-system-green", addBg: "rgba(52, 199, 89, .12)",
        delFg: "-apple-system-red", delBg: "rgba(255, 56, 60, .1)")

    static let systemDark: Palette = {
        var p = systemLight
        p.fill = "rgba(255, 255, 255, .05)"; p.codeBg = "rgba(255, 255, 255, .1)"; p.mark = "rgba(255, 214, 10, .35)"
        p.kw = "#fc5fa3"; p.type = "#d0a8ff"; p.str = "#fc6a5d"; p.num = "#d0bf69"; p.com = "#6c7986"; p.lit = "#fc5fa3"
        p.fn = "#a167e6"; p.meta = "#bf8555"; p.pre = "#fd8f3f"; p.variable = "#67b7a4"; p.tag = "#5dd8ff"
        p.attr = "#41a1c0"; p.builtin = "#a167e6"
        p.addBg = "rgba(48, 209, 88, .16)"; p.delBg = "rgba(255, 69, 58, .16)"
        return p
    }()

    // GitHub（Primer 配色）
    static let githubLight = Palette(
        fg: "#1f2328", fgMuted: "#59636e", bg: "#ffffff", separator: "#d1d9e0", link: "#0969da",
        fill: "#f6f8fa", codeBg: "#818b981f", rowAlt: "#f6f8fa", mark: "#fff8c5", error: "#d1242f",
        kw: "#cf222e", type: "#953800", str: "#0a3069", num: "#0550ae", com: "#59636e", lit: "#0550ae",
        fn: "#8250df", meta: "#8250df", pre: "#cf222e", variable: "#953800", tag: "#116329", attr: "#0550ae",
        builtin: "#0550ae", addFg: "#116329", addBg: "#dafbe1", delFg: "#82071e", delBg: "#ffebe9")

    static let githubDark = Palette(
        fg: "#f0f6fc", fgMuted: "#9198a1", bg: "#0d1117", separator: "#3d444d", link: "#4493f8",
        fill: "#151b23", codeBg: "#656c7633", rowAlt: "#151b23", mark: "#bb800926", error: "#f85149",
        kw: "#ff7b72", type: "#ffa657", str: "#a5d6ff", num: "#79c0ff", com: "#9198a1", lit: "#79c0ff",
        fn: "#d2a8ff", meta: "#d2a8ff", pre: "#ff7b72", variable: "#ffa657", tag: "#7ee787", attr: "#79c0ff",
        builtin: "#79c0ff", addFg: "#aff5b4", addBg: "#033a16", delFg: "#ffdcd7", delBg: "#67060c")

    // Solarized（Ethan Schoonover 的 16 色）
    static let solarizedLight = Palette(
        fg: "#657b83", fgMuted: "#93a1a1", bg: "#fdf6e3", separator: "#e2dbc6", link: "#268bd2",
        fill: "#eee8d5", codeBg: "#eee8d5", rowAlt: "#f6efdb", mark: "#f3e2a5", error: "#dc322f",
        kw: "#859900", type: "#b58900", str: "#2aa198", num: "#d33682", com: "#93a1a1", lit: "#cb4b16",
        fn: "#268bd2", meta: "#6c71c4", pre: "#cb4b16", variable: "#268bd2", tag: "#268bd2", attr: "#b58900",
        builtin: "#6c71c4", addFg: "#859900", addBg: "rgba(133, 153, 0, .12)", delFg: "#dc322f",
        delBg: "rgba(220, 50, 47, .1)")

    static let solarizedDark: Palette = {
        var p = solarizedLight
        p.fg = "#839496"; p.fgMuted = "#586e75"; p.bg = "#002b36"; p.separator = "#164452"
        p.fill = "#073642"; p.codeBg = "#073642"; p.rowAlt = "#04313c"; p.mark = "rgba(181, 137, 0, .35)"
        p.com = "#586e75"
        return p
    }()

    // Nord（Arctic Ice Studio）
    static let nordLight = Palette(
        fg: "#2e3440", fgMuted: "#4c566a", bg: "#eceff4", separator: "#d8dee9", link: "#5e81ac",
        fill: "#e5e9f0", codeBg: "#d8dee9", rowAlt: "#e5e9f0", mark: "rgba(235, 203, 139, .5)", error: "#bf616a",
        kw: "#5e81ac", type: "#3f8c8a", str: "#5c7f3e", num: "#a0708f", com: "#7b88a1", lit: "#5e81ac",
        fn: "#2e7a96", meta: "#c0704a", pre: "#5e81ac", variable: "#2e3440", tag: "#5e81ac", attr: "#3f8c8a",
        builtin: "#2e7a96", addFg: "#5c7f3e", addBg: "rgba(163, 190, 140, .25)", delFg: "#bf616a",
        delBg: "rgba(191, 97, 106, .15)")

    static let nordDark = Palette(
        fg: "#d8dee9", fgMuted: "#9aa5ba", bg: "#2e3440", separator: "#434c5e", link: "#88c0d0",
        fill: "#3b4252", codeBg: "#3b4252", rowAlt: "#353c4a", mark: "rgba(235, 203, 139, .3)", error: "#bf616a",
        kw: "#81a1c1", type: "#8fbcbb", str: "#a3be8c", num: "#b48ead", com: "#616e88", lit: "#81a1c1",
        fn: "#88c0d0", meta: "#d08770", pre: "#5e81ac", variable: "#d8dee9", tag: "#81a1c1", attr: "#8fbcbb",
        builtin: "#88c0d0", addFg: "#a3be8c", addBg: "rgba(163, 190, 140, .15)", delFg: "#bf616a",
        delBg: "rgba(191, 97, 106, .18)")

    // 纸墨：暖色纸张 + 衬线正文
    static let sepiaLight = Palette(
        fg: "#3b3125", fgMuted: "#7a6a55", bg: "#f8f1e3", separator: "#e3d7c1", link: "#9a4d1f",
        fill: "#f1e7d4", codeBg: "#ecdfc7", rowAlt: "#f3ead9", mark: "#f6dd9a", error: "#b3261e",
        kw: "#8b3a2b", type: "#7a5a1c", str: "#4f6b2b", num: "#9b4f0f", com: "#9a8a72", lit: "#8b3a2b",
        fn: "#5b4a8a", meta: "#8a6a2a", pre: "#8b3a2b", variable: "#3f6b73", tag: "#8b3a2b", attr: "#7a5a1c",
        builtin: "#5b4a8a", addFg: "#4f6b2b", addBg: "#e6efd2", delFg: "#a23a2a", delBg: "#f6ddd5")

    static let sepiaDark = Palette(
        fg: "#e6dccb", fgMuted: "#a3967f", bg: "#221d17", separator: "#3a3229", link: "#e0a26b",
        fill: "#2b251e", codeBg: "#332c23", rowAlt: "#28221b", mark: "rgba(214, 170, 80, .35)", error: "#f08070",
        kw: "#e88a6e", type: "#e0b56b", str: "#b5c98a", num: "#e6a25c", com: "#85786a", lit: "#e88a6e",
        fn: "#b9a6e8", meta: "#d4b06a", pre: "#e88a6e", variable: "#8ec1c9", tag: "#e88a6e", attr: "#e0b56b",
        builtin: "#b9a6e8", addFg: "#b5c98a", addBg: "rgba(181, 201, 138, .14)", delFg: "#f08070",
        delBg: "rgba(240, 128, 112, .14)")
}
