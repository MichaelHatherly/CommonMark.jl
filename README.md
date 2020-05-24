# CommonMark

*A [CommonMark](https://spec.commonmark.org/current/)-compliant parser for Julia.*

[![Build Status](https://travis-ci.org/MichaelHatherly/CommonMark.jl.svg?branch=master)](https://travis-ci.org/MichaelHatherly/CommonMark.jl)
[![Codecov](https://codecov.io/gh/MichaelHatherly/CommonMark.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/MichaelHatherly/CommonMark.jl)

## Interface

```julia
using CommonMark
```

Create a markdown parser with the default CommonMark settings and then add
footnote syntax to our parser.

```julia
markdown = Parser()
enable!(markdown, FootnoteRule())
```

Parse some text to an abstract syntax tree.

```julia
ast = markdown("Hello *world*")
```

Write `ast` to a string.

```julia
body = html(ast)
content = "<head></head><body>$body</body>"
```

Write to a file.

```julia
open("file.tex", "w") do file
    latex(file, ast)
    println(file, "rest of document...")
end
```

Or write to a buffer, such as `stdout`.

```julia
term(stdout, ast)
```

## Extensions

Extensions can be enabled using the `enable!` function and disabled using `disable!`.

### Admonitions

```julia
enable!(parser, AdmonitionRule())
```

### Front matter

Fenced blocks at the start of a file containing structured data.

```
+++
[heading]
content = "..."
+++

The rest of the file...
```

The block **must** start on the first line of the file. Supported blocks are:

  - `;;;` for JSON
  - `+++` for TOML
  - `---` for YAML

To enable provide the `FrontMatterRule` with your choice of parsers for the formats:

```julia
using JSON
enable!(parser, FrontMatterRule(json=JSON.Parser.parse))
```

### Footnotes

```julia
enable!(parser, FootnoteRule())
```

### Math

Julia-style inline and display maths:

````markdown
Some ``\LaTeX`` math:

```math
f(a) = \frac{1}{2\pi}\int_{0}^{2\pi} (\alpha+R\cos(\theta))d\theta
```
````

Enabled with:

```julia
enable!(parser, MathRule())
```

### Tables

Pipe-style tables, similar to GitHub's using `|`. **Strict alignment** required for pipes.

```markdown
| Column One | Column Two | Column Three |
|:---------- | ---------- |:------------:|
| Row `1`    | Column `2` |              |
| *Row* 2    | **Row** 2  | Column ``3`` |
```

Enabled with:

```julia
enable!(parser, TableRule())
```

### CommonMark Defaults

Block rules enabled by default in `Parser` objects:

  - `AtxHeadingRule()`
  - `BlockQuoteRule()`
  - `FencedCodeBlockRule()`
  - `HtmlBlockRule()`
  - `IndentedCodeBlockRule()`
  - `ListItemRule()`
  - `SetextHeadingRule()`
  - `ThematicBreakRule()`

Inline rules enabled by default in `Parser` objects:

  - `AsteriskEmphasisRule()`
  - `AutolinkRule()`
  - `BackslashEscapeRule()`
  - `DoubleQuoteRule()`
  - `HtmlEntityRule()`
  - `HtmlInlineRule()`
  - `ImageRule()`
  - `InlineCodeRule()`
  - `LinkRule()`
  - `NewlineRule()`
  - `SingleQuoteRule()`
  - `TextRule()`
  - `UnderscoreEmphasisRule()`

These can all be disabled using `disable!`. Note that disabling some parser
rules may result in unexpected results. It is recommended to be conservative in
what is disabled.

**Note**

Until version `1.0.0` the rules listed above are subject to change and should
be considered unstable regardless of whether they are exported or not.
