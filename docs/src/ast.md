# Building ASTs

Build markdown documents programmatically using Node constructors instead of
parsing text. This is useful for:

- **Generating documents from data**: Create reports, documentation, or content
  from databases, APIs, or computation results
- **Template systems**: Build document structures that get filled with dynamic content
- **Document transformation**: Modify parsed documents or create new ones based on
  existing ASTs
- **Testing**: Create specific AST structures for unit tests

```@example ast
import CommonMark as CM
nothing # hide
```

!!! tip
    Use `import CommonMark as CM` to reduce verbosity in code that builds ASTs.

## How It Works

The AST is a tree of `Node` objects. Each node has:

- A **container type** (e.g., `Document`, `Paragraph`, `Strong`) that defines what kind of element it is
- **Children** for container nodes (blocks contain blocks or inlines; inlines contain inlines or text)
- A **literal** string for leaf nodes like `Text`, `Code`, and `CodeBlock`
- Optional **metadata** for attributes, IDs, and classes

Nodes are created with `Node(Type, children...)` where strings automatically
become `Text` nodes:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Heading, 1, "Hello World"),
    CM.Node(CM.Paragraph, "Welcome to ", CM.Node(CM.Strong, "CommonMark"), "!")
)
CM.html(doc)
```

The constructed AST can be rendered to any output format: `html()`, `latex()`,
`markdown()`, `term()`, `typst()`, or `json()`.

## Block Containers

Block elements form the document structure: paragraphs, headings, lists, etc.
They occupy their own vertical space in the rendered output.

### Document

The root container. Every AST must have a `Document` as its root node. It can
contain any block elements except list items.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph, "First paragraph."),
    CM.Node(CM.Paragraph, "Second paragraph.")
)
CM.html(doc)
```

### Paragraph

The basic text container. Paragraphs hold inline content: text, emphasis, links,
code spans, etc. Most text content lives inside paragraphs.

```@example ast
p = CM.Node(CM.Paragraph,
    "Plain text, ",
    CM.Node(CM.Emph, "italic"),
    ", and ",
    CM.Node(CM.Strong, "bold"),
    "."
)
doc = CM.Node(CM.Document, p)
CM.html(doc)
```

### Heading

Section headings with levels 1-6. The first argument is the level (1 = h1,
2 = h2, etc.), followed by the heading content.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Heading, 1, "Main Title"),
    CM.Node(CM.Paragraph, "Introduction paragraph."),
    CM.Node(CM.Heading, 2, "First Section"),
    CM.Node(CM.Paragraph, "Section content."),
    CM.Node(CM.Heading, 3, "Subsection")
)
CM.html(doc)
```

Headings can contain inline formatting:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Heading, 2, "The ", CM.Node(CM.Code, "Node"), " API")
)
CM.html(doc)
```

### BlockQuote

Quoted content, typically rendered with indentation or a vertical bar. Block
quotes can contain any block elements including nested quotes.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.BlockQuote,
        CM.Node(CM.Paragraph, "To be or not to be."),
        CM.Node(CM.Paragraph, "— Shakespeare")
    )
)
CM.html(doc)
```

Nested block quotes:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.BlockQuote,
        CM.Node(CM.Paragraph, "Outer quote"),
        CM.Node(CM.BlockQuote,
            CM.Node(CM.Paragraph, "Inner quote")
        )
    )
)
CM.html(doc)
```

### List and Item

Lists contain `Item` nodes. By default, lists are unordered (bullet points).
Use keyword arguments to customize:

| Keyword | Type | Default | Description |
|---------|------|---------|-------------|
| `ordered` | `Bool` | `false` | Numbered list instead of bullets |
| `start` | `Int` | `1` | Starting number for ordered lists |
| `tight` | `Bool` | `true` | Tight spacing (no `<p>` tags around items) |

Unordered list:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.List,
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "First item")),
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "Second item")),
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "Third item"))
    )
)
CM.html(doc)
```

Ordered list starting at 5:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.List,
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "Fifth")),
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "Sixth"));
        ordered=true, start=5
    )
)
CM.html(doc)
```

Nested lists:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.List,
        CM.Node(CM.Item,
            CM.Node(CM.Paragraph, "Outer item"),
            CM.Node(CM.List,
                CM.Node(CM.Item, CM.Node(CM.Paragraph, "Nested item 1")),
                CM.Node(CM.Item, CM.Node(CM.Paragraph, "Nested item 2"))
            )
        )
    )
)
CM.html(doc)
```

### CodeBlock

Fenced code blocks for displaying source code. The `info` keyword specifies the
language for syntax highlighting.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.CodeBlock, "function greet(name)\n    println(\"Hello, \$name!\")\nend"; info="julia")
)
CM.html(doc)
```

Without a language:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.CodeBlock, "Plain text code block\nNo syntax highlighting")
)
CM.html(doc)
```

### ThematicBreak

A horizontal rule that separates sections. Takes no children or arguments.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph, "Content above the break."),
    CM.Node(CM.ThematicBreak),
    CM.Node(CM.Paragraph, "Content below the break.")
)
CM.html(doc)
```

### HtmlBlock

Raw HTML that passes through unchanged. Use for content that can't be expressed
in markdown, like complex layouts or embedded widgets.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.HtmlBlock, "<div class=\"warning\">\n  <strong>Warning:</strong> Custom HTML content.\n</div>")
)
CM.html(doc)
```

## Inline Containers

Inline elements flow within text: emphasis, links, code spans, etc. They don't
create line breaks by themselves.

### Emph and Strong

Emphasis (`<em>`, typically italic) and strong emphasis (`<strong>`, typically
bold). Both are containers that can hold other inline content.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "This is ",
        CM.Node(CM.Emph, "emphasized"),
        " and this is ",
        CM.Node(CM.Strong, "strongly emphasized"),
        "."
    )
)
CM.html(doc)
```

Nested emphasis:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        CM.Node(CM.Strong, "Bold with ", CM.Node(CM.Emph, "italic"), " inside")
    )
)
CM.html(doc)
```

### Code

Inline code spans for mentioning code within text. The argument is the literal
code string.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "Call ",
        CM.Node(CM.Code, "process(data)"),
        " to transform the input."
    )
)
CM.html(doc)
```

### Link

Hyperlinks with a destination URL and optional title. Links are containers—their
children become the link text.

| Keyword | Type | Required | Description |
|---------|------|----------|-------------|
| `dest` | `String` | Yes | URL or path |
| `title` | `String` | No | Tooltip text |

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "Visit the ",
        CM.Node(CM.Link, "official website"; dest="https://example.com", title="Example Site"),
        " for more information."
    )
)
CM.html(doc)
```

Links can contain formatting:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        CM.Node(CM.Link,
            "Click ",
            CM.Node(CM.Strong, "here"),
            " to continue";
            dest="/next"
        )
    )
)
CM.html(doc)
```

### Image

Images with source URL and alt text. Unlike links, images don't contain children—
the alt text is specified as a keyword argument.

| Keyword | Type | Required | Description |
|---------|------|----------|-------------|
| `dest` | `String` | Yes | Image URL or path |
| `alt` | `String` | No | Alternative text |
| `title` | `String` | No | Tooltip text |

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "Here's a diagram: ",
        CM.Node(CM.Image; dest="diagram.png", alt="Architecture diagram")
    )
)
CM.html(doc)
```

### SoftBreak and LineBreak

`SoftBreak` represents a line break in the source that becomes a space or newline
depending on output format. `LineBreak` is a hard break (`<br>` in HTML).

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "First line",
        CM.Node(CM.SoftBreak),
        "continues here (soft break becomes space)."
    ),
    CM.Node(CM.Paragraph,
        "Line one",
        CM.Node(CM.LineBreak),
        "Line two (hard break)"
    )
)
CM.html(doc)
```

### HtmlInline

Raw inline HTML for special formatting not available in markdown. Use paired
tags for spans or single tags for elements like `<br>`.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "Text with ",
        CM.Node(CM.HtmlInline, "<mark>"),
        "highlighted",
        CM.Node(CM.HtmlInline, "</mark>"),
        " content."
    )
)
CM.html(doc)
```

## Extension Types

Extension nodes represent syntax beyond standard CommonMark. They can be built
programmatically regardless of whether the corresponding parser rule is enabled.

### Math

Inline math (`Math`) and display math blocks (`DisplayMath`) for LaTeX-style
equations. The argument is the LaTeX expression without delimiters.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "Einstein's famous equation: ",
        CM.Node(CM.Math, "E = mc^2"),
        "."
    ),
    CM.Node(CM.DisplayMath, "\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}")
)
CM.html(doc)
```

### Strikethrough, Mark, Subscript, Superscript

Text formatting for deleted text, highlighted text, subscripts, and superscripts.
All are containers that hold inline content.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        CM.Node(CM.Strikethrough, "removed"),
        ", ",
        CM.Node(CM.Mark, "highlighted"),
        ", H",
        CM.Node(CM.Subscript, "2"),
        "O, x",
        CM.Node(CM.Superscript, "2")
    )
)
CM.html(doc)
```

### Admonition

Callout boxes for notes, warnings, tips, and other highlighted content. Takes
a category, title, and block children.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Admonition, "warning", "Important",
        CM.Node(CM.Paragraph, "This operation cannot be undone.")
    ),
    CM.Node(CM.Admonition, "tip", "Pro Tip",
        CM.Node(CM.Paragraph, "Use keyboard shortcuts for efficiency.")
    )
)
CM.html(doc)
```

### FencedDiv

Generic container divs with CSS classes and IDs. Useful for custom styling or
semantic grouping.

| Keyword | Type | Description |
|---------|------|-------------|
| `class` | `String` or `Vector{String}` | CSS class(es) |
| `id` | `String` | Element ID |

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.FencedDiv,
        CM.Node(CM.Paragraph, "Important content here.");
        class=["highlight", "important"], id="section-1"
    )
)
CM.html(doc)
```

### Footnotes

Footnote definitions and references. When building a `Document`, footnote links
are automatically connected to their definitions.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "This claim needs a citation",
        CM.Node(CM.FootnoteLink, "1"),
        "."
    ),
    CM.Node(CM.FootnoteDefinition, "1",
        CM.Node(CM.Paragraph, "Source: Journal of Examples, 2024.")
    )
)
CM.html(doc)
```

### GitHubAlert

GitHub-flavored alert blocks. Categories: `note`, `tip`, `important`, `warning`,
`caution`. The title defaults to the capitalized category.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.GitHubAlert, "note",
        CM.Node(CM.Paragraph, "This is informational.")
    ),
    CM.Node(CM.GitHubAlert, "warning",
        CM.Node(CM.Paragraph, "Proceed with caution!"); title="Danger Zone"
    )
)
CM.html(doc)
```

### TaskItem

Checkbox list items for task lists. Use `checked=true` for completed items.
TaskItems go inside a `List` just like regular `Item` nodes.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Heading, 2, "Todo"),
    CM.Node(CM.List,
        CM.Node(CM.TaskItem, CM.Node(CM.Paragraph, "Write documentation")),
        CM.Node(CM.TaskItem, CM.Node(CM.Paragraph, "Add tests"); checked=true),
        CM.Node(CM.TaskItem, CM.Node(CM.Paragraph, "Release"))
    )
)
CM.html(doc)
```

### Table

Tables with headers and data rows. Build from `TableHeader`, `TableBody`,
`TableRow`, and `TableCell` components.

The `align` keyword on `Table` sets column alignments: `:left`, `:center`, or `:right`.

```@example ast
header = CM.Node(CM.TableHeader,
    CM.Node(CM.TableRow,
        CM.Node(CM.TableCell, "Name"),
        CM.Node(CM.TableCell, "Value"),
        CM.Node(CM.TableCell, "Status")
    )
)
row1 = CM.Node(CM.TableRow,
    CM.Node(CM.TableCell, "Alpha"),
    CM.Node(CM.TableCell, "100"),
    CM.Node(CM.TableCell, CM.Node(CM.Strong, "Active"))
)
row2 = CM.Node(CM.TableRow,
    CM.Node(CM.TableCell, "Beta"),
    CM.Node(CM.TableCell, "200"),
    CM.Node(CM.TableCell, "Pending")
)
doc = CM.Node(CM.Document,
    CM.Node(CM.Table, header, row1, row2; align=[:left, :right, :center])
)
CM.html(doc)
```

### Citation

Academic citation references. Requires bibliography configuration for proper
rendering.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "According to ",
        CM.Node(CM.Citation, "smith2020"),
        ", this approach is effective."
    )
)
CM.html(doc)
```

### Raw Content

Format-specific content that passes through only to matching output formats.
Available types: `LaTeXInline`, `LaTeXBlock`, `TypstInline`, `TypstBlock`.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "This ",
        CM.Node(CM.LaTeXInline, "\\textbf{bold}"),
        " only appears in LaTeX output."
    )
)
CM.latex(doc)
```

### Reference Links

Reference-style links preserve the original syntax for roundtripping. These
nodes are produced when parsing with `ReferenceLinkRule` enabled.

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Paragraph,
        "See the ",
        CM.Node(CM.ReferenceLink, "docs"; dest="https://example.com", label="docs"),
        " or ",
        CM.Node(CM.ReferenceLink, "click here"; dest="https://example.com", label="docs", style=:full),
        "."
    ),
    CM.Node(CM.ReferenceDefinition; label="docs", dest="https://example.com")
)
CM.markdown(doc)
```

| Type | Children | Keyword Args |
|------|----------|--------------|
| `ReferenceLink` | link text | `dest`, `label`, `title=""`, `style=:full` |
| `ReferenceImage` | alt text | `dest`, `label`, `title=""`, `style=:full` |
| `ReferenceDefinition` | — | `label`, `dest`, `title=""` |
| `UnresolvedReference` | link text | `label`, `style=:shortcut`, `image=false` |

The `style` can be `:full`, `:collapsed`, or `:shortcut`.

## Tree Manipulation

After constructing nodes, you can modify the tree structure using these functions:

| Function | Description |
|----------|-------------|
| `append_child(parent, child)` | Add child as last child of parent |
| `prepend_child(parent, child)` | Add child as first child of parent |
| `insert_after(node, sibling)` | Insert sibling immediately after node |
| `insert_before(node, sibling)` | Insert sibling immediately before node |
| `unlink(node)` | Remove node from its parent |
| `isnull(node)` | Check if node is the null node (empty reference) |
| `text(string)` | Create a Text node with the given content |

### Building Incrementally

Instead of nesting everything in the constructor, you can build nodes step by step:

```@example ast
# Create empty containers
doc = CM.Node(CM.Document)
para = CM.Node(CM.Paragraph)

# Add content
CM.append_child(para, CM.text("Hello "))
CM.append_child(para, CM.Node(CM.Strong, "world"))
CM.append_child(para, CM.text("!"))

# Attach to document
CM.append_child(doc, para)

CM.html(doc)
```

### Modifying Existing Trees

You can also modify trees created by the parser:

```@example ast
# Parse a document
parser = CM.Parser()
doc = parser("# Original Title\n\nSome content.")

# Find and modify nodes
for (node, entering) in doc
    if entering && node.t isa CM.Heading
        # Prepend "Chapter: " to all headings
        CM.prepend_child(node, CM.text("Chapter: "))
    end
end

CM.html(doc)
```

## Complete Example

A realistic document combining multiple element types:

```@example ast
doc = CM.Node(CM.Document,
    CM.Node(CM.Heading, 1, "CommonMark.jl User Guide"),

    CM.Node(CM.Paragraph,
        "CommonMark.jl is a ",
        CM.Node(CM.Strong, "fast"),
        " and ",
        CM.Node(CM.Strong, "spec-compliant"),
        " markdown parser for Julia."
    ),

    CM.Node(CM.Admonition, "tip", "Quick Start",
        CM.Node(CM.Paragraph,
            "Install with ",
            CM.Node(CM.Code, "Pkg.add(\"CommonMark\")"),
            "."
        )
    ),

    CM.Node(CM.Heading, 2, "Features"),

    CM.Node(CM.List,
        CM.Node(CM.Item, CM.Node(CM.Paragraph,
            CM.Node(CM.Link, "Multiple output formats"; dest="#outputs"),
            ": HTML, LaTeX, Typst, terminal"
        )),
        CM.Node(CM.Item, CM.Node(CM.Paragraph,
            "Extensible parser with ",
            CM.Node(CM.Code, "enable!"),
            " and ",
            CM.Node(CM.Code, "disable!")
        )),
        CM.Node(CM.Item, CM.Node(CM.Paragraph, "Full CommonMark specification support"))
    ),

    CM.Node(CM.Heading, 2, "Example"),

    CM.Node(CM.CodeBlock, """
using CommonMark

parser = Parser()
enable!(parser, TableRule())

ast = parser("| A | B |\\n|---|---|\\n| 1 | 2 |")
html(ast)"""; info="julia"),

    CM.Node(CM.Paragraph,
        "See the ",
        CM.Node(CM.Link, "API Reference"; dest="api.html"),
        " for complete documentation."
    )
)

CM.html(doc)
```

## Converting from Julia Markdown

CommonMark.jl can convert Julia's stdlib `Markdown.MD` AST to CommonMark's
`Node` AST. This enables migration of existing documentation or integration
with tools that produce stdlib Markdown.

```@example ast-stdlib
using Markdown  # Load first to trigger extension
using CommonMark
import CommonMark: Node

# Parse with Julia's stdlib
md = Markdown.parse("# Hello World\n\nThis is **bold** and *italic* text.")

# Convert to CommonMark AST
ast = Node(md)

# Render to any format
CommonMark.html(ast)
```

The conversion handles all stdlib element types:

| Stdlib Type | CommonMark Type |
|-------------|-----------------|
| `MD` | `Document` |
| `Paragraph` | `Paragraph` |
| `Header{N}` | `Heading` (level N) |
| `Bold` | `Strong` |
| `Italic` | `Emph` |
| `Code` (inline) | `Code` |
| `Code` (block) | `CodeBlock` |
| `BlockQuote` | `BlockQuote` |
| `List` | `List` + `Item` |
| `HorizontalRule` | `ThematicBreak` |
| `Link` | `Link` |
| `Image` | `Image` |
| `LineBreak` | `LineBreak` |
| `Table` | `Table` hierarchy |
| `Admonition` | `Admonition` |
| `Footnote` | `FootnoteDefinition` / `FootnoteLink` |
| `LaTeX` | `Math` |

Metadata from the stdlib `MD` object is preserved:

```@example ast-stdlib
md = Markdown.MD([Markdown.Paragraph(["Content"])])
md.meta[:title] = "My Document"
md.meta[:author] = "Author Name"

ast = Node(md)
ast.meta["title"], ast.meta["author"]
```

The converted AST works with all CommonMark.jl output formats:

```@example ast-stdlib
md = Markdown.parse("Visit [Julia](https://julialang.org).")
ast = Node(md)

println("HTML:     ", CommonMark.html(ast))
println("LaTeX:    ", CommonMark.latex(ast))
println("Markdown: ", CommonMark.markdown(ast))
```

## Converting to/from MarkdownAST.jl

CommonMark.jl supports bidirectional conversion with
[MarkdownAST.jl](https://github.com/JuliaDocs/MarkdownAST.jl), enabling
interoperability between the two AST representations.

### CommonMark → MarkdownAST

```@example ast-mast
using MarkdownAST
using CommonMark

cm = CommonMark.Parser()("# Hello **world**")
mast = MarkdownAST.Node(cm)
```

### MarkdownAST → CommonMark

```@example ast-mast
using MarkdownAST: @ast

mast = @ast MarkdownAST.Document() do
    MarkdownAST.Heading(1) do
        "Hello"
    end
    MarkdownAST.Paragraph() do
        "Some "
        MarkdownAST.Strong() do
            "bold"
        end
        " text."
    end
end

cm = CommonMark.Node(mast)
CommonMark.html(cm)
```

### Supported Type Mappings

| CommonMark | MarkdownAST |
|------------|-------------|
| `Document` | `Document` |
| `Paragraph` | `Paragraph` |
| `Heading` | `Heading` |
| `BlockQuote` | `BlockQuote` |
| `List` | `List` |
| `Item` | `Item` |
| `CodeBlock` | `CodeBlock` |
| `ThematicBreak` | `ThematicBreak` |
| `HtmlBlock` | `HTMLBlock` |
| `Text` | `Text` |
| `SoftBreak` | `SoftBreak` |
| `LineBreak` | `LineBreak` |
| `Code` | `Code` |
| `Emph` | `Emph` |
| `Strong` | `Strong` |
| `Link` | `Link` |
| `Image` | `Image` |
| `HtmlInline` | `HTMLInline` |
| `Backslash` | `Backslash` |
| `Table`, `TableHeader`, `TableBody`, `TableRow`, `TableCell` | Table hierarchy |
| `Admonition` | `Admonition` |
| `Math` | `InlineMath` |
| `DisplayMath` | `DisplayMath` |
| `FootnoteDefinition` | `FootnoteDefinition` |
| `FootnoteLink` | `FootnoteLink` |
| `JuliaValue`, `JuliaExpression` | `JuliaValue` |

Unsupported types generate a warning and are skipped during conversion.

## Pandoc JSON Round-Trip

CommonMark.jl can convert ASTs to and from Pandoc's JSON format, enabling
interoperability with Pandoc's ecosystem and lossless round-tripping.

### Export to Dict

Use `json(Dict, ast)` to get the Pandoc AST as a dictionary without JSON
string serialization:

```@example ast-json
import CommonMark as CM

parser = CM.Parser()
ast = parser("# Hello\n\nWorld with **bold**.")

d = CM.json(Dict, ast)
keys(d)
```

The dictionary contains Pandoc's standard keys:

```@example ast-json
d["pandoc-api-version"]
```

### Import from Dict

Convert a Pandoc AST dictionary back to a CommonMark `Node`:

```@example ast-json
ast2 = CM.Node(d)
CM.html(ast2)
```

### Round-Trip Example

This enables lossless round-tripping through the Pandoc format:

```@example ast-json
original = parser("A [link](url.md) and `code`.")
roundtrip = CM.Node(CM.json(Dict, original))

CM.markdown(original) == CM.markdown(roundtrip)
```

### Deterministic Output

For deterministic key ordering (useful for diffs and tests), pass an ordered
dict type:

```julia
using OrderedCollections
d = json(OrderedDict, ast)  # Keys in consistent order
```

### Use Cases

- **Pandoc integration**: Modify AST between CommonMark parsing and Pandoc output
- **Serialization**: Store ASTs in databases or send over networks
- **Testing**: Compare AST structures programmatically
- **Migration**: Convert from other tools that export Pandoc JSON
