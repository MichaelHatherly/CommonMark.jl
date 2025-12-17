# CommonMark.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://michaelhatherly.github.io/CommonMark.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://michaelhatherly.github.io/CommonMark.jl/dev)

*A [CommonMark](https://spec.commonmark.org/current/)-compliant parser for Julia.*

## Quick Start

```julia
using CommonMark

parser = Parser()
ast = parser("Hello *world*")
html(ast)  # "<p>Hello <em>world</em></p>\n"
```

## Output Formats

```julia
html(ast)      # HTML
latex(ast)     # LaTeX
typst(ast)     # Typst
term(ast)      # Terminal with ANSI colors
markdown(ast)  # Normalized markdown
notebook(ast)  # Jupyter notebook
```

## Extensions

Enable syntax beyond CommonMark:

```julia
enable!(parser, TableRule())
enable!(parser, FootnoteRule())
enable!(parser, MathRule())
```

Available extensions: `TableRule`, `FootnoteRule`, `MathRule`, `DollarMathRule`,
`AdmonitionRule`, `FrontMatterRule`, `AttributeRule`, `CitationRule`,
`AutoIdentifierRule`, `TypographyRule`, `StrikethroughRule`, `SubscriptRule`,
`SuperscriptRule`, `TaskListRule`, `GitHubAlertRule`, `FencedDivRule`,
`ReferenceLinkRule`, `RawContentRule`.

See the [documentation](https://michaelhatherly.github.io/CommonMark.jl/stable) for details.

## Writer Configuration

Configuration can be provided via a `Dict{String,Any}` or front matter:

```julia
html(ast, Dict("title" => "My Document"))
```

### Template Variables

- `template-engine::Function` — Mustache-compatible renderer for standalone documents
- `<format>.template.file::String` — Custom template file
- `<format>.template.string::String` — Custom template string
- `title`, `subtitle`, `authors`, `abstract`, `keywords`, `lang`, `date`
- `html.css`, `html.js`, `html.header`, `html.footer`
- `latex.documentclass`, `latex.preamble`
