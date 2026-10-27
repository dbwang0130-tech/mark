// LaTeX → MathML 转换器。输出交给 WebKit 原生 MathML 排版，不依赖任何 JS。

import Foundation

public struct MathMLResult {
    public let mathML: String
    /// \tag{...} 指定的编号（仅 display 公式使用）
    public let tag: String?
}

public enum TeXToMathML {
    public static func convert(_ tex: String, display: Bool) -> MathMLResult {
        let parser = TeXParser(tex, display: display)
        let body = parser.parseTopLevel()
        let open = display ? "<math display=\"block\">" : "<math>"
        return MathMLResult(mathML: open + body + "</math>", tag: parser.tag)
    }
}

enum MathFont { case normal, bold, italic, boldItalic, script, fraktur, doubleStruck, sans, sansBold, mono }

private enum LimitsMode { case never, display, always }

private struct MathNode {
    var xml: String
    var limits: LimitsMode = .never
    var explicitLimits: Bool? = nil
    var sub: String? = nil
    var sup: String? = nil
    var primes = 0
    /// 函数名（sin、log…）：后面跟普通符号时补细空格
    var isFunction = false
}

private enum Stop { case eof, brace, bracket, right, cell }


final class TeXParser {
    private let s: [Character]
    private var i = 0
    private var displayMode: Bool
    private var font: MathFont?
    private var depth = 0
    private(set) var tag: String?

    init(_ tex: String, display: Bool) {
        s = Array(tex)
        displayMode = display
    }

    // MARK: - 顶层

    func parseTopLevel() -> String {
        let rows = parseRows()
        if rows.count == 1 && rows[0].count == 1 { return rows[0][0] }
        // 没有环境却出现了 \\ 或 &：按 aligned / gather 处理
        let columns = rows.map(\.count).max() ?? 1
        return columns > 1 ? alignedTable(rows) : centeredTable(rows, displayStyle: true)
    }

    /// 解析以 & 和 \\ 分隔的表格，直到 \end{...} 或输入结束
    private func parseRows() -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        while true {
            row.append(parseExpr(.cell))
            guard i < s.count else { break }
            if s[i] == "&" { i += 1; continue }
            if s[i] == "\\" {
                let save = i
                let name = readCommand()
                if name == "\\" || name == "cr" || name == "newline" {
                    skipSpaces()
                    if i < s.count && s[i] == "[" { _ = readBalanced(open: "[", close: "]") }
                    rows.append(row)
                    row = []
                    continue
                }
                if name == "end" { _ = readGroupRaw(); break }
                i = save
            }
            break
        }
        if !(row.count == 1 && row[0].isEmpty && !rows.isEmpty) { rows.append(row) }
        return rows
    }

    // MARK: - 表达式

    private func isStop(_ command: String, _ stop: Stop) -> Bool {
        switch stop {
        case .right:
            return command == "right" || command == "\\" || command == "cr" || command == "end"
        case .cell:
            return command == "\\" || command == "cr" || command == "newline" || command == "end"
        default:
            return false
        }
    }

    private func parseExpr(_ stop: Stop) -> String {
        depth += 1
        defer { depth -= 1 }
        if depth > 120 {
            i = s.count
            return "<merror><mtext>表达式嵌套过深</mtext></merror>"
        }
        var nodes: [MathNode] = []
        var numerator: String?
        var infix = ""

        loop: while i < s.count {
            let c = s[i]
            switch c {
            case " ", "\t", "\n", "\r":
                i += 1
            case "}":
                if stop == .brace || stop == .right { break loop }
                i += 1
            case "]" where stop == .bracket:
                break loop
            case "&":
                if stop == .cell || stop == .right { break loop }
                i += 1
            case "^", "_":
                i += 1
                let arg = parseArg()
                if nodes.isEmpty { nodes.append(MathNode(xml: "<mrow></mrow>")) }
                if c == "^" { nodes[nodes.count - 1].sup = arg } else { nodes[nodes.count - 1].sub = arg }
            case "'":
                var count = 0
                while i < s.count && s[i] == "'" { count += 1; i += 1 }
                if nodes.isEmpty { nodes.append(MathNode(xml: "<mrow></mrow>")) }
                nodes[nodes.count - 1].primes += count
            case "{":
                i += 1
                let inner = parseExpr(.brace)
                if i < s.count { i += 1 }
                nodes.append(MathNode(xml: "<mrow>\(inner)</mrow>"))
            case "\\":
                let save = i
                let name = readCommand()
                if isStop(name, stop) { i = save; break loop }
                switch name {
                case "over", "choose", "atop", "brace", "brack":
                    numerator = join(nodes)
                    nodes = []
                    infix = name
                case "limits":
                    if !nodes.isEmpty { nodes[nodes.count - 1].explicitLimits = true }
                case "nolimits":
                    if !nodes.isEmpty { nodes[nodes.count - 1].explicitLimits = false }
                default:
                    if let node = parseSwitch(name, stop) ?? parseCommand(name) { nodes.append(node) }
                }
            default:
                nodes.append(parseCharAtom(merge: true))
            }
        }

        let body = join(nodes)
        guard let num = numerator else { return body }
        switch infix {
        case "choose": return binomial(num, body)
        case "atop": return "<mfrac linethickness=\"0\"><mrow>\(num)</mrow><mrow>\(body)</mrow></mfrac>"
        case "brace", "brack":
            let (l, r) = infix == "brace" ? ("{", "}") : ("[", "]")
            return "<mrow>\(fence(l))<mfrac linethickness=\"0\"><mrow>\(num)</mrow><mrow>\(body)</mrow></mfrac>\(fence(r))</mrow>"
        default: return "<mfrac><mrow>\(num)</mrow><mrow>\(body)</mrow></mfrac>"
        }
    }

    private func join(_ nodes: [MathNode]) -> String {
        var out = ""
        for (k, node) in nodes.enumerated() {
            out += emit(node)
            if node.isFunction && k + 1 < nodes.count && !nodes[k + 1].xml.hasPrefix("<mo")
                && !nodes[k + 1].xml.hasPrefix("<mrow><mo") {
                out += "<mspace width=\"0.1667em\"></mspace>"
            }
        }
        return out
    }

    private func emit(_ node: MathNode) -> String {
        var sup = node.sup
        if node.primes > 0 {
            let p = "<mo>" + String(repeating: "′", count: node.primes) + "</mo>"
            sup = sup.map { "<mrow>\(p)\($0)</mrow>" } ?? p
        }
        let limits: Bool
        if let explicit = node.explicitLimits {
            limits = explicit
        } else {
            switch node.limits {
            case .never: limits = false
            case .always: limits = true
            case .display: limits = displayMode
            }
        }
        let base = node.xml
        let xml: String
        switch (node.sub, sup) {
        case (nil, nil): xml = base
        case let (sub?, nil): xml = limits ? "<munder>\(base)\(sub)</munder>" : "<msub>\(base)\(sub)</msub>"
        case let (nil, sup?): xml = limits ? "<mover>\(base)\(sup)</mover>" : "<msup>\(base)\(sup)</msup>"
        case let (sub?, sup?):
            xml = limits ? "<munderover>\(base)\(sub)\(sup)</munderover>" : "<msubsup>\(base)\(sub)\(sup)</msubsup>"
        }
        return xml
    }

    /// 命令参数或上下标：一个 {...} 组，或单个记号
    private func parseArg() -> String {
        skipSpaces()
        guard i < s.count else { return "<mrow></mrow>" }
        switch s[i] {
        case "{":
            i += 1
            let inner = parseExpr(.brace)
            if i < s.count { i += 1 }
            return "<mrow>\(inner)</mrow>"
        case "\\":
            let name = readCommand()
            if let node = parseCommand(name) { return emit(node) }
            return "<mrow></mrow>"
        default:
            return emit(parseCharAtom(merge: false))
        }
    }

    // MARK: - 单字符

    private func parseCharAtom(merge: Bool) -> MathNode {
        let c = s[i]
        i += 1
        if c.isASCII && c.isLetter {
            if font == .normal && merge {
                var run = String(c)
                while i < s.count && s[i].isASCII && s[i].isLetter { run.append(s[i]); i += 1 }
                return MathNode(xml: run.count == 1 ? "<mi mathvariant=\"normal\">\(run)</mi>" : "<mi>\(run)</mi>")
            }
            return MathNode(xml: identifier(c))
        }
        if c.isASCII && c.isNumber {
            var run = String(c)
            if merge {
                while i < s.count {
                    if s[i].isASCII && s[i].isNumber {
                        run.append(s[i]); i += 1
                    } else if s[i] == "." && i + 1 < s.count && s[i + 1].isASCII && s[i + 1].isNumber {
                        run.append(s[i]); i += 1
                    } else {
                        break
                    }
                }
            }
            if let f = font, f != .normal, f != .italic {
                return MathNode(xml: "<mn>" + String(run.map { styledChar($0, f) ?? String($0) }.joined()) + "</mn>")
            }
            return MathNode(xml: "<mn>\(run)</mn>")
        }
        switch c {
        case "-": return MathNode(xml: "<mo>−</mo>")
        case "*": return MathNode(xml: "<mo>∗</mo>")
        case "(", ")", "[", "]", "|", "/": return MathNode(xml: "<mo stretchy=\"false\">\(c)</mo>")
        case "<": return MathNode(xml: "<mo>&lt;</mo>")
        case ">": return MathNode(xml: "<mo>&gt;</mo>")
        case "&": return MathNode(xml: "<mo>&amp;</mo>")
        case "~": return MathNode(xml: "<mtext>&#xA0;</mtext>")
        case ".": return MathNode(xml: "<mi mathvariant=\"normal\">.</mi>")
        case "+", "=", ",", ";", ":", "!", "?", "@": return MathNode(xml: "<mo>\(c)</mo>")
        default:
            let text = escapeXML(String(c))
            return MathNode(xml: c.isLetter ? "<mi>\(text)</mi>" : "<mo>\(text)</mo>")
        }
    }

    private func identifier(_ c: Character) -> String {
        guard let f = font else { return "<mi>\(c)</mi>" }
        if f == .normal { return "<mi mathvariant=\"normal\">\(c)</mi>" }
        if let mapped = styledChar(c, f) { return "<mi>\(mapped)</mi>" }
        return "<mi>\(c)</mi>"
    }

    /// 命令产生的标识符（希腊字母等）在粗体字体下加粗
    private func symbolIdentifier(_ v: String, upright: Bool) -> String {
        var attrs = upright || font == .normal || font == .bold || font == .sansBold ? " mathvariant=\"normal\"" : ""
        if font == .bold || font == .boldItalic || font == .sansBold { attrs += " style=\"font-weight:bold\"" }
        return "<mi\(attrs)>\(escapeXML(v))</mi>"
    }

    // MARK: - 状态切换命令（作用到当前组结束）

    private func parseSwitch(_ name: String, _ stop: Stop) -> MathNode? {
        switch name {
        case "color":
            let color = readGroupRaw()
            let body = parseExpr(stop)
            return MathNode(xml: "<mstyle mathcolor=\"\(escapeAttr(color))\"><mrow>\(body)</mrow></mstyle>")
        case "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle":
            let old = displayMode
            displayMode = name == "displaystyle"
            let body = parseExpr(stop)
            displayMode = old
            let level = name == "scriptstyle" ? " scriptlevel=\"1\"" : name == "scriptscriptstyle" ? " scriptlevel=\"2\"" : " scriptlevel=\"0\""
            return MathNode(xml: "<mstyle displaystyle=\"\(name == "displaystyle")\"\(level)><mrow>\(body)</mrow></mstyle>")
        case "rm", "bf", "it", "cal", "sf", "tt", "mit", "frak", "Bbb":
            let map: [String: MathFont] = ["rm": .normal, "bf": .bold, "it": .italic, "cal": .script, "sf": .sans,
                                           "tt": .mono, "mit": .italic, "frak": .fraktur, "Bbb": .doubleStruck]
            // \frak{X} / \Bbb{X} 也常带参数使用
            if (name == "frak" || name == "Bbb") && peekNonSpace() == "{" { return nil }
            let old = font
            font = map[name]
            let body = parseExpr(stop)
            font = old
            return MathNode(xml: "<mrow>\(body)</mrow>")
        case "tiny", "scriptsize", "footnotesize", "small", "normalsize", "large", "Large", "LARGE", "huge", "Huge":
            let size: [String: String] = ["tiny": "0.5em", "scriptsize": "0.7em", "footnotesize": "0.8em", "small": "0.9em",
                                          "normalsize": "1em", "large": "1.2em", "Large": "1.44em", "LARGE": "1.728em",
                                          "huge": "2.074em", "Huge": "2.488em"]
            let body = parseExpr(stop)
            return MathNode(xml: "<mstyle mathsize=\"\(size[name] ?? "1em")\"><mrow>\(body)</mrow></mstyle>")
        default:
            return nil
        }
    }

    // MARK: - 命令

    private func parseCommand(_ name: String) -> MathNode? {
        if let v = MathSymbols.identifiers[name] { return MathNode(xml: symbolIdentifier(v, upright: false)) }
        if let v = MathSymbols.uprightIdentifiers[name] { return MathNode(xml: symbolIdentifier(v, upright: true)) }
        if let v = MathSymbols.operators[name] { return MathNode(xml: "<mo>\(escapeXML(v))</mo>") }
        if let v = MathSymbols.delimiters[name] { return MathNode(xml: "<mo stretchy=\"false\">\(v)</mo>") }
        if let (v, limits) = MathSymbols.largeOperators[name] {
            return MathNode(xml: "<mo>\(v)</mo>", limits: limits ? .display : .never)
        }
        if MathSymbols.functions.contains(name) {
            return MathNode(xml: "<mi>\(name)</mi>", isFunction: true)
        }
        if let v = MathSymbols.limitFunctions[name] {
            let text = v.replacingOccurrences(of: " ", with: "&#x2006;")
            return MathNode(xml: "<mi>\(text)</mi>", limits: .display, isFunction: true)
        }
        if let accent = MathSymbols.accents[name] {
            let base = parseArg()
            let stretchy = accent.stretchy ? "true" : "false"
            let mo = "<mo stretchy=\"\(stretchy)\">\(accent.char)</mo>"
            if !accent.isAccent {
                // 花括号：上下标放在括号外侧
                let xml = accent.under ? "<munder>\(base)\(mo)</munder>" : "<mover>\(base)\(mo)</mover>"
                return MathNode(xml: "<mrow>\(xml)</mrow>", limits: .always)
            }
            return MathNode(xml: accent.under
                ? "<munder accentunder=\"true\">\(base)\(mo)</munder>"
                : "<mover accent=\"true\">\(base)\(mo)</mover>")
        }
        if let arrow = MathSymbols.extensibleArrows[name] {
            var below: String?
            skipSpaces()
            if i < s.count && s[i] == "[" {
                i += 1
                below = parseExpr(.bracket)
                if i < s.count { i += 1 }
            }
            let above = parseArg()
            let mo = "<mo stretchy=\"true\" minsize=\"1.8em\">\(arrow)</mo>"
            let pad = { (x: String) in "<mpadded width=\"+1em\" lspace=\"0.5em\">\(x)</mpadded>" }
            if let below {
                return MathNode(xml: "<munderover>\(mo)\(pad("<mrow>\(below)</mrow>"))\(pad(above))</munderover>")
            }
            return MathNode(xml: "<mover>\(mo)\(pad(above))</mover>")
        }
        if let width = MathSymbols.spaces[name] {
            if width <= 0 { return nil }
            return MathNode(xml: "<mspace width=\"\(width)em\"></mspace>")
        }

        switch name {
        case "frac", "dfrac", "tfrac", "cfrac":
            let num = parseArg(), den = parseArg()
            let frac = "<mfrac>\(num)\(den)</mfrac>"
            switch name {
            case "dfrac", "cfrac": return MathNode(xml: "<mstyle displaystyle=\"true\" scriptlevel=\"0\">\(frac)</mstyle>")
            case "tfrac": return MathNode(xml: "<mstyle displaystyle=\"false\">\(frac)</mstyle>")
            default: return MathNode(xml: frac)
            }
        case "binom", "dbinom", "tbinom":
            let a = parseArg(), b = parseArg()
            let xml = binomial(a, b)
            if name == "dbinom" { return MathNode(xml: "<mstyle displaystyle=\"true\" scriptlevel=\"0\">\(xml)</mstyle>") }
            if name == "tbinom" { return MathNode(xml: "<mstyle displaystyle=\"false\">\(xml)</mstyle>") }
            return MathNode(xml: xml)
        case "sqrt":
            skipSpaces()
            if i < s.count && s[i] == "[" {
                i += 1
                let index = parseExpr(.bracket)
                if i < s.count { i += 1 }
                let radicand = parseArg()
                return MathNode(xml: "<mroot>\(radicand)<mrow>\(index)</mrow></mroot>")
            }
            return MathNode(xml: "<msqrt>\(parseArg())</msqrt>")
        case "left":
            let open = readDelimiter()
            let body = parseExpr(.right)
            var close = ""
            if i < s.count && s[i] == "\\" {
                let save = i
                if readCommand() == "right" { close = readDelimiter() } else { i = save }
            }
            return MathNode(xml: "<mrow>\(stretchyFence(open))\(body)\(stretchyFence(close))</mrow>")
        case "middle":
            return MathNode(xml: stretchyFence(readDelimiter()))
        case "big", "Big", "bigg", "Bigg", "bigl", "Bigl", "biggl", "Biggl", "bigr", "Bigr", "biggr", "Biggr",
             "bigm", "Bigm", "biggm", "Biggm":
            let sizes: [String: String] = ["big": "1.2em", "Big": "1.623em", "bigg": "2.047em", "Bigg": "2.470em"]
            var key = name
            if let last = key.last, "lrm".contains(last) { key.removeLast() }
            let d = readDelimiter()
            guard !d.isEmpty else { return nil }
            let size = sizes[key] ?? "1.2em"
            return MathNode(xml: "<mo minsize=\"\(size)\" maxsize=\"\(size)\" stretchy=\"true\" symmetric=\"true\">\(d)</mo>")
        case "text", "textrm", "textnormal", "mbox", "hbox", "textup", "textmd", "fbox":
            let text = mtext(readGroupRaw())
            return MathNode(xml: name == "fbox" ? "<menclose notation=\"box\">\(text)</menclose>" : text)
        case "textbf": return MathNode(xml: mtext(readGroupRaw(), style: "font-weight:bold"))
        case "textit", "emph", "textsl": return MathNode(xml: mtext(readGroupRaw(), style: "font-style:italic"))
        case "texttt": return MathNode(xml: mtext(readGroupRaw(), style: "font-family:ui-monospace,Menlo,monospace"))
        case "textsf": return MathNode(xml: mtext(readGroupRaw(), style: "font-family:-apple-system,sans-serif"))
        case "mathbb", "Bbb", "mathbf", "mathcal", "mathscr", "mathfrak", "frak", "mathsf", "mathtt", "mathit",
             "mathrm", "mathup", "mathnormal", "boldsymbol", "bm", "pmb", "mathbfit", "mathsfbf", "bold":
            let map: [String: MathFont] = [
                "mathbb": .doubleStruck, "Bbb": .doubleStruck, "mathbf": .bold, "bold": .bold,
                "mathcal": .script, "mathscr": .script, "mathfrak": .fraktur, "frak": .fraktur,
                "mathsf": .sans, "mathsfbf": .sansBold, "mathtt": .mono, "mathit": .italic,
                "mathnormal": .italic, "mathrm": .normal, "mathup": .normal,
                "boldsymbol": .boldItalic, "bm": .boldItalic, "pmb": .boldItalic, "mathbfit": .boldItalic,
            ]
            let old = font
            font = map[name]
            let arg = parseArg()
            font = old
            return MathNode(xml: arg)
        case "operatorname", "operatornamewithlimits":
            var starred = name == "operatornamewithlimits"
            if i < s.count && s[i] == "*" { starred = true; i += 1 }
            let old = font
            font = .normal
            let arg = parseArg()
            font = old
            return MathNode(xml: arg, limits: starred ? .display : .never, isFunction: true)
        case "mathop":
            return MathNode(xml: parseArg(), limits: .display)
        case "mathbin", "mathrel", "mathord", "mathpunct", "mathopen", "mathclose", "mathinner", "ensuremath":
            return MathNode(xml: parseArg())
        case "overset", "stackrel":
            let top = parseArg(), base = parseArg()
            return MathNode(xml: "<mover>\(base)\(top)</mover>")
        case "underset":
            let bottom = parseArg(), base = parseArg()
            return MathNode(xml: "<munder>\(base)\(bottom)</munder>")
        case "phantom":
            return MathNode(xml: "<mphantom>\(parseArg())</mphantom>")
        case "hphantom":
            return MathNode(xml: "<mpadded height=\"0\" depth=\"0\"><mphantom>\(parseArg())</mphantom></mpadded>")
        case "vphantom":
            return MathNode(xml: "<mpadded width=\"0\"><mphantom>\(parseArg())</mphantom></mpadded>")
        case "overline":
            return MathNode(xml: "<menclose notation=\"top\">\(parseArg())</menclose>")
        case "underline":
            return MathNode(xml: "<menclose notation=\"bottom\">\(parseArg())</menclose>")
        case "boxed":
            return MathNode(xml: "<menclose notation=\"box\">\(parseArg())</menclose>")
        case "cancel", "bcancel", "xcancel", "sout":
            // WebKit 不画 menclose 的删除线，用 CSS 渐变模拟
            let line = { (dir: String) in "linear-gradient(\(dir),transparent calc(50% - 0.04em),currentColor calc(50% - 0.04em),currentColor calc(50% + 0.04em),transparent calc(50% + 0.04em))" }
            let bg: String
            switch name {
            case "bcancel": bg = line("to bottom right")
            case "xcancel": bg = line("to top right") + "," + line("to bottom right")
            case "sout": bg = line("to bottom")
            default: bg = line("to top right")
            }
            return MathNode(xml: "<mrow style=\"background:\(bg)\">\(parseArg())</mrow>")
        case "textcolor":
            let color = readGroupRaw()
            return MathNode(xml: "<mstyle mathcolor=\"\(escapeAttr(color))\">\(parseArg())</mstyle>")
        case "colorbox":
            let color = readGroupRaw()
            return MathNode(xml: "<mstyle mathbackground=\"\(escapeAttr(color))\">\(mtext(readGroupRaw()))</mstyle>")
        case "not":
            return parseNot()
        case "pmod":
            let arg = parseArg()
            return MathNode(xml: "<mspace width=\"0.444em\"></mspace><mo stretchy=\"false\">(</mo><mi>mod</mi><mspace width=\"0.333em\"></mspace>\(arg)<mo stretchy=\"false\">)</mo>")
        case "pod":
            let arg = parseArg()
            return MathNode(xml: "<mspace width=\"0.444em\"></mspace><mo stretchy=\"false\">(</mo>\(arg)<mo stretchy=\"false\">)</mo>")
        case "bmod":
            return MathNode(xml: "<mo lspace=\"0.2222em\" rspace=\"0.2222em\">mod</mo>")
        case "mod":
            return MathNode(xml: "<mspace width=\"0.8em\"></mspace><mi>mod</mi><mspace width=\"0.333em\"></mspace>")
        case "hspace", "hskip", "kern", "mkern", "mskip", "hspace*":
            if i < s.count && s[i] == "*" { i += 1 }
            let width = dimensionToEm(readGroupRaw())
            return width > 0 ? MathNode(xml: "<mspace width=\"\(width)em\"></mspace>") : nil
        case "tag":
            var starred = false
            if i < s.count && s[i] == "*" { starred = true; i += 1 }
            let text = readGroupRaw()
            tag = starred ? text : "(\(text))"
            return nil
        case "label":
            _ = readGroupRaw()
            return nil
        case "ref", "eqref":
            let text = readGroupRaw()
            return MathNode(xml: mtext(name == "eqref" ? "(\(text))" : text))
        case "substack":
            let rows = TeXParser(readGroupRaw(), display: false).parseRows()
            return MathNode(xml: "<mstyle scriptlevel=\"1\">\(centeredTable(rows, displayStyle: false, padding: "0"))</mstyle>")
        case "begin":
            return environment(readGroupRaw())
        case "{", "}":
            return MathNode(xml: "<mo stretchy=\"false\">\(name)</mo>")
        case "unicode":
            let raw = readGroupRaw()
            let hex = raw.hasPrefix("x") || raw.hasPrefix("X") ? String(raw.dropFirst()) : raw
            if let code = UInt32(hex, radix: raw.hasPrefix("x") || raw.hasPrefix("X") ? 16 : 10),
               let scalar = Unicode.Scalar(code) {
                return MathNode(xml: "<mi>\(escapeXML(String(Character(scalar))))</mi>")
            }
            return nil
        case "":
            return nil
        default:
            if MathSymbols.ignored.contains(name) {
                if name == "end" { _ = readGroupRaw() }
                if name == "right" { _ = readDelimiter() }
                return nil
            }
            return MathNode(xml: "<merror><mtext>\\\(escapeXML(name))</mtext></merror>")
        }
    }

    private func parseNot() -> MathNode? {
        skipSpaces()
        guard i < s.count else { return nil }
        let key: String
        if s[i] == "\\" {
            let save = i
            key = readCommand()
            if let v = MathSymbols.negations[key] { return MathNode(xml: "<mo>\(v)</mo>") }
            i = save
        } else {
            key = String(s[i])
            if let v = MathSymbols.negations[key] { i += 1; return MathNode(xml: "<mo>\(escapeXML(v))</mo>") }
        }
        let xml = parseArg()
        // 通用情况：在符号后加组合用斜线 U+0338
        if let r = xml.range(of: "</mo>") ?? xml.range(of: "</mi>") {
            return MathNode(xml: xml.replacingCharacters(in: r, with: "\u{338}" + xml[r]))
        }
        return MathNode(xml: xml)
    }

    // MARK: - 环境

    private func environment(_ rawName: String) -> MathNode {
        let name = rawName.hasSuffix("*") ? String(rawName.dropLast()) : rawName
        switch name {
        case "matrix", "pmatrix", "bmatrix", "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "CD":
            var align = "center"
            if rawName.hasSuffix("*") && peekNonSpace() == "[" {
                skipSpaces()
                let a = readBalanced(open: "[", close: "]")
                align = a == "l" ? "left" : a == "r" ? "right" : "center"
            }
            let rows = parseRows()
            var table = matrixTable(rows, align: align)
            if name == "smallmatrix" { table = "<mstyle scriptlevel=\"1\">\(table)</mstyle>" }
            let fences: [String: (String, String)] = ["pmatrix": ("(", ")"), "bmatrix": ("[", "]"), "Bmatrix": ("{", "}"),
                                                      "vmatrix": ("|", "|"), "Vmatrix": ("‖", "‖")]
            if let (l, r) = fences[name] {
                return MathNode(xml: "<mrow>\(stretchyFence(l))\(table)\(stretchyFence(r))</mrow>")
            }
            return MathNode(xml: table)
        case "cases", "dcases", "rcases", "drcases":
            let rows = parseRows()
            var xml = "<mtable columnalign=\"left left\">"
            for row in rows {
                xml += "<mtr>"
                for (k, cell) in row.enumerated() {
                    let pad = k == 0 ? "0.15em 1em 0.15em 0" : "0.15em 0"
                    xml += "<mtd columnalign=\"left\" style=\"text-align:left;padding:\(pad)\">\(cell)</mtd>"
                }
                xml += "</mtr>"
            }
            xml += "</mtable>"
            if name.hasPrefix("d") { xml = "<mstyle displaystyle=\"true\">\(xml)</mstyle>" }
            let right = name.hasSuffix("rcases")
            return MathNode(xml: "<mrow>\(right ? "" : stretchyFence("{"))\(xml)\(right ? stretchyFence("}") : "")</mrow>")
        case "aligned", "align", "alignat", "alignedat", "split", "flalign", "eqnarray", "multlined":
            if name == "alignat" || name == "alignedat" { _ = readGroupRaw() }
            return MathNode(xml: alignedTable(parseRows()))
        case "array", "subarray", "darray":
            let spec = readGroupRaw()
            let aligns = spec.compactMap { c -> String? in
                switch c {
                case "l": return "left"
                case "r": return "right"
                case "c": return "center"
                default: return nil
                }
            }
            let rows = parseRows()
            var xml = "<mtable>"
            for row in rows {
                xml += "<mtr>"
                for (k, cell) in row.enumerated() {
                    let a = k < aligns.count ? aligns[k] : "center"
                    xml += "<mtd columnalign=\"\(a)\" style=\"text-align:\(a);padding:0.15em 0.4em\">\(cell)</mtd>"
                }
                xml += "</mtr>"
            }
            return MathNode(xml: xml + "</mtable>")
        default:
            // gather / gathered / equation / multline 等：单列居中
            let rows = parseRows()
            if rows.count == 1 && rows[0].count == 1 { return MathNode(xml: "<mrow>\(rows[0][0])</mrow>") }
            return MathNode(xml: rows.map(\.count).max() ?? 1 > 1 ? alignedTable(rows) : centeredTable(rows, displayStyle: true))
        }
    }

    private func matrixTable(_ rows: [[String]], align: String) -> String {
        var xml = "<mtable>"
        for row in rows {
            xml += "<mtr>"
            for cell in row {
                xml += "<mtd columnalign=\"\(align)\" style=\"text-align:\(align);padding:0.2em 0.5em\">\(cell)</mtd>"
            }
            xml += "</mtr>"
        }
        return xml + "</mtable>"
    }

    /// aligned 风格：列交替右对齐 / 左对齐，奇数列前补空 <mi> 让 = 等按中缀间距排版
    private func alignedTable(_ rows: [[String]]) -> String {
        var xml = "<mtable displaystyle=\"true\">"
        for row in rows {
            xml += "<mtr>"
            for (k, cell) in row.enumerated() {
                if k % 2 == 0 {
                    let left = k == 0 ? "0" : "2em"
                    xml += "<mtd columnalign=\"right\" style=\"text-align:right;padding:0.25em 0 0.25em \(left)\">\(cell)</mtd>"
                } else {
                    xml += "<mtd columnalign=\"left\" style=\"text-align:left;padding:0.25em 0\"><mi></mi>\(cell)</mtd>"
                }
            }
            xml += "</mtr>"
        }
        return xml + "</mtable>"
    }

    private func centeredTable(_ rows: [[String]], displayStyle: Bool, padding: String = "0.25em 0") -> String {
        var xml = displayStyle ? "<mtable displaystyle=\"true\">" : "<mtable>"
        for row in rows {
            xml += "<mtr>"
            for cell in row {
                xml += "<mtd columnalign=\"center\" style=\"text-align:center;padding:\(padding)\">\(cell)</mtd>"
            }
            xml += "</mtr>"
        }
        return xml + "</mtable>"
    }

    // MARK: - 辅助

    private func binomial(_ a: String, _ b: String) -> String {
        "<mrow>\(stretchyFence("("))<mfrac linethickness=\"0\"><mrow>\(a)</mrow><mrow>\(b)</mrow></mfrac>\(stretchyFence(")"))</mrow>"
    }

    private func fence(_ d: String) -> String {
        "<mo stretchy=\"false\">\(escapeXML(d))</mo>"
    }

    private func stretchyFence(_ d: String) -> String {
        d.isEmpty ? "" : "<mo fence=\"true\" stretchy=\"true\" symmetric=\"true\">\(escapeXML(d))</mo>"
    }

    private func readDelimiter() -> String {
        skipSpaces()
        guard i < s.count else { return "" }
        let c = s[i]
        if c == "\\" {
            let name = readCommand()
            return MathSymbols.delimiters[name] ?? MathSymbols.operators[name] ?? ""
        }
        i += 1
        switch c {
        case ".": return ""
        case "<": return "⟨"
        case ">": return "⟩"
        default: return String(c)
        }
    }

    private func mtext(_ raw: String, style: String? = nil) -> String {
        var text = ""
        var chars = Array(raw)[...]
        while let c = chars.popFirst() {
            if c == "\\", let next = chars.first {
                chars.removeFirst()
                switch next {
                case "%", "$", "&", "_", "{", "}", "#": text.append(next)
                case " ", ",", ";", ":": text.append(" ")
                case "\\": text.append(" ")
                default:
                    // \textbackslash 之类的命令：跳过命令名
                    var word = String(next)
                    while let n = chars.first, n.isASCII && n.isLetter { word.append(n); chars.removeFirst() }
                    text += word == "textbackslash" ? "\\" : word
                }
            } else if c == "~" {
                text.append("\u{A0}")
            } else if c != "{" && c != "}" && c != "$" {
                text.append(c)
            }
        }
        // mtext 会裁掉首尾空白，换成不换行空格保留
        if text.hasPrefix(" ") { text = "\u{A0}" + text.dropFirst() }
        if text.hasSuffix(" ") { text = text.dropLast() + "\u{A0}" }
        let styleAttr = style.map { " style=\"\($0)\"" } ?? ""
        return "<mtext\(styleAttr)>\(escapeXML(text))</mtext>"
    }

    private func dimensionToEm(_ raw: String) -> Double {
        let t = raw.trimmingCharacters(in: .whitespaces)
        let units: [(String, Double)] = [("em", 1), ("ex", 0.43), ("mu", 1.0 / 18), ("pt", 0.1), ("px", 0.0625),
                                         ("mm", 0.284), ("cm", 2.84), ("in", 7.2)]
        for (u, f) in units where t.hasSuffix(u) {
            return (Double(t.dropLast(u.count).trimmingCharacters(in: .whitespaces)) ?? 0) * f
        }
        return Double(t) ?? 0
    }

    // MARK: - 词法

    private func skipSpaces() {
        while i < s.count && s[i].isWhitespace { i += 1 }
    }

    private func peekNonSpace() -> Character? {
        var j = i
        while j < s.count && s[j].isWhitespace { j += 1 }
        return j < s.count ? s[j] : nil
    }

    /// 读取 \ 之后的命令名（字母串或单个符号）
    private func readCommand() -> String {
        i += 1
        guard i < s.count else { return "" }
        if s[i].isASCII && s[i].isLetter {
            let start = i
            while i < s.count && s[i].isASCII && s[i].isLetter { i += 1 }
            return String(s[start..<i])
        }
        i += 1
        return String(s[i - 1])
    }

    /// 读取一个原样参数：{...} 内的原文，或单个记号
    private func readGroupRaw() -> String {
        skipSpaces()
        guard i < s.count else { return "" }
        if s[i] == "{" { return readBalanced(open: "{", close: "}") }
        if s[i] == "\\" {
            let start = i
            _ = readCommand()
            return String(s[start..<i])
        }
        i += 1
        return String(s[i - 1])
    }

    private func readBalanced(open: Character, close: Character) -> String {
        guard i < s.count && s[i] == open else { return "" }
        i += 1
        let start = i
        var level = 1
        while i < s.count {
            let c = s[i]
            if c == "\\" { i += 2; continue }
            if c == open { level += 1 }
            if c == close {
                level -= 1
                if level == 0 { break }
            }
            i += 1
        }
        let end = min(i, s.count)
        if i < s.count { i += 1 }
        return String(s[start..<end])
    }
}

// MARK: - Unicode 数学字母

func styledChar(_ c: Character, _ font: MathFont) -> String? {
    guard let a = c.asciiValue else { return nil }
    let upper = (65...90).contains(a), lower = (97...122).contains(a), digit = (48...57).contains(a)
    guard upper || lower || digit else { return nil }

    let exceptions: [Character: UInt32]
    let bases: (upper: UInt32, lower: UInt32, digit: UInt32?)
    switch font {
    case .normal: return nil
    case .bold: bases = (0x1D400, 0x1D41A, 0x1D7CE); exceptions = [:]
    case .italic: bases = (0x1D434, 0x1D44E, nil); exceptions = ["h": 0x210E]
    case .boldItalic: bases = (0x1D468, 0x1D482, 0x1D7CE); exceptions = [:]
    case .script:
        bases = (0x1D49C, 0x1D4B6, nil)
        exceptions = ["B": 0x212C, "E": 0x2130, "F": 0x2131, "H": 0x210B, "I": 0x2110, "L": 0x2112,
                      "M": 0x2133, "R": 0x211B, "e": 0x212F, "g": 0x210A, "o": 0x2134]
    case .fraktur:
        bases = (0x1D504, 0x1D51E, nil)
        exceptions = ["C": 0x212D, "H": 0x210C, "I": 0x2111, "R": 0x211C, "Z": 0x2128]
    case .doubleStruck:
        bases = (0x1D538, 0x1D552, 0x1D7D8)
        exceptions = ["C": 0x2102, "H": 0x210D, "N": 0x2115, "P": 0x2119, "Q": 0x211A, "R": 0x211D, "Z": 0x2124]
    case .sans: bases = (0x1D5A0, 0x1D5BA, 0x1D7E2); exceptions = [:]
    case .sansBold: bases = (0x1D5D4, 0x1D5EE, 0x1D7EC); exceptions = [:]
    case .mono: bases = (0x1D670, 0x1D68A, 0x1D7F6); exceptions = [:]
    }
    let code: UInt32
    if let e = exceptions[c] {
        code = e
    } else if upper {
        code = bases.upper + UInt32(a - 65)
    } else if lower {
        code = bases.lower + UInt32(a - 97)
    } else if let d = bases.digit {
        code = d + UInt32(a - 48)
    } else {
        return nil
    }
    return Unicode.Scalar(code).map { String(Character($0)) }
}

func escapeXML(_ s: String) -> String {
    guard s.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" }) else { return s }
    var out = ""
    out.reserveCapacity(s.count + 8)
    for c in s {
        switch c {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(c)
        }
    }
    return out
}

private func escapeAttr(_ s: String) -> String { escapeXML(s) }
