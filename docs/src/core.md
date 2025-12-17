# Core Rules

These rules are enabled by default in `Parser()` and implement the
[CommonMark specification](https://spec.commonmark.org/current/). They cover
the standard markdown syntax that most users expect.

```@example core
using CommonMark
parser = Parser()
nothing # hide
```

## Block Rules

Block rules handle document structure: headings, paragraphs, lists, code blocks,
and other elements that occupy their own lines.

### ATX Headings

Headings prefixed with `#` characters. Supports levels 1-6.

```@example core
ast = parser("# Heading 1\n## Heading 2\n### Heading 3")
html(ast)
```

### Setext Headings

Headings underlined with `=` or `-`. Only supports levels 1 and 2.

```@example core
ast = parser("Heading 1\n=========\n\nHeading 2\n---------")
html(ast)
```

### Block Quotes

Quoted text prefixed with `>`. Can be nested and contain other block elements.

```@example core
ast = parser("> This is a block quote.\n> It can span multiple lines.")
html(ast)
```

### Lists

Unordered lists use `-`, `+`, or `*` as markers:

```@example core
ast = parser("- Item one\n- Item two\n- Item three")
html(ast)
```

Ordered lists use numbers followed by `.` or `)`:

```@example core
ast = parser("1. First item\n2. Second item\n3. Third item")
html(ast)
```

Lists can be nested by indenting items, and can contain multiple paragraphs
or other block elements.

### Fenced Code Blocks

Code blocks delimited by triple backticks or tildes. An optional info string
specifies the language for syntax highlighting.

````@example core
ast = parser("""
```julia
println("Hello, World!")
```
""")
html(ast)
````

### Indented Code Blocks

Code indented by at least 4 spaces. No language info string is possible.

```@example core
ast = parser("    function hello()\n        println(\"Hello\")\n    end")
html(ast)
```

### HTML Blocks

Raw HTML that passes through unchanged. Useful for embedding content that
markdown can't express.

```@example core
ast = parser("<div class=\"custom\">\n  Raw HTML content.\n</div>")
html(ast)
```

### Thematic Breaks

Horizontal rules created with three or more `-`, `*`, or `_` characters.

```@example core
ast = parser("Above\n\n---\n\nBelow")
html(ast)
```

## Inline Rules

Inline rules handle formatting within paragraphs: emphasis, links, code spans,
and other elements that flow with text.

### Emphasis

Asterisks and underscores create emphasis. Single delimiters produce `<em>`,
double delimiters produce `<strong>`.

```@example core
ast = parser("*italic* and **bold** and ***both***")
html(ast)
```

```@example core
ast = parser("_italic_ and __bold__ and ___both___")
html(ast)
```

### Inline Code

Backticks create code spans. Use multiple backticks to include literal backticks.

```@example core
ast = parser("Use `code` for inline code.")
html(ast)
```

### Links

Inline links with the URL in parentheses, or reference links defined elsewhere.

```@example core
ast = parser("[inline link](https://example.com)")
html(ast)
```

Reference-style links separate the URL from the text, useful for keeping
paragraphs readable or reusing the same URL multiple times.

### Images

Same syntax as links but prefixed with `!`. The link text becomes alt text.

```@example core
ast = parser("![alt text](image.png)")
html(ast)
```

### Autolinks

URLs and email addresses in angle brackets become clickable links automatically.

```@example core
ast = parser("<https://example.com>")
html(ast)
```

### HTML Inline

Raw HTML tags within paragraphs pass through unchanged.

```@example core
ast = parser("This has <em>inline HTML</em> content.")
html(ast)
```

### HTML Entities

Named and numeric HTML entities are decoded.

```@example core
ast = parser("&amp; &copy; &mdash;")
html(ast)
```

## Disabling Default Rules

Use [`disable!`](@ref) to turn off rules you don't want. This is useful for
stricter parsing or when certain syntax conflicts with your content.

```@example core
p = Parser()
disable!(p, SetextHeadingRule())  # Only ATX headings
disable!(p, [HtmlBlockRule(), HtmlInlineRule()])  # No raw HTML
nothing # hide
```
