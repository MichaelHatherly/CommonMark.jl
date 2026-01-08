# CommonMark.jl

A [CommonMark](https://spec.commonmark.org/current/)-compliant parser for Julia.

## Features

- **Spec compliant**: Passes the CommonMark spec test suite
- **Multiple outputs**: HTML, LaTeX, Typst, terminal (ANSI), Jupyter notebooks
- **Markdown roundtrip**: Parse and re-emit normalized markdown
- **Modular parser**: Enable/disable individual syntax rules
- **Extensions**: Tables, footnotes, math, front matter, admonitions, and more

## Installation

```julia
using Pkg
Pkg.add("CommonMark")
```

## Quick Start

Create a parser, parse some markdown, and render it to HTML:

```@example index
using CommonMark

parser = Parser()
ast = parser("Hello *world*")
html(ast)
```

The parser returns an abstract syntax tree (AST) that can be rendered to
multiple output formats or inspected programmatically.

## Parsing

The parser is callable on strings:

```@example index
ast = parser("# Heading\n\nParagraph")
html(ast)
```

For files, use `open` with the parser:

```julia
ast = open(parser, "document.md")
```

## Output Formats

The same AST can be rendered to different formats. Each format has its own
writer function that returns a string or writes to a file/IO.

```@example index
ast = parser("# Title\n\n**Bold** and *italic*.")
nothing # hide
```

HTML for web pages:

```@example index
html(ast)
```

LaTeX for documents and papers:

```@example index
latex(ast)
```

Markdown for normalization and roundtripping:

```@example index
markdown(ast)
```

Other formats include `typst()` for Typst documents, `term()` for
terminal output with ANSI colors, `notebook()` for Jupyter notebooks,
and `json()` for Pandoc AST JSON (enables export to docx, epub, rst, etc.).
Use `json(Dict, ast)` to get the dict without JSON serialization.

All writer functions accept a filename or IO as the first argument:

```julia
html("output.html", ast)
term(stdout, ast)
```

Writers also accept an optional `env` dictionary for configuration. Front
matter from the document is merged automatically:

```julia
env = Dict{String,Any}("title" => "My Page", "lang" => "en")
html(ast, env)
```

## Transforms

Writers accept a `transform` keyword argument to intercept and modify nodes
during rendering. Use transforms for URL rewriting, syntax highlighting, or
wrapping output in templates:

```@example index
# Rewrite .md links to .html for static sites
function rewrite_links(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
    entering || return (node, entering)
    dest = replace(link.destination, ".md" => ".html")
    (CommonMark.Node(CommonMark.Link; dest, title=link.title), entering)
end
rewrite_links(mime, ::CommonMark.AbstractContainer, node, entering, writer) = (node, entering)

ast = parser("[Guide](guide.md)")
html(ast; transform = rewrite_links)
```

See the [Transforms](@ref transforms-page) page for full documentation.

## Customization

The parser is modular. Each piece of syntax (headings, lists, emphasis, etc.)
is handled by a rule that can be enabled or disabled independently.

By default, all standard CommonMark syntax is enabled. Extensions add syntax
beyond the spec:

```@example index-ext
using CommonMark

parser = Parser()
enable!(parser, TableRule())
enable!(parser, FootnoteRule())
enable!(parser, MathRule())

ast = parser("""
| A | B |
|---|---|
| 1 | 2 |
""")
html(ast)
```

Default rules can be disabled if you want stricter or simpler parsing:

```@example index-ext
parser = Parser()
disable!(parser, SetextHeadingRule())  # Only allow # headings, not underlined
nothing # hide
```

See [Core Rules](@ref) for the default syntax and [Extensions](@ref extensions-page)
for additional features like tables, math, admonitions, and a string macro for
interpolation (`cm"Hello $(name)!"`).
