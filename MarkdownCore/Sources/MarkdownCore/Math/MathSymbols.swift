// LaTeX 命令 → Unicode 符号表

enum MathSymbols {
    /// 普通标识符（<mi>），小写希腊字母等
    static let identifiers: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ϵ", "varepsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ",
        "varkappa": "ϰ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "omicron": "ο",
        "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς",
        "tau": "τ", "upsilon": "υ", "phi": "ϕ", "varphi": "φ", "chi": "χ", "psi": "ψ",
        "omega": "ω", "digamma": "ϝ",
        "infty": "∞", "partial": "∂", "hbar": "ℏ", "hslash": "ℏ", "ell": "ℓ", "wp": "℘",
        "imath": "ı", "jmath": "ȷ", "eth": "ð",
    ]

    /// 直立标识符（<mi mathvariant="normal">）
    static let uprightIdentifiers: [String: String] = [
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π",
        "Sigma": "Σ", "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        "nabla": "∇", "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ", "beth": "ℶ", "gimel": "ℷ",
        "emptyset": "∅", "varnothing": "∅", "forall": "∀", "exists": "∃", "nexists": "∄",
        "neg": "¬", "lnot": "¬", "top": "⊤", "bot": "⊥", "angle": "∠", "measuredangle": "∡",
        "triangle": "△", "Box": "□", "square": "□", "blacksquare": "■", "Diamond": "◇",
        "clubsuit": "♣", "diamondsuit": "♢", "heartsuit": "♡", "spadesuit": "♠",
        "flat": "♭", "natural": "♮", "sharp": "♯", "prime": "′", "degree": "°",
        "checkmark": "✓", "dagger": "†", "ddagger": "‡", "S": "§", "P": "¶",
        "copyright": "©", "pounds": "£", "yen": "¥", "circledR": "®", "mho": "℧",
        "complement": "∁", "Finv": "Ⅎ", "Game": "⅁", "infin": "∞",
        "#": "#", "%": "%", "&": "&", "$": "$", "_": "_",
    ]

    /// 运算符 / 关系符 / 箭头（<mo>）
    static let operators: [String: String] = [
        // 二元运算
        "pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "⋅", "ast": "∗", "star": "⋆",
        "circ": "∘", "bullet": "∙", "oplus": "⊕", "ominus": "⊖", "otimes": "⊗", "oslash": "⊘",
        "odot": "⊙", "cap": "∩", "cup": "∪", "sqcap": "⊓", "sqcup": "⊔", "vee": "∨", "lor": "∨",
        "wedge": "∧", "land": "∧", "setminus": "∖", "smallsetminus": "∖", "backslash": "∖",
        "wr": "≀", "uplus": "⊎", "amalg": "⨿", "diamond": "⋄", "bigtriangleup": "△",
        "bigtriangledown": "▽", "triangleleft": "◃", "triangleright": "▹", "lhd": "⊲", "rhd": "⊳",
        "unlhd": "⊴", "unrhd": "⊵", "cdotp": "⋅", "centerdot": "⋅", "boxplus": "⊞",
        "boxminus": "⊟", "boxtimes": "⊠", "boxdot": "⊡", "dotplus": "∔", "divideontimes": "⋇",
        "ltimes": "⋉", "rtimes": "⋊", "curlyvee": "⋎", "curlywedge": "⋏", "barwedge": "⊼",
        "veebar": "⊻", "intercal": "⊺", "circledast": "⊛", "circledcirc": "⊚", "circleddash": "⊝",
        // 关系
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠", "equiv": "≡",
        "approx": "≈", "approxeq": "≊", "cong": "≅", "sim": "∼", "simeq": "≃", "propto": "∝",
        "ll": "≪", "gg": "≫", "lll": "⋘", "ggg": "⋙", "subset": "⊂", "supset": "⊃",
        "subseteq": "⊆", "supseteq": "⊇", "subsetneq": "⊊", "supsetneq": "⊋", "nsubseteq": "⊈",
        "nsupseteq": "⊉", "sqsubset": "⊏", "sqsupset": "⊐", "sqsubseteq": "⊑", "sqsupseteq": "⊒",
        "in": "∈", "ni": "∋", "owns": "∋", "notin": "∉", "vdash": "⊢", "dashv": "⊣",
        "models": "⊨", "vDash": "⊨", "Vdash": "⊩", "perp": "⊥", "mid": "∣", "nmid": "∤",
        "parallel": "∥", "nparallel": "∦", "asymp": "≍", "bowtie": "⋈", "Join": "⋈",
        "smile": "⌣", "frown": "⌢", "doteq": "≐", "triangleq": "≜", "coloneqq": "≔",
        "eqqcolon": "≕", "coloneq": "≔", "leqslant": "⩽", "geqslant": "⩾", "lesssim": "≲",
        "gtrsim": "≳", "prec": "≺", "succ": "≻", "preceq": "⪯", "succeq": "⪰", "nless": "≮",
        "ngtr": "≯", "nleq": "≰", "ngeq": "≱", "lneq": "⪇", "gneq": "⪈", "nsim": "≁",
        "ncong": "≇", "therefore": "∴", "because": "∵", "lt": "<", "gt": ">",
        "leqq": "≦", "geqq": "≧", "lessgtr": "≶", "gtrless": "≷", "simeqq": "≅",
        // 箭头
        "to": "→", "rightarrow": "→", "leftarrow": "←", "gets": "←", "leftrightarrow": "↔",
        "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔", "iff": "⟺",
        "implies": "⟹", "impliedby": "⟸", "longrightarrow": "⟶", "longleftarrow": "⟵",
        "longleftrightarrow": "⟷", "Longrightarrow": "⟹", "Longleftarrow": "⟸",
        "Longleftrightarrow": "⟺", "mapsto": "↦", "longmapsto": "⟼", "uparrow": "↑",
        "downarrow": "↓", "updownarrow": "↕", "Uparrow": "⇑", "Downarrow": "⇓",
        "Updownarrow": "⇕", "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖",
        "hookrightarrow": "↪", "hookleftarrow": "↩", "rightharpoonup": "⇀",
        "rightharpoondown": "⇁", "leftharpoonup": "↼", "leftharpoondown": "↽",
        "rightleftharpoons": "⇌", "leftrightharpoons": "⇋", "leadsto": "⇝",
        "rightsquigarrow": "⇝", "twoheadrightarrow": "↠", "twoheadleftarrow": "↞",
        "rightrightarrows": "⇉", "leftleftarrows": "⇇", "rightleftarrows": "⇄",
        "leftrightarrows": "⇆", "circlearrowleft": "↺", "circlearrowright": "↻",
        "curvearrowleft": "↶", "curvearrowright": "↷", "nrightarrow": "↛", "nleftarrow": "↚",
        "nRightarrow": "⇏", "nLeftarrow": "⇍", "nleftrightarrow": "↮", "nLeftrightarrow": "⇎",
        "upuparrows": "⇈", "downdownarrows": "⇊", "restriction": "↾", "longleftrightarrows": "⇆",
        // 省略号与标点
        "ldots": "…", "dots": "…", "dotsc": "…", "dotso": "…", "cdots": "⋯", "dotsb": "⋯",
        "dotsm": "⋯", "dotsi": "⋯", "vdots": "⋮", "ddots": "⋱", "colon": ":",
    ]

    /// 定界符（<mo stretchy="false">），也用于 \left \right \big
    static let delimiters: [String: String] = [
        "{": "{", "}": "}", "lbrace": "{", "rbrace": "}", "|": "‖",
        "langle": "⟨", "rangle": "⟩", "lvert": "|", "rvert": "|", "vert": "|",
        "lVert": "‖", "rVert": "‖", "Vert": "‖", "lfloor": "⌊", "rfloor": "⌋",
        "lceil": "⌈", "rceil": "⌉", "ulcorner": "⌜", "urcorner": "⌝", "llcorner": "⌞",
        "lrcorner": "⌟", "lgroup": "⟮", "rgroup": "⟯", "lmoustache": "⎰", "rmoustache": "⎱",
        "lbrack": "[", "rbrack": "]", "lparen": "(", "rparen": ")",
    ]

    /// 大型运算符：符号 + 是否在 display 模式下把上下标放在正上下方
    static let largeOperators: [String: (String, Bool)] = [
        "sum": ("∑", true), "prod": ("∏", true), "coprod": ("∐", true),
        "bigcup": ("⋃", true), "bigcap": ("⋂", true), "bigvee": ("⋁", true),
        "bigwedge": ("⋀", true), "bigoplus": ("⨁", true), "bigotimes": ("⨂", true),
        "bigodot": ("⨀", true), "biguplus": ("⨄", true), "bigsqcup": ("⨆", true),
        "int": ("∫", false), "iint": ("∬", false), "iiint": ("∭", false), "iiiint": ("⨌", false),
        "oint": ("∮", false), "oiint": ("∯", false), "oiiint": ("∰", false),
        "intop": ("∫", true), "smallint": ("∫", false),
    ]

    /// 直立函数名（不带极限位置）
    static let functions: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "arccot",
        "sinh", "cosh", "tanh", "coth", "sech", "csch", "ln", "lg", "log", "exp", "deg",
        "dim", "hom", "ker", "arg", "sgn", "Tr", "tr", "rank", "erf",
    ]

    /// 直立函数名（display 模式下上下标放正下方）
    static let limitFunctions: [String: String] = [
        "lim": "lim", "liminf": "lim inf", "limsup": "lim sup", "max": "max", "min": "min",
        "sup": "sup", "inf": "inf", "det": "det", "Pr": "Pr", "gcd": "gcd", "lcm": "lcm",
        "argmax": "arg max", "argmin": "arg min", "injlim": "inj lim", "projlim": "proj lim",
    ]

    /// 重音：符号、是否可伸展、是否在下方、是否按 accent 处理
    struct Accent { let char: String; let stretchy: Bool; let under: Bool; let isAccent: Bool }

    static let accents: [String: Accent] = [
        "hat": Accent(char: "ˆ", stretchy: false, under: false, isAccent: true),
        "widehat": Accent(char: "^", stretchy: true, under: false, isAccent: true),
        "check": Accent(char: "ˇ", stretchy: false, under: false, isAccent: true),
        "widecheck": Accent(char: "ˇ", stretchy: true, under: false, isAccent: true),
        "tilde": Accent(char: "˜", stretchy: false, under: false, isAccent: true),
        "widetilde": Accent(char: "~", stretchy: true, under: false, isAccent: true),
        "acute": Accent(char: "´", stretchy: false, under: false, isAccent: true),
        "grave": Accent(char: "`", stretchy: false, under: false, isAccent: true),
        "dot": Accent(char: "˙", stretchy: false, under: false, isAccent: true),
        "ddot": Accent(char: "¨", stretchy: false, under: false, isAccent: true),
        "dddot": Accent(char: "⃛", stretchy: false, under: false, isAccent: true),
        "breve": Accent(char: "˘", stretchy: false, under: false, isAccent: true),
        "bar": Accent(char: "¯", stretchy: false, under: false, isAccent: true),
        "vec": Accent(char: "→", stretchy: false, under: false, isAccent: true),
        "mathring": Accent(char: "˚", stretchy: false, under: false, isAccent: true),
        "overrightarrow": Accent(char: "→", stretchy: true, under: false, isAccent: true),
        "overleftarrow": Accent(char: "←", stretchy: true, under: false, isAccent: true),
        "overleftrightarrow": Accent(char: "↔", stretchy: true, under: false, isAccent: true),
        "underrightarrow": Accent(char: "→", stretchy: true, under: true, isAccent: true),
        "underleftarrow": Accent(char: "←", stretchy: true, under: true, isAccent: true),
        "overbrace": Accent(char: "⏞", stretchy: true, under: false, isAccent: false),
        "underbrace": Accent(char: "⏟", stretchy: true, under: true, isAccent: false),
        "overparen": Accent(char: "⏜", stretchy: true, under: false, isAccent: false),
        "underparen": Accent(char: "⏝", stretchy: true, under: true, isAccent: false),
    ]

    /// 可伸展箭头 \xrightarrow 等
    static let extensibleArrows: [String: String] = [
        "xrightarrow": "→", "xleftarrow": "←", "xRightarrow": "⇒", "xLeftarrow": "⇐",
        "xleftrightarrow": "↔", "xLeftrightarrow": "⇔", "xmapsto": "↦",
        "xhookrightarrow": "↪", "xhookleftarrow": "↩", "xrightleftharpoons": "⇌",
        "xlongequal": "=",
    ]

    /// \not 后常见组合的预组合字符
    static let negations: [String: String] = [
        "=": "≠", "in": "∉", "equiv": "≢", "subset": "⊄", "supset": "⊅", "subseteq": "⊈",
        "supseteq": "⊉", "<": "≮", ">": "≯", "le": "≰", "leq": "≰", "ge": "≱", "geq": "≱",
        "sim": "≁", "cong": "≇", "approx": "≉", "mid": "∤", "parallel": "∦", "ni": "∌",
        "exists": "∄", "prec": "⊀", "succ": "⊁",
    ]

    /// 数学空格（em）
    static let spaces: [String: Double] = [
        ",": 0.1667, "thinspace": 0.1667, ":": 0.2222, ">": 0.2222, "medspace": 0.2222,
        ";": 0.2778, "thickspace": 0.2778, "enspace": 0.5, "quad": 1, "qquad": 2,
        " ": 0.25, "space": 0.25, "nobreakspace": 0.25,
        "!": -0.1667, "negthinspace": -0.1667, "negmedspace": -0.2222, "negthickspace": -0.2778,
    ]

    /// 被忽略的命令
    static let ignored: Set<String> = [
        "nonumber", "notag", "hline", "hdashline", "displaylimits", "allowbreak", "nobreak",
        "relax", "/", "protect", "strut", "mathstrut", "limits", "nolimits", "centering",
        "right", "end", "\\", "cr", "newline", "middle@", "displaybreak", "ensuremath",
    ]
}
