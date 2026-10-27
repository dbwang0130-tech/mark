// 在交给 cmark 之前把公式替换成占位符，避免 _ * \ 等被当成 Markdown 语法。
// 跳过围栏代码块和行内代码；支持 $...$、$$...$$、\(...\)、\[...\]。

struct MathSegment {
    let tex: String
    let display: Bool
}

enum MathExtractor {
    // 占位符：U+E000 + 序号 + U+E001（私用区字符，cmark 原样输出）
    static let openMark: [UInt8] = [0xEE, 0x80, 0x80]
    static let closeMark: [UInt8] = [0xEE, 0x80, 0x81]

    private static let newline = UInt8(ascii: "\n")
    private static let backslash = UInt8(ascii: "\\")
    private static let dollar = UInt8(ascii: "$")
    private static let backtick = UInt8(ascii: "`")
    private static let tilde = UInt8(ascii: "~")
    private static let quote = UInt8(ascii: ">")

    static func extract(_ source: String) -> (String, [MathSegment]) {
        let b = Array(source.utf8)
        let n = b.count
        // 快速路径：没有可能的公式定界符
        if !b.contains(dollar) && !b.contains(backslash) { return (source, []) }

        var out: [UInt8] = []
        out.reserveCapacity(n + 64)
        var segments: [MathSegment] = []
        var i = 0
        var atLineStart = true
        var fence: (char: UInt8, length: Int)?
        var lineInQuote = false
        // 缩进代码块识别：前一行为空（或已在缩进代码中）且缩进 ≥ 4；列表内的缩进视为续行
        var previousLineBlank = true
        var inIndentedCode = false
        var inList = false

        func isSpace(_ c: UInt8) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D }

        func lineEnd(from j: Int) -> Int {
            var k = j
            while k < n && b[k] != newline { k += 1 }
            return k < n ? k + 1 : n
        }

        /// j 处的换行之后是否紧跟空行（段落结束）
        func blankLineFollows(_ j: Int) -> Bool {
            var k = j + 1
            while k < n && (b[k] == 0x20 || b[k] == 0x09 || b[k] == quote) { k += 1 }
            return k >= n || b[k] == newline
        }

        func isListMarker(at k: Int) -> Bool {
            guard k < n else { return false }
            let c = b[k]
            if c == UInt8(ascii: "-") || c == UInt8(ascii: "*") || c == UInt8(ascii: "+") {
                return k + 1 < n && (b[k + 1] == 0x20 || b[k + 1] == 0x09)
            }
            var m = k
            while m < n && b[m] >= 0x30 && b[m] <= 0x39 && m - k < 9 { m += 1 }
            return m > k && m + 1 < n && (b[m] == UInt8(ascii: ".") || b[m] == UInt8(ascii: ")"))
                && (b[m + 1] == 0x20 || b[m + 1] == 0x09)
        }

        func emit(_ start: Int, _ end: Int, contentStart: Int, contentEnd: Int, display: Bool) {
            var tex = String(decoding: b[contentStart..<contentEnd], as: UTF8.self)
            if lineInQuote && tex.contains("\n") {
                tex = tex.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
                    var l = line[...]
                    while let f = l.first, f == " " || f == "\t" || f == ">" { l = l.dropFirst() }
                    return l
                }.joined(separator: "\n")
            }
            out.append(contentsOf: openMark)
            out.append(contentsOf: String(segments.count).utf8)
            out.append(contentsOf: closeMark)
            segments.append(MathSegment(tex: tex, display: display))
            i = end
        }

        while i < n {
            if atLineStart {
                atLineStart = false
                var j = i
                lineInQuote = false
                while j < n && (b[j] == 0x20 || b[j] == 0x09 || b[j] == quote) {
                    if b[j] == quote { lineInQuote = true }
                    j += 1
                }
                if j < n && (b[j] == backtick || b[j] == tilde) {
                    let c = b[j]
                    var k = j
                    while k < n && b[k] == c { k += 1 }
                    let run = k - j
                    if run >= 3 {
                        if let f = fence {
                            if c == f.char && run >= f.length { fence = nil }
                        } else {
                            fence = (c, run)
                        }
                        let e = lineEnd(from: i)
                        out.append(contentsOf: b[i..<e])
                        i = e
                        atLineStart = true
                        continue
                    }
                }
                if fence != nil {
                    let e = lineEnd(from: i)
                    out.append(contentsOf: b[i..<e])
                    i = e
                    atLineStart = true
                    continue
                }
                if !lineInQuote {
                    var indent = 0
                    var k = i
                    while k < n && (b[k] == 0x20 || b[k] == 0x09) { indent += b[k] == 0x09 ? 4 : 1; k += 1 }
                    if k >= n || b[k] == newline || b[k] == 0x0D {
                        previousLineBlank = true
                    } else {
                        if indent >= 4 && !inList && (previousLineBlank || inIndentedCode) {
                            inIndentedCode = true
                            previousLineBlank = false
                            let e = lineEnd(from: i)
                            out.append(contentsOf: b[i..<e])
                            i = e
                            atLineStart = true
                            continue
                        }
                        inIndentedCode = false
                        if isListMarker(at: k) {
                            inList = true
                        } else if indent == 0 && previousLineBlank {
                            inList = false
                        }
                        previousLineBlank = false
                    }
                } else {
                    previousLineBlank = false
                }
            }

            let c = b[i]
            switch c {
            case newline:
                out.append(c)
                i += 1
                atLineStart = true

            case backtick:
                // 行内代码：找长度相同的反引号串
                var k = i
                while k < n && b[k] == backtick { k += 1 }
                let run = k - i
                var j = k
                var closeEnd = -1
                while j < n {
                    if b[j] == newline && blankLineFollows(j) { break }
                    if b[j] == backtick {
                        var m = j
                        while m < n && b[m] == backtick { m += 1 }
                        if m - j == run { closeEnd = m; break }
                        j = m
                    } else {
                        j += 1
                    }
                }
                let end = closeEnd > 0 ? closeEnd : k
                out.append(contentsOf: b[i..<end])
                i = end

            case backslash:
                guard i + 1 < n else { out.append(c); i += 1; continue }
                let next = b[i + 1]
                if next == UInt8(ascii: "(") || next == UInt8(ascii: "[") {
                    let closer = next == UInt8(ascii: "(") ? UInt8(ascii: ")") : UInt8(ascii: "]")
                    var j = i + 2
                    var found = -1
                    while j + 1 < n {
                        if b[j] == newline && blankLineFollows(j) { break }
                        if b[j] == backslash {
                            if b[j + 1] == closer { found = j; break }
                            j += 2
                            continue
                        }
                        j += 1
                    }
                    if found > 0 {
                        emit(i, found + 2, contentStart: i + 2, contentEnd: found, display: next == UInt8(ascii: "["))
                        continue
                    }
                }
                if next == newline {
                    out.append(c)
                    i += 1
                } else {
                    out.append(c)
                    out.append(next)
                    i += 2
                }

            case dollar:
                if i + 1 < n && b[i + 1] == dollar {
                    // $$...$$
                    var j = i + 2
                    var found = -1
                    while j + 1 < n {
                        if b[j] == backslash { j += 2; continue }
                        if b[j] == dollar && b[j + 1] == dollar { found = j; break }
                        j += 1
                    }
                    if found > i + 2 {
                        emit(i, found + 2, contentStart: i + 2, contentEnd: found, display: true)
                        continue
                    }
                    out.append(contentsOf: [dollar, dollar])
                    i += 2
                    continue
                }
                // $...$：开头后不能是空白，结尾前不能是空白，结尾后不能紧跟数字（避免 $5 and $10）
                if i + 1 < n && !isSpace(b[i + 1]) {
                    var j = i + 1
                    var found = -1
                    while j < n {
                        let d = b[j]
                        if d == newline && blankLineFollows(j) { break }
                        if d == backslash { j += 2; continue }
                        if d == dollar {
                            let afterIsDigit = j + 1 < n && b[j + 1] >= 0x30 && b[j + 1] <= 0x39
                            if !isSpace(b[j - 1]) && !afterIsDigit { found = j }
                            break
                        }
                        j += 1
                    }
                    if found > i + 1 {
                        emit(i, found + 1, contentStart: i + 1, contentEnd: found, display: false)
                        continue
                    }
                }
                out.append(c)
                i += 1

            default:
                out.append(c)
                i += 1
            }
        }
        return (String(decoding: out, as: UTF8.self), segments)
    }

    /// 把渲染后 HTML 里的占位符换成 MathML。单独成段的 display 公式去掉外层 <p>。
    static func substitute(_ html: String, segments: [MathSegment]) -> String {
        guard !segments.isEmpty else { return html }
        let b = Array(html.utf8)
        let n = b.count
        var out: [UInt8] = []
        out.reserveCapacity(n + segments.count * 256)
        let pOpen = Array("<p>".utf8), pClose = Array("</p>".utf8)
        var i = 0
        while i < n {
            if b[i] == 0xEE && i + 2 < n && b[i + 1] == 0x80 && b[i + 2] == 0x80 {
                var j = i + 3
                var index = 0
                var digits = 0
                while j < n && b[j] >= 0x30 && b[j] <= 0x39 { index = index * 10 + Int(b[j] - 0x30); j += 1; digits += 1 }
                if digits > 0 && j + 2 < n && b[j] == 0xEE && b[j + 1] == 0x80 && b[j + 2] == 0x81 && index < segments.count {
                    let seg = segments[index]
                    j += 3
                    let standalone = seg.display && out.count >= 3 && Array(out.suffix(3)) == pOpen
                        && j + 4 <= n && Array(b[j..<j + 4]) == pClose
                    if standalone {
                        out.removeLast(3)
                        j += 4
                    }
                    out.append(contentsOf: render(seg, block: standalone).utf8)
                    i = j
                    continue
                }
            }
            out.append(b[i])
            i += 1
        }
        return String(decoding: out, as: UTF8.self)
    }

    private static func render(_ seg: MathSegment, block: Bool) -> String {
        let result = TeXToMathML.convert(seg.tex, display: seg.display)
        guard seg.display else { return result.mathML }
        let tag = result.tag.map { "<span class=\"math-tag\">\(escapeXML($0))</span>" } ?? ""
        return block
            ? "<div class=\"math-display\">\(result.mathML)\(tag)</div>"
            : "<span class=\"math-display-inline\">\(result.mathML)\(tag)</span>"
    }
}
