// 预览样式：配色方案提供 CSS 变量，版式规则所有方案共用

enum Stylesheet {
    static func css(_ style: RenderStyle) -> String {
        let theme = style.theme
        let variables: String
        switch style.appearance {
        case .system:
            variables = """
            :root { color-scheme: light dark; \(theme.light.cssVariables) }
            @media (prefers-color-scheme: dark) { :root { \(theme.dark.cssVariables) } }
            """
        case .light:
            variables = ":root { color-scheme: light; \(theme.light.cssVariables) }"
        case .dark:
            variables = ":root { color-scheme: dark; \(theme.dark.cssVariables) }"
        }
        return variables + "\nbody { font-family: \(theme.bodyFont); }\n" + layout
    }

    private static let layout = """
    html { background: var(--bg); }
    body { margin: 0; color: var(--fg); background: var(--bg);
      font-size: 15px; line-height: 1.65;
      -webkit-text-size-adjust: 100%; word-wrap: break-word; }
    .markdown-body { max-width: 820px; margin: 0 auto; padding: 32px 40px 56px; }
    .markdown-body > *:first-child { margin-top: 0 !important; }
    a { color: var(--link); text-decoration: none; }
    ::selection { background: -apple-system-selected-text-background; }
    a:hover { text-decoration: underline; }
    p, blockquote, ul, ol, dl, table, pre, details, .math-display { margin: 0 0 16px; }
    h1, h2, h3, h4, h5, h6 { margin: 28px 0 12px; font-weight: 700; line-height: 1.25; letter-spacing: -.01em; }
    h1 { font-size: 2em; }
    h2 { font-size: 1.5em; }
    h3 { font-size: 1.25em; } h4 { font-size: 1em; } h5 { font-size: .875em; }
    h6 { font-size: .85em; color: var(--fg-muted); }
    hr { height: 1px; padding: 0; margin: 28px 0; background: var(--separator); border: 0; }
    blockquote { padding: 0 1em; color: var(--fg-muted); border-left: 3px solid var(--separator); }
    blockquote > :last-child { margin-bottom: 0; }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: .25em; }
    li > p { margin-top: 16px; }
    ul ul, ul ol, ol ol, ol ul { margin-bottom: 0; }
    li:has(> input[type="checkbox"]:first-child), li:has(> p:first-child > input[type="checkbox"]:first-child) { list-style: none; }
    li > input[type="checkbox"]:first-child, li > p:first-child > input[type="checkbox"]:first-child { margin: 0 .35em .2em -1.5em; vertical-align: middle; }
    img { max-width: 100%; box-sizing: content-box; border-radius: 6px; }
    mark { background: var(--mark); color: inherit; }
    del { color: var(--fg-muted); }
    table { border-spacing: 0; border-collapse: separate; display: block; width: max-content; max-width: 100%; overflow: auto;
      border: 1px solid var(--separator); border-radius: 8px; }
    th, td { padding: 6px 14px; border: 0; }
    td { border-top: 1px solid var(--separator); }
    th + th, td + td { border-left: 1px solid var(--separator); }
    th { font-weight: 600; }
    tr { background: transparent; }
    tbody tr:nth-child(2n) { background: var(--row-alt); }
    code, kbd, pre, samp { font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, monospace; }
    code { padding: .15em .4em; margin: 0; font-size: 85%; white-space: break-spaces; background: var(--code-bg); border-radius: 5px; }
    kbd { display: inline-block; padding: 3px 6px; font-size: 11px; line-height: 10px; border: 1px solid var(--separator);
      border-radius: 5px; box-shadow: 0 1px 0 var(--separator); background: var(--fill); }
    pre { position: relative; padding: 14px 16px; overflow: auto; font-size: 13px; line-height: 1.5;
      background: var(--fill); border: 1px solid var(--separator); border-radius: 10px; }
    pre code { display: block; padding: 0; margin: 0; overflow: visible; font-size: 100%; white-space: pre;
      background: transparent; border: 0; word-wrap: normal; }
    pre[data-lang]::before { content: attr(data-lang); position: absolute; top: 6px; right: 10px;
      font: 11px -apple-system, sans-serif; color: var(--fg-muted); text-transform: lowercase; opacity: .8; }
    pre.front-matter { color: var(--fg-muted); }
    .footnotes { font-size: 12px; color: var(--fg-muted); border-top: 1px solid var(--separator); padding-top: 12px; margin-top: 32px; }
    .footnotes ol { padding-left: 16px; }
    sup a[data-footnote-ref]::before { content: "["; } sup a[data-footnote-ref]::after { content: "]"; }
    details summary { cursor: pointer; }
    .hl-kw { color: var(--hl-kw); font-weight: 600; } .hl-type { color: var(--hl-type); } .hl-str { color: var(--hl-str); }
    .hl-num { color: var(--hl-num); } .hl-com { color: var(--hl-com); font-style: italic; }
    .hl-lit { color: var(--hl-lit); font-weight: 600; } .hl-fn { color: var(--hl-fn); } .hl-meta { color: var(--hl-meta); } .hl-pre { color: var(--hl-pre); }
    .hl-var { color: var(--hl-var); } .hl-tag { color: var(--hl-tag); } .hl-attr { color: var(--hl-attr); }
    .hl-bi { color: var(--hl-bi); } .hl-punct { color: var(--fg-muted); }
    .hl-add { color: var(--hl-add-fg); background: var(--hl-add-bg); display: inline-block; min-width: 100%; }
    .hl-del { color: var(--hl-del-fg); background: var(--hl-del-bg); display: inline-block; min-width: 100%; }
    /* 表格 align=right 会给 MathML 带入 -webkit-right，导致 WebKit 排版错乱，这里重置 */
    math { text-align: initial; font-family: "STIX Two Math", "Latin Modern Math", math; font-size: 1.1em; }
    .math-display { position: relative; overflow-x: auto; overflow-y: hidden; padding: 2px 0; text-align: center; }
    .math-display math { display: block; margin: 0 auto; }
    .math-display-inline { display: block; text-align: center; margin: 8px 0; }
    .math-tag { position: absolute; right: 0; top: 50%; transform: translateY(-50%); }
    merror { color: var(--error); background: transparent; border: 0; }
    merror mtext { font-family: ui-monospace, Menlo, monospace; font-size: .8em; }
    """
}
