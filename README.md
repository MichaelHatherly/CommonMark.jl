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
parser = Parser()
enable!(parser, FootnoteRule())
```

Parse some text to an abstract syntax tree.

```julia
ast = parser("Hello *world*")
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

### Output Formats

Supported output formats are currently:

- `html`
- `latex`
- `term`: colourised and Unicode-formatted for display in a terminal.
- `markdown`
- `notebook`: [Jupyter](https://jupyter.org/) notebooks.

## Extensions

Extensions can be enabled using the `enable!` function and disabled using `disable!`.

### Typography

Convert ASCII dashes, ellipses, and quotes to their Unicode equivalents.

```julia
enable!(parser, TypographyRule())
```

Keyword arguments available for `TypographyRule` are

  - `double_quotes`
  - `single_quotes`
  - `ellipses`
  - `dashes`

which all default to `true`.

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

### Raw Content

Overload literal syntax to support passing through any type of raw content.

```julia
enable!(parser, RawContentRule())
```

By default `RawContentRule` will handle inline and block content in HTML and
LaTeX formats.

````markdown
This is raw HTML: `<img src="myimage.jpg">`{=html}.

And here's an HTML block:

```{=html}
<div id="main">
 <div class="article">
```
````

````markdown
```{=latex}
\begin{tikzpicture}
\draw[gray, thick] (-1,2) -- (2,-4);
\draw[gray, thick] (-1,-1) -- (2,2);
\filldraw[black] (0,0) circle (2pt) node[anchor=west] {Intersection point};
\end{tikzpicture}
```
````

This can be used to pass through different complex content that can't be easily
handled by CommonMark natively without any loss of expressiveness.

Custom raw content handlers can also be passed through when enabling the rule.
The naming scheme is `<format>_inline` or `<format>_block`.

```julia
enable!(p, RawContentRule(rst_inline=RstInline))
```

The last example would require the definition of a custom `RstInline` struct
and associated display methods for all supported output types, namely: `html`,
`latex`, and `term`. When passing your own keywords to `RawContentRule` the
defaults are not included and must be enabled individually.

### Attributes

Block and inline nodes can be tagged with arbitrary metadata in the form of
key/value pairs using the `AttributeRule` extension.

```julia
enable!(p, AttributeRule())
```

Block attributes appear directly *above* the node that they target:

```markdown
{#my_id color="red"}
# Heading
```

This will attach the metadata `id="my_id"` and `color="red"` to `# Heading`.

Inline attributes appear directly *after* the node that they target:

```markdown
*Some styled text*{background="green"}.
```

Which will attach metadata `background="green"` to the emphasised text
`Some styled text`.

CSS-style shorthand syntax `#<name>` and `.<name>` are available to use in
place of `id="<name>"` and `class="name"`. Multiple classes may be specified
sequentially.

`AttributeRule` does not handle writing metadata to particular formats such as
HTML or LaTeX. It is up to the implementation of a particular writer format to
make use of available metadata itself.

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
  - `HtmlEntityRule()`
  - `HtmlInlineRule()`
  - `ImageRule()`
  - `InlineCodeRule()`
  - `LinkRule()`
  - `UnderscoreEmphasisRule()`

These can all be disabled using `disable!`. Note that disabling some parser
rules may result in unexpected results. It is recommended to be conservative in
what is disabled.

**Note**

Until version `1.0.0` the rules listed above are subject to change and should
be considered unstable regardless of whether they are exported or not.
