# Julia Markdown stdlib AST -> CommonMark.jl AST converter.

module CommonMarkMarkdownExt

using CommonMark
using CommonMark:
    Node,
    append_child,
    setmeta!,
    Document,
    Paragraph,
    Heading,
    BlockQuote,
    List,
    Item,
    CodeBlock,
    ThematicBreak,
    Text,
    SoftBreak,
    LineBreak,
    Code,
    Emph,
    Strong,
    Link,
    Image,
    # Extensions
    Table,
    TableHeader,
    TableBody,
    TableRow,
    TableCell,
    Admonition,
    FootnoteDefinition,
    FootnoteLink,
    Math

using Markdown

"""
    Node(md::Markdown.MD) -> Node

Convert a Julia Markdown stdlib AST to a CommonMark.jl AST.

# Examples

```julia
using CommonMark, Markdown
md = md"# Hello **world**"
ast = Node(md)
html(ast)
```
"""
function CommonMark.Node(md::Markdown.MD)
    doc = Node(Document())
    for (k, v) in md.meta
        setmeta!(doc, string(k), v)
    end
    for block in md.content
        child = from_stdlib_block(block)
        !isnothing(child) && append_child(doc, child)
    end
    return doc
end

# Block converters

function from_stdlib_block(elem::Markdown.Paragraph)
    node = Node(Paragraph())
    process_inlines!(node, elem.content)
    return node
end

function from_stdlib_block(elem::Markdown.Header{N}) where {N}
    node = Node(Heading())
    node.t.level = N
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_block(elem::Markdown.Code)
    node = Node(CodeBlock())
    node.t.info = elem.language
    node.t.is_fenced = true
    node.t.fence_char = '`'
    node.t.fence_length = 3
    node.literal = endswith(elem.code, '\n') ? elem.code : elem.code * "\n"
    return node
end

function from_stdlib_block(elem::Markdown.BlockQuote)
    node = Node(BlockQuote())
    for block in elem.content
        child = from_stdlib_block(block)
        !isnothing(child) && append_child(node, child)
    end
    return node
end

function from_stdlib_block(elem::Markdown.List)
    list = Node(List())
    list.t.list_data.type = elem.ordered >= 0 ? :ordered : :bullet
    list.t.list_data.tight = !elem.loose
    if elem.ordered >= 0
        list.t.list_data.start = elem.ordered
    else
        list.t.list_data.bullet_char = '-'
    end
    for item_content in elem.items
        item = Node(Item())
        item.t.list_data = list.t.list_data
        for block in item_content
            child = from_stdlib_block(block)
            !isnothing(child) && append_child(item, child)
        end
        append_child(list, item)
    end
    return list
end

function from_stdlib_block(elem::Markdown.HorizontalRule)
    return Node(ThematicBreak())
end

function from_stdlib_block(elem::Markdown.Table)
    rows = elem.rows
    isempty(rows) && return nothing

    spec = elem.align
    table = Node(Table(spec))

    # First row is header
    if !isempty(rows)
        header = Node(TableHeader())
        append_child(table, header)
        header_row = table_row_from_stdlib(rows[1], spec, true)
        append_child(header, header_row)
    end

    # Rest are body
    if length(rows) > 1
        body = Node(TableBody())
        append_child(table, body)
        for i = 2:length(rows)
            row = table_row_from_stdlib(rows[i], spec, false)
            append_child(body, row)
        end
    end

    return table
end

function table_row_from_stdlib(cells::Vector, spec::Vector{Symbol}, is_header::Bool)
    row = Node(TableRow())
    for (i, cell_content) in enumerate(cells)
        align = i <= length(spec) ? spec[i] : :left
        cell = Node(TableCell(align, is_header, i))
        process_inlines!(cell, cell_content)
        append_child(row, cell)
    end
    return row
end

function from_stdlib_block(elem::Markdown.Admonition)
    node = Node(Admonition(elem.category, elem.title))
    for block in elem.content
        child = from_stdlib_block(block)
        !isnothing(child) && append_child(node, child)
    end
    return node
end

function from_stdlib_block(elem::Markdown.Footnote)
    # Footnote with text is a definition, without is a reference (handled inline)
    if !isnothing(elem.text)
        node = Node(FootnoteDefinition(elem.id))
        for block in elem.text
            child = from_stdlib_block(block)
            !isnothing(child) && append_child(node, child)
        end
        return node
    end
    return nothing
end

# Fallback for unknown block types
function from_stdlib_block(elem)
    @warn "Unknown Markdown block type: $(typeof(elem))"
    return nothing
end

# Inline converters

function process_inlines!(parent::Node, content)
    for elem in content
        child = from_stdlib_inline(elem)
        !isnothing(child) && append_child(parent, child)
    end
end

function from_stdlib_inline(s::AbstractString)
    node = Node(Text())
    node.literal = s
    return node
end

function from_stdlib_inline(elem::Markdown.Bold)
    node = Node(Strong())
    node.literal = "**"  # Delimiter for markdown writer
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Italic)
    node = Node(Emph())
    node.literal = "*"  # Delimiter for markdown writer
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Code)
    node = Node(Code())
    node.literal = elem.code
    return node
end

function from_stdlib_inline(elem::Markdown.Link)
    node = Node(Link())
    node.t.destination = elem.url
    node.t.title = ""
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Image)
    node = Node(Image())
    node.t.destination = elem.url
    node.t.title = ""
    # Alt text goes as Text child in CommonMark.jl
    if !isempty(elem.alt)
        alt_node = Node(Text())
        alt_node.literal = elem.alt
        append_child(node, alt_node)
    end
    return node
end

function from_stdlib_inline(elem::Markdown.LineBreak)
    return Node(LineBreak())
end

function from_stdlib_inline(elem::Markdown.LaTeX)
    node = Node(Math())
    node.literal = elem.formula
    return node
end

function from_stdlib_inline(elem::Markdown.Footnote)
    # Footnote reference (text is nothing)
    if isnothing(elem.text)
        return Node(FootnoteLink, elem.id)
    end
    return nothing
end

# Fallback for unknown inline types
function from_stdlib_inline(elem)
    @warn "Unknown Markdown inline type: $(typeof(elem))"
    return nothing
end

end # module
