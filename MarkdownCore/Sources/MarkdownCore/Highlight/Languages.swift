// 各语言的词法定义

struct LanguageSpec {
    var keywords: Set<String> = []
    var types: Set<String> = []
    var literals: Set<String> = []
    var builtins: Set<String> = []
    var lineComments: [String] = []
    var blockComments: [(String, String)] = []
    var stringQuotes: [UInt8] = [UInt8(ascii: "\""), UInt8(ascii: "'")]
    /// 可以跨行的字符串引号（如 JS 模板字符串、shell 字符串）
    var multilineQuotes: [UInt8] = []
    var tripleQuotes = false
    var caseInsensitive = false
    /// C 系预处理指令：行首 #
    var preprocessor = false
    /// @注解 / 装饰器 / Swift 属性
    var annotations = false
    /// $var（shell、PHP、Perl）
    var dollarVariables = false
    /// 标识符可以包含的额外字符
    var identifierExtra: [UInt8] = []
    /// 首字母大写的标识符视为类型
    var capitalizedTypes = false
}

private func words(_ s: String) -> Set<String> {
    Set(s.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))
}

enum Languages {
    enum Kind {
        case generic(LanguageSpec)
        case markup
        case css
        case json
        case yaml
        case diff
        case ini
    }

    static func lookup(_ name: String) -> Kind? {
        let key = name.lowercased()
        if let id = aliases[key] { return table[id] }
        return table[key]
    }

    private static let aliases: [String: String] = [
        "c++": "cpp", "cc": "cpp", "cxx": "cpp", "hpp": "cpp", "hxx": "cpp", "h++": "cpp", "h": "c",
        "objective-c": "objc", "objectivec": "objc", "m": "objc", "mm": "objc", "objective-c++": "objc",
        "kt": "kotlin", "kts": "kotlin", "cs": "csharp", "c#": "csharp", "golang": "go", "rs": "rust",
        "py": "python", "python3": "python", "py3": "python", "gyp": "python", "rb": "ruby",
        "js": "javascript", "jsx": "javascript", "mjs": "javascript", "cjs": "javascript", "node": "javascript",
        "ts": "typescript", "tsx": "typescript", "mts": "typescript",
        "sh": "bash", "shell": "bash", "zsh": "bash", "console": "bash", "shellsession": "bash", "fish": "bash",
        "ps1": "powershell", "ps": "powershell", "pwsh": "powershell",
        "pl": "perl", "pm": "perl", "make": "makefile", "mk": "makefile", "docker": "dockerfile",
        "mysql": "sql", "postgres": "sql", "postgresql": "sql", "sqlite": "sql", "plsql": "sql", "tsql": "sql",
        "hs": "haskell", "ex": "elixir", "exs": "elixir", "jl": "julia", "gradle": "groovy",
        "proto": "protobuf", "gql": "graphql", "tex": "latex", "vb": "vbnet", "fs": "fsharp",
        "html": "markup", "xml": "markup", "xhtml": "markup", "svg": "markup", "plist": "markup",
        "vue": "markup", "svelte": "markup", "xaml": "markup", "xsl": "markup", "rss": "markup", "atom": "markup",
        "htm": "markup", "storyboard": "markup",
        "scss": "css", "sass": "css", "less": "css", "stylus": "css",
        "json5": "json", "jsonc": "json", "geojson": "json", "ipynb": "json",
        "yml": "yaml", "patch": "diff", "udiff": "diff",
        "toml": "ini", "conf": "ini", "cfg": "ini", "properties": "ini", "editorconfig": "ini", "gitconfig": "ini",
        "env": "ini", "dotenv": "ini",
    ]

    // 共享的关键字集合
    private static let cKeywords = "auto break case const continue default do else enum extern for goto if inline register restrict return sizeof static struct switch typedef union volatile while _Alignas _Alignof _Atomic _Bool _Complex _Generic _Noreturn _Static_assert _Thread_local"
    private static let cTypes = "char double float int long short signed unsigned void bool size_t ssize_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t intptr_t uintptr_t ptrdiff_t FILE wchar_t"
    private static let jsKeywords = "async await break case catch class const continue debugger default delete do else export extends finally for from function get if import in instanceof let new of return set static super switch this throw try typeof var void while with yield as"
    private static let jsBuiltins = "console window document globalThis Math JSON Promise Object Array String Number Boolean Symbol Map Set WeakMap WeakSet Date RegExp Error require module exports process Buffer parseInt parseFloat setTimeout setInterval clearTimeout fetch"

    private static let table: [String: Kind] = {
        var t: [String: Kind] = [:]

        t["swift"] = .generic(LanguageSpec(
            keywords: words("associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private precedencegroup protocol public rethrows static struct subscript typealias var break case catch continue default defer do else fallthrough for guard if in repeat return throw throws switch where while as is try await async actor some any nonisolated isolated mutating nonmutating override final required convenience lazy weak unowned dynamic indirect optional get set willSet didSet consume borrowing consuming macro package sending"),
            types: words("Int Int8 Int16 Int32 Int64 UInt UInt8 UInt16 UInt32 UInt64 Double Float CGFloat Bool String Character Array Dictionary Set Optional Any AnyObject Void Never Result Error Self Data URL Date"),
            literals: words("true false nil self super"),
            lineComments: ["//"], blockComments: [("/*", "*/")],
            stringQuotes: [UInt8(ascii: "\"")], tripleQuotes: true, preprocessor: true, annotations: true,
            capitalizedTypes: true))

        let c = LanguageSpec(
            keywords: words(cKeywords), types: words(cTypes), literals: words("NULL true false"),
            builtins: words("printf scanf malloc calloc realloc free memcpy memset strlen strcpy strcmp fopen fclose exit"),
            lineComments: ["//"], blockComments: [("/*", "*/")], preprocessor: true)
        t["c"] = .generic(c)

        var cpp = c
        cpp.keywords.formUnion(words("alignas alignof and asm catch class concept consteval constexpr constinit const_cast co_await co_return co_yield decltype delete dynamic_cast explicit export friend mutable namespace new noexcept not operator or override final private protected public reinterpret_cast requires static_assert static_cast template this thread_local throw try typeid typename using virtual xor"))
        cpp.types.formUnion(words("string vector map unordered_map set unordered_set pair tuple shared_ptr unique_ptr weak_ptr optional variant array deque list queue stack span string_view"))
        cpp.literals.formUnion(words("nullptr"))
        cpp.builtins.formUnion(words("std cout cin cerr endl move forward make_shared make_unique"))
        t["cpp"] = .generic(cpp)

        var objc = c
        objc.keywords.formUnion(words("@interface @implementation @end @protocol @property @synthesize @dynamic @class @selector @encode @autoreleasepool @try @catch @finally @throw @optional @required @import self super in out inout oneway bycopy byref nonatomic atomic strong weak copy assign retain readonly readwrite nullable nonnull instancetype"))
        objc.types.formUnion(words("id BOOL SEL IMP Class NSInteger NSUInteger CGFloat NSString NSArray NSDictionary NSObject NSNumber"))
        objc.literals.formUnion(words("YES NO nil Nil"))
        objc.identifierExtra = [UInt8(ascii: "@")]
        objc.capitalizedTypes = true
        t["objc"] = .generic(objc)

        t["java"] = .generic(LanguageSpec(
            keywords: words("abstract assert break case catch class const continue default do else enum extends final finally for goto if implements import instanceof interface native new package private protected public return static strictfp super switch synchronized this throw throws transient try volatile while var record sealed permits yield non-sealed"),
            types: words("boolean byte char double float int long short void String Integer Long Double Float Boolean Object List Map Set ArrayList HashMap"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["kotlin"] = .generic(LanguageSpec(
            keywords: words("as break class continue do else for fun if in interface is object package return super this throw try typealias typeof val var when while by catch constructor delegate dynamic field file finally get import init param property receiver set setparam where actual abstract annotation companion const crossinline data enum expect external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg value"),
            types: words("Int Long Short Byte Double Float Boolean Char String Unit Any Nothing List MutableList Map Set Array"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["scala"] = .generic(LanguageSpec(
            keywords: words("abstract case catch class def do else extends final finally for forSome if implicit import lazy match new object override package private protected return sealed super this throw trait try type val var while with yield given using enum then export"),
            types: words("Int Long Double Float Boolean Char String Unit Any AnyRef Nothing Option Some None List Map Seq"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["csharp"] = .generic(LanguageSpec(
            keywords: words("abstract as base break case catch checked class const continue default delegate do else enum event explicit extern finally fixed for foreach goto if implicit in interface internal is lock namespace new operator out override params private protected public readonly ref return sealed sizeof stackalloc static struct switch this throw try typeof unchecked unsafe using virtual volatile while async await var dynamic yield get set init record when where nameof global partial"),
            types: words("bool byte char decimal double float int long object sbyte short string uint ulong ushort void String Task List Dictionary"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], preprocessor: true, capitalizedTypes: true))

        t["go"] = .generic(LanguageSpec(
            keywords: words("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var"),
            types: words("bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr any"),
            literals: words("true false nil iota"),
            builtins: words("append cap close complex copy delete imag len make new panic print println real recover min max clear"),
            lineComments: ["//"], blockComments: [("/*", "*/")],
            stringQuotes: [UInt8(ascii: "\""), UInt8(ascii: "'")], multilineQuotes: [UInt8(ascii: "`")]))

        t["rust"] = .generic(LanguageSpec(
            keywords: words("as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return static struct super trait type union unsafe use where while macro_rules"),
            types: words("bool char f32 f64 i8 i16 i32 i64 i128 isize str u8 u16 u32 u64 u128 usize String Vec Option Result Box Rc Arc HashMap HashSet Self"),
            literals: words("true false self Some None Ok Err"),
            lineComments: ["//"], blockComments: [("/*", "*/")],
            stringQuotes: [UInt8(ascii: "\"")], annotations: false, capitalizedTypes: true))

        t["python"] = .generic(LanguageSpec(
            keywords: words("and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case type"),
            types: words("int float str bool list dict set tuple bytes object complex frozenset bytearray"),
            literals: words("True False None self cls"),
            builtins: words("print len range enumerate zip map filter sorted reversed open input isinstance issubclass super getattr setattr hasattr type id abs min max sum any all iter next repr format round"),
            lineComments: ["#"], tripleQuotes: true, annotations: true))

        t["ruby"] = .generic(LanguageSpec(
            keywords: words("alias and begin break case class def defined? do else elsif end ensure for if in module next not or redo rescue retry return self super then undef unless until when while yield require require_relative include extend attr_accessor attr_reader attr_writer private protected public lambda proc puts"),
            literals: words("true false nil"),
            lineComments: ["#"], blockComments: [("=begin", "=end")], dollarVariables: true,
            identifierExtra: [UInt8(ascii: "?"), UInt8(ascii: "!")], capitalizedTypes: true))

        t["php"] = .generic(LanguageSpec(
            keywords: words("abstract and array as break callable case catch class clone const continue declare default do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once return static switch throw trait try unset use var while xor yield enum"),
            types: words("int float string bool array object mixed void iterable never self parent"),
            literals: words("true false null TRUE FALSE NULL"),
            lineComments: ["//", "#"], blockComments: [("/*", "*/")], dollarVariables: true, capitalizedTypes: true))

        let js = LanguageSpec(
            keywords: words(jsKeywords), literals: words("true false null undefined NaN Infinity"),
            builtins: words(jsBuiltins),
            lineComments: ["//"], blockComments: [("/*", "*/")],
            multilineQuotes: [UInt8(ascii: "`")], annotations: true,
            identifierExtra: [UInt8(ascii: "$")], capitalizedTypes: true)
        t["javascript"] = .generic(js)

        var ts = js
        ts.keywords.formUnion(words("abstract declare enum implements interface keyof namespace private protected public readonly type infer is asserts satisfies override module unique"))
        ts.types = words("string number boolean any unknown never void object symbol bigint Record Partial Readonly Pick Omit Array Promise")
        t["typescript"] = .generic(ts)

        t["dart"] = .generic(LanguageSpec(
            keywords: words("abstract as assert async await base break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory final finally for get hide if implements import in interface is late library mixin new on operator part required rethrow return sealed set show static super switch sync this throw try typedef var void when while with yield"),
            types: words("int double num String bool List Map Set Future Stream Object dynamic Iterable"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["lua"] = .generic(LanguageSpec(
            keywords: words("and break do else elseif end for function goto if in local not or repeat return then until while"),
            literals: words("true false nil self"),
            builtins: words("print pairs ipairs require type tostring tonumber setmetatable getmetatable pcall error assert table string math io os"),
            lineComments: ["--"], blockComments: [("--[[", "]]")]))

        t["perl"] = .generic(LanguageSpec(
            keywords: words("my our local sub if elsif else unless while until for foreach do last next redo return use no package require and or not eq ne lt gt le ge cmp print say die"),
            lineComments: ["#"], dollarVariables: true))

        t["r"] = .generic(LanguageSpec(
            keywords: words("if else repeat while function for in next break return library require"),
            literals: words("TRUE FALSE NULL NA NaN Inf T F"),
            lineComments: ["#"]))

        t["sql"] = .generic(LanguageSpec(
            keywords: words("select from where insert into values update set delete create alter drop table view index database schema primary key foreign references unique not null default and or in is like between exists join inner left right full outer cross on as group by order having limit offset union all distinct case when then else end begin commit rollback transaction grant revoke with returning asc desc if replace trigger procedure function returns declare cast constraint check over partition window"),
            types: words("int integer bigint smallint tinyint decimal numeric float real double varchar char text date time timestamp datetime boolean blob json jsonb uuid serial"),
            literals: words("true false null"),
            builtins: words("count sum avg min max coalesce now concat substring length lower upper round"),
            lineComments: ["--", "#"], blockComments: [("/*", "*/")], caseInsensitive: true))

        t["bash"] = .generic(LanguageSpec(
            keywords: words("if then else elif fi case esac for select while until do done in function time coproc return exit break continue export local readonly declare unset shift source alias set trap eval exec"),
            literals: words("true false"),
            builtins: words("echo printf cd pwd ls cat grep sed awk find xargs mkdir rm cp mv chmod chown curl wget git sudo brew npm make test read"),
            lineComments: ["#"], multilineQuotes: [UInt8(ascii: "\""), UInt8(ascii: "'"), UInt8(ascii: "`")],
            dollarVariables: true, identifierExtra: [UInt8(ascii: "-")]))

        t["powershell"] = .generic(LanguageSpec(
            keywords: words("begin break catch class continue data define do dynamicparam else elseif end exit filter finally for foreach from function if in param process return switch throw trap try until using var while"),
            literals: words("$true $false $null"),
            lineComments: ["#"], blockComments: [("<#", "#>")], caseInsensitive: true, dollarVariables: true,
            identifierExtra: [UInt8(ascii: "-")]))

        t["makefile"] = .generic(LanguageSpec(
            keywords: words("ifeq ifneq ifdef ifndef else endif include define endef export override .PHONY"),
            lineComments: ["#"], dollarVariables: true))

        t["dockerfile"] = .generic(LanguageSpec(
            keywords: words("FROM RUN CMD LABEL MAINTAINER EXPOSE ENV ADD COPY ENTRYPOINT VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL HEALTHCHECK SHELL AS"),
            lineComments: ["#"], caseInsensitive: true, dollarVariables: true))

        t["haskell"] = .generic(LanguageSpec(
            keywords: words("case class data default deriving do else foreign if import in infix infixl infixr instance let module newtype of then type where qualified as hiding"),
            literals: words("True False Nothing Just"),
            lineComments: ["--"], blockComments: [("{-", "-}")], stringQuotes: [UInt8(ascii: "\"")],
            identifierExtra: [UInt8(ascii: "'")], capitalizedTypes: true))

        t["elixir"] = .generic(LanguageSpec(
            keywords: words("def defp defmodule defstruct defmacro defprotocol defimpl do end fn if else unless case cond with for try rescue catch after raise receive when and or not in import alias require use quote unquote"),
            literals: words("true false nil"),
            lineComments: ["#"], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["julia"] = .generic(LanguageSpec(
            keywords: words("function end if elseif else for while return break continue module using import export struct mutable abstract type begin let local global const do try catch finally macro quote in"),
            literals: words("true false nothing missing"),
            lineComments: ["#"], blockComments: [("#=", "=#")], tripleQuotes: true, annotations: true))

        t["zig"] = .generic(LanguageSpec(
            keywords: words("const var fn pub return if else while for switch break continue defer errdefer try catch orelse struct enum union error comptime inline export extern test usingnamespace async await suspend resume and or"),
            types: words("i8 i16 i32 i64 u8 u16 u32 u64 usize isize f32 f64 bool void anyerror anytype type noreturn"),
            literals: words("true false null undefined"),
            lineComments: ["//"], annotations: true))

        t["groovy"] = .generic(LanguageSpec(
            keywords: words("def class interface enum extends implements import package return if else for while do switch case default break continue try catch finally throw new in as trait static final public private protected"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("/*", "*/")], tripleQuotes: true, annotations: true, capitalizedTypes: true))

        t["protobuf"] = .generic(LanguageSpec(
            keywords: words("syntax package import option message enum service rpc returns repeated optional required oneof map reserved extend stream"),
            types: words("double float int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64 bool string bytes"),
            literals: words("true false"),
            lineComments: ["//"], blockComments: [("/*", "*/")], capitalizedTypes: true))

        t["graphql"] = .generic(LanguageSpec(
            keywords: words("query mutation subscription fragment on type interface union enum input scalar schema extend implements directive"),
            types: words("Int Float String Boolean ID"),
            literals: words("true false null"),
            lineComments: ["#"], dollarVariables: true, capitalizedTypes: true))

        t["latex"] = .generic(LanguageSpec(
            lineComments: ["%"], stringQuotes: [], identifierExtra: []))

        t["cmake"] = .generic(LanguageSpec(
            keywords: words("if else elseif endif foreach endforeach while endwhile function endfunction macro endmacro set unset project cmake_minimum_required add_executable add_library target_link_libraries include_directories find_package option message install"),
            lineComments: ["#"], caseInsensitive: true, dollarVariables: true))

        t["vbnet"] = .generic(LanguageSpec(
            keywords: words("dim as if then else elseif end sub function return for next each in while do loop select case class module public private protected new imports namespace"),
            literals: words("true false nothing"),
            lineComments: ["'"], stringQuotes: [UInt8(ascii: "\"")], caseInsensitive: true))

        t["fsharp"] = .generic(LanguageSpec(
            keywords: words("let rec in fun function match with if then else elif type module open namespace member static mutable do done for to while yield return async seq"),
            literals: words("true false null"),
            lineComments: ["//"], blockComments: [("(*", "*)")], tripleQuotes: true))

        t["markup"] = .markup
        t["css"] = .css
        t["json"] = .json
        t["yaml"] = .yaml
        t["diff"] = .diff
        t["ini"] = .ini
        return t
    }()
}
