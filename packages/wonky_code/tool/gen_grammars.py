"""Generates the grammars rewritten by patch SH-3 (see THIRD_PARTY.md).

After regenerating, embed the grammars as Dart strings:
`dart run tool/embed_grammars.dart`.

Usage (from the package root): python3 tool/gen_grammars.py grammars
"""
import json
import sys

out = sys.argv[1]


def words(*ws):
    return r"\b(?:" + "|".join(ws) + r")\b"


def esc_rule(lang):
    return {"name": f"constant.character.escape.{lang}", "match": r"\\(?:u\{[0-9A-Fa-f]+\}|u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|.)"}


def common_tail(lang, *, types_extra=()):
    """Rules every C-like grammar ends with: numbers, types, calls, operators."""
    return [
        {"name": f"constant.numeric.{lang}", "match": r"\b(?:0[xX][0-9A-Fa-f_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)[a-zA-Z0-9_]*\b"},
        {"name": f"support.class.{lang}", "match": r"\b[A-Z][A-Za-z0-9_]*\b"},
        {"name": f"entity.name.function.{lang}", "match": r"\b[a-z_][A-Za-z0-9_]*(?=\s*\()"},
        {"name": f"keyword.operator.{lang}", "match": r"[-+*/%=!<>&|^~?:]+"},
    ]


def grammar(name, scope, file_types, patterns, repository):
    # The parser has no `$self`: the top level lives in `#main` so embedded
    # expressions (interpolation) can include it.
    repository = {"main": {"patterns": patterns}, **repository}
    patterns = [{"include": "#main"}]
    return {
        "name": name,
        "version": "1.0.0",
        "fileTypes": file_types,
        "scopeName": scope,
        "patterns": patterns,
        "repository": repository,
    }


def write(file, g):
    with open(f"{out}/{file}.json", "w") as f:
        json.dump(g, f, indent=2)
        f.write("\n")


# ---------------------------------------------------------------- Swift
swift_strings = [
    {"name": "string.quoted.triple.swift", "begin": '"""', "end": '"""', "patterns": [{"include": "#interpolation"}, esc_rule("swift")]},
    {"name": "string.quoted.double.swift", "begin": '"', "end": r'"|$', "patterns": [{"include": "#interpolation"}, esc_rule("swift")]},
]
write("swift", grammar("Swift", "source.swift", ["swift"], [
    {"include": "#comments"},
    {"include": "#strings"},
    {"name": "storage.type.annotation.swift", "match": r"@[A-Za-z_][A-Za-z0-9_]*"},
    {"name": "meta.preprocessor.swift", "match": r"#(?:if|elseif|else|endif|available|selector|keyPath|file|line|function)\b"},
    {"name": "keyword.control.swift", "match": words("if", "else", "for", "in", "while", "repeat", "switch", "case", "default", "break", "continue", "fallthrough", "return", "throw", "throws", "rethrows", "defer", "guard", "do", "catch", "try", "async", "await", "where")},
    {"match": r"\b(class|struct|enum|protocol|extension|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.swift"}, "2": {"name": "entity.name.type.swift"}}},
    {"match": r"\b(func)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.swift"}, "2": {"name": "entity.name.function.swift"}}},
    {"name": "storage.type.swift", "match": words("import", "class", "struct", "enum", "protocol", "extension", "actor", "func", "var", "let", "typealias", "init", "deinit", "subscript", "associatedtype", "operator")},
    {"name": "storage.modifier.swift", "match": words("public", "private", "internal", "fileprivate", "open", "static", "mutating", "nonmutating", "override", "final", "required", "convenience", "lazy", "weak", "unowned", "dynamic", "optional", "indirect", "inout", "some", "any")},
    {"name": "constant.language.swift", "match": words("true", "false", "nil")},
    {"name": "variable.language.swift", "match": words("self", "Self", "super")},
    *common_tail("swift"),
], {
    "comments": {"patterns": [
        {"name": "comment.block.swift", "begin": r"/\*", "end": r"\*/"},
        {"name": "comment.line.double-slash.swift", "match": r"//.*$"},
    ]},
    "strings": {"patterns": swift_strings},
    "interpolation": {"patterns": [
        {"name": "meta.embedded.swift", "begin": r"\\\(", "end": r"\)", "beginCaptures": {"0": {"name": "punctuation.definition.template-expression.begin.ts"}}, "endCaptures": {"0": {"name": "punctuation.definition.template-expression.end.ts"}}, "patterns": [{"include": "#main"}]},
    ]},
}))

# ----------------------------------------------------------- TypeScript
def js_like(lang, name, scope, file_types, *, typescript):
    declaration_words = ["var", "let", "const", "function", "class", "extends", "implements", "new", "import", "export", "from", "as", "default", "get", "set", "static", "async"]
    if typescript:
        declaration_words += ["interface", "type", "enum", "namespace", "module", "declare", "abstract", "readonly", "public", "private", "protected", "keyof", "infer", "is", "satisfies"]
    patterns = [
        {"name": f"meta.preprocessor.script.{lang}", "match": r"^(#!.*)$"},
        {"include": "#comments"},
        {"include": "#strings"},
        # A `/` after an operator, bracket, comma or at line start begins a
        # regex literal, otherwise it is division.
        {"name": f"string.regexp.{lang}", "match": r"(?<=(?:^|[=(,:;!&|?{}\[]|return|typeof)\s*)/(?![/*])(?:\\.|\[(?:\\.|[^\]\\\n])*\]|[^/\\\n\[])+/[dgimsuyv]*"},
        {"name": f"keyword.control.{lang}", "match": words("if", "else", "for", "of", "in", "while", "do", "switch", "case", "default", "break", "continue", "return", "throw", "try", "catch", "finally", "yield", "await")},
        {"name": f"keyword.operator.expression.{lang}", "match": words("instanceof", "typeof", "delete", "void")},
        {"match": r"\b(class|interface|enum|type|namespace)\s+([A-Za-z_$][A-Za-z0-9_$]*)", "captures": {"1": {"name": f"storage.type.{lang}"}, "2": {"name": f"entity.name.type.{lang}"}}} if typescript else
        {"match": r"\b(class)\s+([A-Za-z_$][A-Za-z0-9_$]*)", "captures": {"1": {"name": f"storage.type.{lang}"}, "2": {"name": f"entity.name.type.{lang}"}}},
        {"match": r"\b(function)(\s*\*?\s*)([A-Za-z_$][A-Za-z0-9_$]*)", "captures": {"1": {"name": f"storage.type.{lang}"}, "3": {"name": f"entity.name.function.{lang}"}}},
        {"name": f"storage.type.{lang}", "match": words(*declaration_words)},
        {"name": f"constant.language.{lang}", "match": words("true", "false", "null", "undefined", "NaN", "Infinity")},
        {"name": f"variable.language.{lang}", "match": words("this", "super", "arguments")},
    ]
    if typescript:
        patterns.append({"name": f"support.type.primitive.{lang}", "match": words("string", "number", "boolean", "bigint", "symbol", "object", "unknown", "never", "any")})
    patterns.append({"name": f"storage.type.annotation.{lang}", "match": r"@[A-Za-z_$][A-Za-z0-9_$]*"})
    patterns += common_tail(lang)
    return grammar(name, scope, file_types, patterns, {
        "comments": {"patterns": [
            {"name": f"comment.block.{lang}", "begin": r"/\*", "end": r"\*/"},
            {"name": f"comment.line.double-slash.{lang}", "match": r"//.*$"},
        ]},
        "strings": {"patterns": [
            {"name": f"string.quoted.double.{lang}", "begin": '"', "end": r'"|$', "patterns": [esc_rule(lang)]},
            {"name": f"string.quoted.single.{lang}", "begin": "'", "end": r"'|$", "patterns": [esc_rule(lang)]},
            {"name": f"string.template.{lang}", "begin": "`", "end": "`", "patterns": [esc_rule(lang), {"include": "#template-substitution"}]},
        ]},
        "template-substitution": {"patterns": [
            {"name": f"meta.template.expression.{lang}", "begin": r"\$\{", "end": r"\}", "beginCaptures": {"0": {"name": "punctuation.definition.template-expression.begin.ts"}}, "endCaptures": {"0": {"name": "punctuation.definition.template-expression.end.ts"}}, "patterns": [{"include": "#main"}]},
        ]},
    })


write("typescript", js_like("ts", "TypeScript", "source.ts", ["ts", "tsx", "mts", "cts"], typescript=True))
write("javascript", js_like("js", "JavaScript", "source.js", ["js", "mjs", "cjs", "jsx"], typescript=False))

# --------------------------------------------------------------- Python
def py_string(quote, name, triple):
    q = quote * 3 if triple else quote
    end = q if triple else q + "|$"
    return {"name": f"string.quoted.{name}.python", "begin": r"(?i)(?:[rbu]|br|rb)?" + q, "end": end, "patterns": [esc_rule("python")]}


def py_fstring(quote, name, triple):
    q = quote * 3 if triple else quote
    end = q if triple else q + "|$"
    return {"name": f"string.interpolated.{name}.python", "begin": r"(?i)(?:f|fr|rf)" + q, "end": end, "patterns": [
        {"name": "constant.character.escape.python", "match": r"\{\{|\}\}"},
        {"name": "meta.fstring.expression.python", "begin": r"\{", "end": r"\}", "beginCaptures": {"0": {"name": "punctuation.definition.template-expression.begin.ts"}}, "endCaptures": {"0": {"name": "punctuation.definition.template-expression.end.ts"}}, "patterns": [{"include": "#main"}]},
        esc_rule("python"),
    ]}


write("python", grammar("Python", "source.python", ["py", "pyi", "pyw"], [
    {"name": "comment.line.number-sign.python", "match": r"#.*$"},
    py_fstring('"', "triple.double", True), py_fstring("'", "triple.single", True),
    py_fstring('"', "double", False), py_fstring("'", "single", False),
    py_string('"', "triple.double", True), py_string("'", "triple.single", True),
    py_string('"', "double", False), py_string("'", "single", False),
    {"name": "storage.type.annotation.python", "match": r"^[ \t]*@[A-Za-z_][A-Za-z0-9_.]*"},
    {"match": r"\b(class)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.class.python"}, "2": {"name": "entity.name.type.class.python"}}},
    {"match": r"\b(def)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.function.python"}, "2": {"name": "entity.name.function.python"}}},
    {"name": "keyword.control.python", "match": words("if", "elif", "else", "for", "while", "break", "continue", "return", "pass", "try", "except", "finally", "raise", "with", "as", "yield", "await", "async", "import", "from", "match", "case", "assert", "del", "global", "nonlocal")},
    {"name": "keyword.operator.logical.python", "match": words("and", "or", "not", "in", "is")},
    {"name": "storage.type.python", "match": words("def", "class", "lambda")},
    {"name": "constant.language.python", "match": words("True", "False", "None", "NotImplemented", "Ellipsis")},
    {"name": "variable.language.python", "match": words("self", "cls")},
    {"name": "support.function.builtin.python", "match": words("abs", "all", "any", "bool", "bytes", "callable", "chr", "dict", "dir", "enumerate", "filter", "float", "format", "frozenset", "getattr", "hasattr", "hash", "help", "hex", "id", "input", "int", "isinstance", "issubclass", "iter", "len", "list", "map", "max", "min", "next", "object", "open", "ord", "pow", "print", "range", "repr", "reversed", "round", "set", "setattr", "slice", "sorted", "str", "sum", "super", "tuple", "type", "vars", "zip")},
    *common_tail("python"),
], {}))

# ----------------------------------------------------------------- Rust
write("rust", grammar("Rust", "source.rust", ["rs"], [
    {"name": "meta.preprocessor.rust", "match": r"^(#!\[.*)$"},
    {"name": "comment.block.documentation.rust", "match": r"//[/!].*$"},
    {"name": "comment.line.double-slash.rust", "match": r"//.*$"},
    {"name": "comment.block.rust", "begin": r"/\*", "end": r"\*/"},
    {"name": "meta.attribute.rust", "begin": r"#!?\[", "end": r"\]", "patterns": [{"include": "#strings"}]},
    {"include": "#strings"},
    # Char literals before lifetimes: 'a' is a char, 'a is a lifetime.
    {"name": "string.quoted.single.char.rust", "match": r"b?'(?:\\(?:x[0-9A-Fa-f]{2}|u\{[0-9A-Fa-f]{1,6}\}|.)|[^\\'\n])'"},
    {"name": "storage.modifier.lifetime.rust", "match": r"'[A-Za-z_][A-Za-z0-9_]*\b"},
    {"name": "entity.name.function.macro.rust", "match": r"\b[A-Za-z_][A-Za-z0-9_]*!(?=\s*[(\[{])"},
    {"match": r"\b(struct|enum|trait|type|union)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.rust"}, "2": {"name": "entity.name.type.rust"}}},
    {"match": r"\b(fn)\s+([A-Za-z_][A-Za-z0-9_]*)", "captures": {"1": {"name": "storage.type.rust"}, "2": {"name": "entity.name.function.rust"}}},
    {"name": "keyword.control.rust", "match": words("if", "else", "match", "loop", "while", "for", "in", "break", "continue", "return", "yield", "await", "use", "mod", "crate", "extern", "as", "where")},
    {"name": "storage.type.rust", "match": words("let", "const", "static", "fn", "struct", "enum", "impl", "trait", "type", "union", "macro_rules")},
    {"name": "storage.modifier.rust", "match": words("pub", "mut", "ref", "move", "async", "unsafe", "dyn")},
    {"name": "constant.language.rust", "match": words("true", "false")},
    {"name": "variable.language.rust", "match": words("self", "Self", "super")},
    {"name": "support.type.primitive.rust", "match": words("i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64", "bool", "char", "str")},
    *common_tail("rust"),
], {
    "strings": {"patterns": [
        {"name": "string.quoted.raw.rust", "begin": r'b?r##"', "end": r'"##'},
        {"name": "string.quoted.raw.rust", "begin": r'b?r#"', "end": r'"#'},
        {"name": "string.quoted.raw.rust", "begin": r'b?r"', "end": r'"'},
        {"name": "string.quoted.double.rust", "begin": r'b?"', "end": '"', "patterns": [esc_rule("rust")]},
    ]},
}))
