// 轻量代码高亮：按字节扫描，输出带 class 的 <span>。

import Foundation

public enum SyntaxHighlighter {
    /// 返回高亮后的 HTML（已转义）。语言未知时返回 nil。
    public static func highlight(_ code: String, language: String) -> String? {
        guard let kind = Languages.lookup(language) else { return nil }
        var lexer = Lexer(Array(code.utf8))
        switch kind {
        case .generic(let spec): lexer.generic(spec)
        case .markup: lexer.markup()
        case .css: lexer.css()
        case .json: lexer.json()
        case .yaml: lexer.yaml()
        case .diff: lexer.diff()
        case .ini: lexer.ini()
        }
        return String(decoding: lexer.out, as: UTF8.self)
    }

    public static func escape(_ code: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(code.utf8.count)
        for c in code.utf8 { appendEscaped(&out, c) }
        return String(decoding: out, as: UTF8.self)
    }
}

@inline(__always)
private func appendEscaped(_ out: inout [UInt8], _ c: UInt8) {
    switch c {
    case UInt8(ascii: "&"): out.append(contentsOf: [0x26, 0x61, 0x6D, 0x70, 0x3B])        // &amp;
    case UInt8(ascii: "<"): out.append(contentsOf: [0x26, 0x6C, 0x74, 0x3B])              // &lt;
    case UInt8(ascii: ">"): out.append(contentsOf: [0x26, 0x67, 0x74, 0x3B])              // &gt;
    default: out.append(c)
    }
}

private enum Token: String {
    case keyword = "hl-kw", type = "hl-type", string = "hl-str", number = "hl-num", comment = "hl-com"
    case literal = "hl-lit", function = "hl-fn", meta = "hl-meta", variable = "hl-var", tag = "hl-tag"
    case attribute = "hl-attr", builtin = "hl-bi", added = "hl-add", removed = "hl-del", punct = "hl-punct"
    case preprocessor = "hl-pre"
}

private let nl = UInt8(ascii: "\n")

@inline(__always) private func isDigit(_ c: UInt8) -> Bool { c >= 0x30 && c <= 0x39 }
@inline(__always) private func isAlpha(_ c: UInt8) -> Bool { (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A }
@inline(__always) private func isIdentStart(_ c: UInt8) -> Bool { isAlpha(c) || c == 0x5F || c >= 0x80 }
@inline(__always) private func isIdent(_ c: UInt8) -> Bool { isIdentStart(c) || isDigit(c) }
@inline(__always) private func isBlank(_ c: UInt8) -> Bool { c == 0x20 || c == 0x09 }

private struct Lexer {
    let b: [UInt8]
    let n: Int
    var i = 0
    var out: [UInt8] = []

    init(_ bytes: [UInt8]) {
        b = bytes
        n = bytes.count
        out.reserveCapacity(bytes.count * 2)
    }

    // MARK: 输出

    mutating func plain(_ start: Int, _ end: Int) {
        var k = start
        while k < end { appendEscaped(&out, b[k]); k += 1 }
    }

    mutating func span(_ token: Token, _ start: Int, _ end: Int) {
        guard end > start else { return }
        out.append(contentsOf: "<span class=\"".utf8)
        out.append(contentsOf: token.rawValue.utf8)
        out.append(contentsOf: "\">".utf8)
        plain(start, end)
        out.append(contentsOf: "</span>".utf8)
    }

    func matches(_ s: String, at j: Int) -> Bool {
        var k = j
        for c in s.utf8 {
            if k >= n || b[k] != c { return false }
            k += 1
        }
        return true
    }

    func lineEnd(_ j: Int) -> Int {
        var k = j
        while k < n && b[k] != nl { k += 1 }
        return k
    }

    func find(_ s: String, from j: Int) -> Int? {
        let first = s.utf8.first!
        var k = j
        while k < n {
            if b[k] == first && matches(s, at: k) { return k }
            k += 1
        }
        return nil
    }

    /// 扫描引号字符串，返回结束位置（含收尾引号）
    func scanString(_ start: Int, quote: UInt8, multiline: Bool) -> Int {
        var k = start + 1
        while k < n {
            let c = b[k]
            if c == UInt8(ascii: "\\") { k += 2; continue }
            if c == quote { return k + 1 }
            if c == nl && !multiline { return k }
            k += 1
        }
        return n
    }

    func scanNumber(_ start: Int) -> Int {
        var k = start
        if b[k] == UInt8(ascii: "0") && k + 1 < n && "xXbBoO".utf8.contains(b[k + 1]) { k += 2 }
        while k < n {
            let c = b[k]
            if isDigit(c) || isAlpha(c) || c == 0x5F {
                // 指数后的正负号
                if (c == UInt8(ascii: "e") || c == UInt8(ascii: "E")) && k + 1 < n
                    && (b[k + 1] == UInt8(ascii: "+") || b[k + 1] == UInt8(ascii: "-")) {
                    k += 2
                    continue
                }
                k += 1
            } else if c == UInt8(ascii: ".") && k + 1 < n && isDigit(b[k + 1]) {
                k += 1
            } else {
                break
            }
        }
        return k
    }

    func identEnd(_ start: Int, extra: [UInt8] = []) -> Int {
        var k = start
        while k < n && (isIdent(b[k]) || extra.contains(b[k])) { k += 1 }
        return k
    }

    func nextNonBlank(_ j: Int) -> UInt8? {
        var k = j
        while k < n && isBlank(b[k]) { k += 1 }
        return k < n ? b[k] : nil
    }

    // MARK: 通用语言

    mutating func generic(_ spec: LanguageSpec) {
        var atLineStart = true
        while i < n {
            let c = b[i]

            if c == nl { out.append(c); i += 1; atLineStart = true; continue }
            if isBlank(c) { out.append(c); i += 1; continue }
            defer { atLineStart = false }

            if spec.preprocessor && atLineStart && c == UInt8(ascii: "#") {
                var e = lineEnd(i)
                while e > i && e < n && b[e - 1] == UInt8(ascii: "\\") { e = lineEnd(e + 1) }
                span(.preprocessor, i, e); i = e; continue
            }

            var handled = false
            for lc in spec.lineComments where matches(lc, at: i) {
                // shell/ini 风格的 # 注释要求前面是空白或行首，避免误伤 $#、x#y
                if lc == "#" && i > 0 && !isBlank(b[i - 1]) && b[i - 1] != nl && spec.dollarVariables { continue }
                let e = lineEnd(i)
                span(.comment, i, e); i = e; handled = true; break
            }
            if handled { continue }
            for (open, close) in spec.blockComments where matches(open, at: i) {
                let e = find(close, from: i + open.utf8.count).map { $0 + close.utf8.count } ?? n
                span(.comment, i, e); i = e; handled = true; break
            }
            if handled { continue }

            if spec.tripleQuotes && (c == UInt8(ascii: "\"") || c == UInt8(ascii: "'")) && i + 2 < n
                && b[i + 1] == c && b[i + 2] == c {
                let q = c == UInt8(ascii: "\"") ? "\"\"\"" : "'''"
                let e = find(q, from: i + 3).map { $0 + 3 } ?? n
                span(.string, i, e); i = e; continue
            }
            if spec.multilineQuotes.contains(c) {
                let e = scanString(i, quote: c, multiline: true)
                span(.string, i, e); i = e; continue
            }
            if spec.stringQuotes.contains(c) {
                let e = scanString(i, quote: c, multiline: false)
                span(.string, i, e); i = e; continue
            }

            if isDigit(c) || (c == UInt8(ascii: ".") && i + 1 < n && isDigit(b[i + 1]) && (i == 0 || !isIdent(b[i - 1]))) {
                if i > 0 && isIdent(b[i - 1]) {
                    out.append(c); i += 1; continue
                }
                let e = scanNumber(i)
                span(.number, i, e); i = e; continue
            }

            if spec.annotations && c == UInt8(ascii: "@") && i + 1 < n && isIdentStart(b[i + 1]) {
                let e = identEnd(i + 1, extra: [UInt8(ascii: ".")])
                span(.meta, i, e); i = e; continue
            }

            if spec.dollarVariables && c == UInt8(ascii: "$") && i + 1 < n {
                let d = b[i + 1]
                if d == UInt8(ascii: "{") || d == UInt8(ascii: "(") {
                    let close = d == UInt8(ascii: "{") ? UInt8(ascii: "}") : UInt8(ascii: ")")
                    var e = i + 2
                    while e < n && b[e] != close && b[e] != nl { e += 1 }
                    if e < n && b[e] == close { e += 1 }
                    span(.variable, i, e); i = e; continue
                }
                if isIdent(d) || "@#?*!$-".utf8.contains(d) {
                    let e = isIdent(d) ? identEnd(i + 1) : i + 2
                    span(.variable, i, e); i = e; continue
                }
            }

            if isIdentStart(c) || spec.identifierExtra.contains(c) {
                let e = identEnd(i, extra: spec.identifierExtra)
                let word = String(decoding: b[i..<e], as: UTF8.self)
                let key = spec.caseInsensitive ? word.lowercased() : word
                if spec.keywords.contains(key) {
                    span(.keyword, i, e)
                } else if spec.literals.contains(key) {
                    span(.literal, i, e)
                } else if spec.types.contains(key) {
                    span(.type, i, e)
                } else if spec.builtins.contains(key) {
                    span(.builtin, i, e)
                } else if nextNonBlank(e) == UInt8(ascii: "(") {
                    span(.function, i, e)
                } else if spec.capitalizedTypes && b[i] >= 0x41 && b[i] <= 0x5A {
                    span(.type, i, e)
                } else {
                    plain(i, e)
                }
                i = e
                continue
            }

            appendEscaped(&out, c)
            i += 1
        }
    }

    // MARK: HTML / XML

    mutating func markup() {
        while i < n {
            let c = b[i]
            if c == UInt8(ascii: "<") {
                if matches("<!--", at: i) {
                    let e = find("-->", from: i + 4).map { $0 + 3 } ?? n
                    span(.comment, i, e); i = e; continue
                }
                if matches("<![CDATA[", at: i) {
                    let e = find("]]>", from: i + 9).map { $0 + 3 } ?? n
                    span(.string, i, e); i = e; continue
                }
                if i + 1 < n && (b[i + 1] == UInt8(ascii: "!") || b[i + 1] == UInt8(ascii: "?")) {
                    var e = i
                    while e < n && b[e] != UInt8(ascii: ">") { e += 1 }
                    e = min(e + 1, n)
                    span(.meta, i, e); i = e; continue
                }
                // 标签
                var e = i + 1
                if e < n && b[e] == UInt8(ascii: "/") { e += 1 }
                let nameEnd = identEnd(e, extra: [UInt8(ascii: "-"), UInt8(ascii: ":"), UInt8(ascii: ".")])
                if nameEnd == e { appendEscaped(&out, c); i += 1; continue }
                span(.punct, i, e)
                span(.tag, e, nameEnd)
                i = nameEnd
                // 属性
                while i < n && b[i] != UInt8(ascii: ">") {
                    let d = b[i]
                    if d == UInt8(ascii: "\"") || d == UInt8(ascii: "'") {
                        let s = scanString(i, quote: d, multiline: true)
                        span(.string, i, s); i = s
                    } else if isIdentStart(d) {
                        let s = identEnd(i, extra: [UInt8(ascii: "-"), UInt8(ascii: ":"), UInt8(ascii: "@"), UInt8(ascii: ".")])
                        span(.attribute, i, s); i = s
                    } else if d == UInt8(ascii: "/") || d == UInt8(ascii: "=") {
                        span(.punct, i, i + 1); i += 1
                    } else {
                        appendEscaped(&out, d); i += 1
                    }
                }
                if i < n { span(.punct, i, i + 1); i += 1 }
                continue
            }
            if c == UInt8(ascii: "&") {
                var e = i + 1
                while e < n && e - i < 12 && (isIdent(b[e]) || b[e] == UInt8(ascii: "#")) { e += 1 }
                if e < n && b[e] == UInt8(ascii: ";") && e > i + 1 {
                    span(.literal, i, e + 1); i = e + 1; continue
                }
            }
            appendEscaped(&out, c)
            i += 1
        }
    }

    // MARK: CSS / SCSS / LESS

    mutating func css() {
        var depth = 0
        while i < n {
            let c = b[i]
            if matches("/*", at: i) {
                let e = find("*/", from: i + 2).map { $0 + 2 } ?? n
                span(.comment, i, e); i = e; continue
            }
            if matches("//", at: i) && (i == 0 || b[i - 1] != UInt8(ascii: ":")) {
                let e = lineEnd(i)
                span(.comment, i, e); i = e; continue
            }
            if c == UInt8(ascii: "\"") || c == UInt8(ascii: "'") {
                let e = scanString(i, quote: c, multiline: false)
                span(.string, i, e); i = e; continue
            }
            if c == UInt8(ascii: "{") { depth += 1 }
            if c == UInt8(ascii: "}") { depth = max(0, depth - 1) }
            if c == UInt8(ascii: "@") && i + 1 < n && isIdentStart(b[i + 1]) {
                let e = identEnd(i + 1, extra: [UInt8(ascii: "-")])
                span(.keyword, i, e); i = e; continue
            }
            if c == UInt8(ascii: "$") && i + 1 < n && isIdentStart(b[i + 1]) {
                let e = identEnd(i + 1, extra: [UInt8(ascii: "-")])
                span(.variable, i, e); i = e; continue
            }
            if c == UInt8(ascii: "#") && depth > 0 && i + 1 < n && isIdent(b[i + 1]) {
                let e = identEnd(i + 1)
                span(.number, i, e); i = e; continue
            }
            if isDigit(c) || (c == UInt8(ascii: ".") && i + 1 < n && isDigit(b[i + 1])) || (c == UInt8(ascii: "-") && i + 1 < n && isDigit(b[i + 1])) {
                if i > 0 && (isIdent(b[i - 1]) || b[i - 1] == UInt8(ascii: "-")) { out.append(c); i += 1; continue }
                var e = i + 1
                while e < n && (isDigit(b[e]) || b[e] == UInt8(ascii: ".")) { e += 1 }
                while e < n && (isAlpha(b[e]) || b[e] == UInt8(ascii: "%")) { e += 1 }
                span(.number, i, e); i = e; continue
            }
            if isIdentStart(c) || c == UInt8(ascii: "-") {
                let e = identEnd(i, extra: [UInt8(ascii: "-")])
                if e == i { appendEscaped(&out, c); i += 1; continue }
                let next = nextNonBlank(e)
                if depth > 0 && next == UInt8(ascii: ":") {
                    span(.attribute, i, e)
                } else if next == UInt8(ascii: "(") {
                    span(.function, i, e)
                } else if depth == 0 || next == UInt8(ascii: "{") {
                    // 选择器
                    let prev = i > 0 ? b[i - 1] : 0
                    span(prev == UInt8(ascii: ".") || prev == UInt8(ascii: "#") ? .type : (prev == UInt8(ascii: ":") ? .keyword : .tag), i, e)
                } else if matches("!important", at: i - 1) {
                    span(.keyword, i, e)
                } else {
                    span(.literal, i, e)
                }
                i = e
                continue
            }
            appendEscaped(&out, c)
            i += 1
        }
    }

    // MARK: JSON

    mutating func json() {
        while i < n {
            let c = b[i]
            if c == UInt8(ascii: "\"") {
                let e = scanString(i, quote: c, multiline: false)
                span(nextNonBlank(e) == UInt8(ascii: ":") ? .attribute : .string, i, e); i = e; continue
            }
            if matches("//", at: i) {
                let e = lineEnd(i)
                span(.comment, i, e); i = e; continue
            }
            if matches("/*", at: i) {
                let e = find("*/", from: i + 2).map { $0 + 2 } ?? n
                span(.comment, i, e); i = e; continue
            }
            if isDigit(c) || (c == UInt8(ascii: "-") && i + 1 < n && isDigit(b[i + 1])) {
                let e = scanNumber(c == UInt8(ascii: "-") ? i + 1 : i)
                span(.number, i, e); i = e; continue
            }
            if isAlpha(c) {
                let e = identEnd(i)
                span(.literal, i, e); i = e; continue
            }
            appendEscaped(&out, c)
            i += 1
        }
    }

    // MARK: YAML

    mutating func yaml() {
        while i < n {
            let lineStart = i
            let e = lineEnd(i)
            var k = i
            while k < e && isBlank(b[k]) { k += 1 }
            plain(lineStart, k)
            i = k
            if matches("---", at: i) || matches("...", at: i) {
                span(.meta, i, e); i = e
            } else {
                if i + 1 < e && b[i] == UInt8(ascii: "-") && isBlank(b[i + 1]) {
                    span(.punct, i, i + 1); i += 1
                    while i < e && isBlank(b[i]) { out.append(b[i]); i += 1 }
                }
                // 键
                var j = i
                var keyEnd = -1
                if j < e && b[j] != UInt8(ascii: "#") && b[j] != UInt8(ascii: "\"") && b[j] != UInt8(ascii: "'") {
                    while j < e {
                        if b[j] == UInt8(ascii: ":") && (j + 1 == e || isBlank(b[j + 1])) { keyEnd = j; break }
                        if b[j] == UInt8(ascii: "#") && j > i && isBlank(b[j - 1]) { break }
                        j += 1
                    }
                } else if j < e && (b[j] == UInt8(ascii: "\"") || b[j] == UInt8(ascii: "'")) {
                    let s = scanString(j, quote: b[j], multiline: false)
                    if s < e && b[s] == UInt8(ascii: ":") { keyEnd = s }
                }
                if keyEnd >= 0 {
                    span(.attribute, i, keyEnd)
                    span(.punct, keyEnd, keyEnd + 1)
                    i = keyEnd + 1
                }
                yamlValue(until: e)
            }
            if i < n { out.append(nl); i += 1 }
        }
    }

    private mutating func yamlValue(until e: Int) {
        while i < e && isBlank(b[i]) { out.append(b[i]); i += 1 }
        guard i < e else { return }
        let c = b[i]
        if c == UInt8(ascii: "#") { span(.comment, i, e); i = e; return }
        if c == UInt8(ascii: "\"") || c == UInt8(ascii: "'") {
            let s = min(scanString(i, quote: c, multiline: false), e)
            span(.string, i, s); i = s
            yamlValue(until: e)
            return
        }
        if c == UInt8(ascii: "&") || c == UInt8(ascii: "*") || c == UInt8(ascii: "!") {
            var s = i + 1
            while s < e && !isBlank(b[s]) { s += 1 }
            span(c == UInt8(ascii: "!") ? .type : .variable, i, s); i = s
            yamlValue(until: e)
            return
        }
        if c == UInt8(ascii: "|") || c == UInt8(ascii: ">") {
            span(.punct, i, e); i = e; return
        }
        // 普通标量：到行尾或 " #" 注释
        var s = i
        while s < e && !(b[s] == UInt8(ascii: "#") && s > i && isBlank(b[s - 1])) { s += 1 }
        var valueEnd = s
        while valueEnd > i && isBlank(b[valueEnd - 1]) { valueEnd -= 1 }
        let word = String(decoding: b[i..<valueEnd], as: UTF8.self)
        let literals: Set<String> = ["true", "false", "null", "yes", "no", "on", "off", "~", "True", "False", "Null", "NULL", "TRUE", "FALSE"]
        if literals.contains(word) {
            span(.literal, i, valueEnd)
        } else if Double(word.replacingOccurrences(of: "_", with: "")) != nil {
            span(.number, i, valueEnd)
        } else {
            plain(i, valueEnd)
        }
        plain(valueEnd, s)
        i = s
        if i < e { span(.comment, i, e); i = e }
    }

    // MARK: diff

    mutating func diff() {
        while i < n {
            let e = lineEnd(i)
            let token: Token?
            if matches("+++", at: i) || matches("---", at: i) || matches("diff ", at: i) || matches("index ", at: i) {
                token = .meta
            } else if matches("@@", at: i) {
                token = .function
            } else if b[i] == UInt8(ascii: "+") || b[i] == UInt8(ascii: ">") {
                token = .added
            } else if b[i] == UInt8(ascii: "-") || b[i] == UInt8(ascii: "<") {
                token = .removed
            } else {
                token = nil
            }
            if let token, e > i { span(token, i, e) } else { plain(i, e) }
            i = e
            if i < n { out.append(nl); i += 1 }
        }
    }

    // MARK: INI / TOML / properties / .env

    mutating func ini() {
        while i < n {
            let e = lineEnd(i)
            var k = i
            while k < e && isBlank(b[k]) { k += 1 }
            plain(i, k)
            i = k
            if i < e && (b[i] == UInt8(ascii: "#") || b[i] == UInt8(ascii: ";")) {
                span(.comment, i, e)
            } else if i < e && b[i] == UInt8(ascii: "[") {
                span(.type, i, e)
            } else if let eq = (i..<e).first(where: { b[$0] == UInt8(ascii: "=") || b[$0] == UInt8(ascii: ":") }) {
                var keyEnd = eq
                while keyEnd > i && isBlank(b[keyEnd - 1]) { keyEnd -= 1 }
                span(.attribute, i, keyEnd)
                plain(keyEnd, eq + 1)
                i = eq + 1
                while i < e && isBlank(b[i]) { out.append(b[i]); i += 1 }
                if i < e {
                    let c = b[i]
                    if c == UInt8(ascii: "\"") || c == UInt8(ascii: "'") {
                        span(.string, i, e)
                    } else {
                        let word = String(decoding: b[i..<e], as: UTF8.self).trimmingCharacters(in: .whitespaces)
                        if ["true", "false", "yes", "no", "on", "off"].contains(word.lowercased()) {
                            span(.literal, i, e)
                        } else if Double(word) != nil {
                            span(.number, i, e)
                        } else {
                            span(.string, i, e)
                        }
                    }
                }
            } else {
                plain(i, e)
            }
            i = e
            if i < n { out.append(nl); i += 1 }
        }
    }
}
