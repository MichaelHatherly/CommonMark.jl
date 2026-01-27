# [Extensions](@id extensions-page)

Extensions add syntax beyond the CommonMark specification. They must be
explicitly enabled with [`enable!`](@ref).

```@example ext
using CommonMark
nothing # hide
```

## Tables

Pipe-style tables from GitHub Flavored Markdown. Tables require a header row
and a separator row that defines column alignment.

```@example ext
parser = Parser()
enable!(parser, TableRule())

ast = parser("""
| Column One | Column Two | Column Three |
|:---------- | ---------- |:------------:|
| Row `1`    | Column `2` |              |
| *Row* 2    | **Row** 2  | Column 3     |
""")
html(ast)
```

Alignment is set with colons in the separator: `:---` left, `---:` right,
`:---:` center. Cells can contain inline formatting. Escape literal pipes
with backslashes.

## Admonitions

Callout boxes for notes, warnings, tips, and other highlighted content.
Common in technical documentation.

```@example ext
parser = Parser()
enable!(parser, AdmonitionRule())

ast = parser("""
!!! note "Custom Title"
    This is an admonition block.

!!! warning
    Title defaults to category name.
""")
html(ast)
```

The category (note, warning, tip, etc.) determines styling. An optional
quoted string overrides the title. Content must be indented by 4 spaces.

## Footnotes

Reference-style footnotes that collect at the end of the document. Useful
for citations, asides, and additional context without interrupting flow.

```@example ext
parser = Parser()
enable!(parser, FootnoteRule())

ast = parser("""
Here is a footnote reference[^1].

[^1]: This is the footnote content.
""")
html(ast)
```

Footnote identifiers can be any word or number. Definitions can appear
anywhere in the document and will be collected at the end.

## Typography

Converts ASCII punctuation to proper typographic characters. Makes documents
look more polished without requiring special input.

```@example ext
parser = Parser()
enable!(parser, TypographyRule())

ast = parser("\"Hello\" -- Pro tip... use 'single quotes' too --- or not.")
html(ast)
```

Conversions: straight quotes to curly quotes, `...` to ellipsis, `--` to
en-dash, `---` to em-dash. Disable specific conversions with keyword arguments:

```julia
enable!(parser, TypographyRule(double_quotes=false, dashes=false))
```

## Math

LaTeX math expressions for technical and scientific documents.

### Julia-style (double backticks)

Uses double backticks for inline math, matching Julia's docstring convention.
Display math uses fenced code blocks with `math` as the language.

```@example ext
parser = Parser()
enable!(parser, MathRule())

ast = parser("Inline ``E = mc^2`` math.")
html(ast)
```

Display math with fenced blocks:

````@example ext
ast = parser("""
```math
\\int_0^\\infty e^{-x^2} dx
```
""")
html(ast)
````

### Dollar-style

Traditional LaTeX syntax with single `$` for inline and double `$$` for display.
More familiar to users coming from LaTeX or other markdown flavors.

```@example ext
parser = Parser()
enable!(parser, DollarMathRule())

ast = parser("Inline \$E = mc^2\$ math.")
html(ast)
```

## Attributes

Attach IDs, classes, and arbitrary key-value pairs to elements. Useful for
styling, linking, and integrating with JavaScript.

```@example ext
parser = Parser()
enable!(parser, AttributeRule())

ast = parser("""
{#my-id .highlight}
# Heading
""")
html(ast)
```

Block attributes go above the target element. Inline attributes go after:

```@example ext
ast = parser("*text*{.important}")
html(ast)
```

CSS shorthand: `#foo` expands to `id="foo"`, `.bar` expands to `class="bar"`.

## Strikethrough

Marks deleted or outdated text. Renders as `<del>` in HTML.

```@example ext
parser = Parser()
enable!(parser, StrikethroughRule())

ast = parser("~~deleted text~~")
html(ast)
```

## Mark

Highlights important text. Renders as `<mark>` in HTML. Follows Pandoc's
`+mark` extension syntax.

```@example ext
parser = Parser()
enable!(parser, MarkRule())

ast = parser("This is ==highlighted text==.")
html(ast)
```

Uses double equals signs. Single equals are unaffected (for code examples
like `a = b`).

## Subscript

Chemical formulas, mathematical notation, and other subscripted text.

```@example ext
parser = Parser()
enable!(parser, SubscriptRule())

ast = parser("H~2~O")
html(ast)
```

Can be combined with `StrikethroughRule` since they use different tilde counts
(single vs double).

## Superscript

Exponents, ordinals, and other superscripted text.

```@example ext
parser = Parser()
enable!(parser, SuperscriptRule())

ast = parser("x^2^")
html(ast)
```

## Task Lists

Interactive checklists from GitHub Flavored Markdown. Useful for todo lists
and progress tracking.

```@example ext
parser = Parser()
enable!(parser, TaskListRule())

ast = parser("""
- [ ] Unchecked
- [x] Checked
""")
html(ast)
```

## GitHub Alerts

Styled callouts matching GitHub's markdown alerts. Similar to admonitions
but with GitHub's specific syntax and categories.

```@example ext
parser = Parser()
enable!(parser, GitHubAlertRule())

ast = parser("""
> [!NOTE]
> Useful information.

> [!WARNING]
> Important warning.
""")
html(ast)
```

Supported types: NOTE, TIP, IMPORTANT, WARNING, CAUTION.

## Fenced Divs

Generic containers from Pandoc. Wrap arbitrary content in a div with classes
and attributes. Useful for custom styling and semantic markup.

```@example ext
parser = Parser()
enable!(parser, FencedDivRule())

ast = parser("""
::: warning
This is a warning.
:::
""")
html(ast)
```

Divs can be nested by using more colons for outer fences.

## Front Matter

Structured metadata at the start of a document. Commonly used for titles,
authors, dates, and configuration in static site generators.

```@example ext
using YAML

parser = Parser()
enable!(parser, FrontMatterRule(yaml=YAML.load))

ast = parser("""
---
title: My Document
author: Jane Doe
---

Content here.
""")
frontmatter(ast)
```

The `frontmatter(ast)` function extracts metadata as a dictionary. Returns
an empty dict if no front matter is present.

Delimiters determine format: `---` for YAML, `+++` for TOML, `;;;` for JSON.
Pass the appropriate parser function for each format you want to support.

## Citations

Academic-style citations with Pandoc syntax. Requires bibliography data
in CSL-JSON format passed to the writer.

```@example ext
parser = Parser()
enable!(parser, CitationRule())

ast = parser("According to @doe2020, this is true.")

# Bibliography as CSL-JSON array
bib = [Dict(
    "id" => "doe2020",
    "author" => [Dict("family" => "Doe", "given" => "Jane")],
    "title" => "Example Article",
    "issued" => Dict("date-parts" => [[2020]])
)]
html(ast, Dict{String,Any}("references" => bib))
```

Bracketed syntax groups multiple citations: `[@doe2020; @smith2021]`.
Brackets render as parentheses in the output.

## Auto Identifiers

Automatically generates IDs for headings based on their text. Enables linking
directly to sections.

```@example ext
parser = Parser()
enable!(parser, AutoIdentifierRule())

ast = parser("# My Heading")
html(ast)
```

IDs are slugified: lowercased, spaces become hyphens, special characters removed.
Duplicate headings get numeric suffixes.

## Reference Links

Preserves reference-style link syntax in the AST instead of resolving it
during parsing. Enables accurate markdown roundtripping and detection of
undefined references.

```@example ext
parser = Parser()
enable!(parser, ReferenceLinkRule())

ast = parser("""
[full style][ref]
[collapsed style][]
[shortcut style]

[ref]: https://example.com
[collapsed style]: /url
[shortcut style]: /url
""")
markdown(ast)
```

The three reference styles are preserved:
- **Full**: `[text][label]` - explicit label
- **Collapsed**: `[text][]` - label matches text
- **Shortcut**: `[text]` - implicit label

### Detecting Undefined References

When enabled, undefined references become `UnresolvedReference` nodes instead
of literal text. This enables tools to find broken links:

```@example ext
ast = parser("[undefined link][missing]")
for (node, entering) in ast
    if entering && node.t isa CommonMark.UnresolvedReference
        ref = node.t
        println("Undefined: label='$(ref.label)', style=$(ref.style), image=$(ref.image)")
    end
end
```

## Raw Content

Pass format-specific content through unchanged. Useful for embedding LaTeX
commands, HTML widgets, or other content that shouldn't be processed.

````@example ext
parser = Parser()
enable!(parser, RawContentRule())

ast = parser("Inline: `\\textbf{bold}`{=latex}\n\n```{=latex}\n\\begin{center}\nCentered\n\\end{center}\n```")
nothing # hide
````

Raw content only appears in its target format:

```@example ext
latex(ast)
```

```@example ext
html(ast)  # LaTeX content omitted
```

The format name (`html`, `latex`, `typst`) is specified in the attribute.
The parser automatically determines inline vs block from context. Custom
formats can be added by passing type mappings to `RawContentRule`.

## String Macro

The `@cm_str` macro enables markdown string interpolation, embedding Julia
expressions directly in markdown text.

```@example ext
using CommonMark

name = "world"
ast = cm"Hello *$(name)*!"
html(ast)
```

Expressions are captured during parsing and evaluated at runtime when the
code executes. This is useful for generating markdown programmatically
without manually constructing nodes.

### Default Syntax Rules

The macro enables several extensions by default, matching Julia's `@md_str`:

- `AdmonitionRule`
- `AttributeRule`
- `AutoIdentifierRule`
- `CitationRule`
- `FootnoteRule`
- `MathRule`
- `RawContentRule`
- `TableRule`
- `TypographyRule`

!!! warning "DollarMathRule Conflict"
    `DollarMathRule` is NOT enabled because `$` is used for interpolation.
    Use double backticks (``` ``E=mc^2`` ```) or `math` code blocks instead.

### Custom Parser

Suffix the macro with a function name to use a custom parser:

```@example ext
# Define a minimal parser (no extensions)
minimal() = Parser()

text = "plain"
ast = cm"Just $(text) markdown."minimal
html(ast)
```

The suffix `none` invokes a basic parser with no extensions:

```@example ext
ast = cm"No **extensions** here."none
html(ast)
```

## Docstring Parser

!!! warning "Experimental"
    This feature is experimental and subject to change without notice.

Render module docstrings with CommonMark formatting instead of Julia's
default markdown parser.

```julia
module MyPackage

# ... docstrings ...

using CommonMark
CommonMark.@docstring_parser
end
```

Call at module top-level after all docstrings are defined. Pass a custom
parser to enable extensions:

```julia
CommonMark.@docstring_parser Parser(enable=[AdmonitionRule(), TableRule(), MathRule()])
```
