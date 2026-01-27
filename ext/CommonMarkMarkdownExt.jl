# Julia Markdown stdlib AST -> CommonMark.jl AST converter.

module CommonMarkMarkdownExt

@static if isdefined(Base, :get_extension)
    import CommonMark
    import Markdown
else
    import ..CommonMark
    import ..Markdown
end

# Flatten nested Markdown.MD and merge metadata (outer takes precedence)
function flatten_md(md::Markdown.MD)
    content = Any[]
    meta = Dict{Symbol,Any}()
    for (k, v) in md.meta
        meta[k] = v
    end
    for block in md.content
        if block isa Markdown.MD
            nested_content, nested_meta = flatten_md(block)
            append!(content, nested_content)
            for (k, v) in nested_meta
                haskey(meta, k) || (meta[k] = v)
            end
        else
            push!(content, block)
        end
    end
    return content, meta
end

"""
    CommonMark.Node(md::Markdown.MD) -> CommonMark.Node

Convert a Julia Markdown stdlib AST to a CommonMark.jl AST.

# Examples

```julia
using CommonMark, Markdown
md = md"# Hello **world**"
ast = CommonMark.Node(md)
CommonMark.html(ast)
```
"""
function CommonMark.Node(md::Markdown.MD)
    doc = CommonMark.Node(CommonMark.Document())
    content, meta = flatten_md(md)
    for (k, v) in meta
        CommonMark.setmeta!(doc, string(k), v)
    end
    for block in content
        child = from_stdlib_block(block)
        !isnothing(child) && CommonMark.append_child(doc, child)
    end
    return doc
end

# Block converters

function from_stdlib_block(elem::Markdown.Paragraph)
    node = CommonMark.Node(CommonMark.Paragraph())
    process_inlines!(node, elem.content)
    return node
end

function from_stdlib_block(elem::Markdown.Header{N}) where {N}
    node = CommonMark.Node(CommonMark.Heading())
    node.t.level = N
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_block(elem::Markdown.Code)
    node = CommonMark.Node(CommonMark.CodeBlock())
    node.t.info = elem.language
    node.t.is_fenced = true
    node.t.fence_char = '`'
    # Fence must be longer than any backtick sequence in content
    node.t.fence_length = max(3, max_backtick_run(elem.code) + 1)
    node.literal = endswith(elem.code, '\n') ? elem.code : elem.code * "\n"
    return node
end

# Find longest consecutive backtick sequence in string
function max_backtick_run(s::AbstractString)
    max_run = 0
    current = 0
    for c in s
        if c == '`'
            current += 1
            max_run = max(max_run, current)
        else
            current = 0
        end
    end
    return max_run
end

function from_stdlib_block(elem::Markdown.BlockQuote)
    node = CommonMark.Node(CommonMark.BlockQuote())
    for block in elem.content
        child = from_stdlib_block(block)
        !isnothing(child) && CommonMark.append_child(node, child)
    end
    return node
end

function from_stdlib_block(elem::Markdown.List)
    list = CommonMark.Node(CommonMark.List())
    list.t.list_data.type = elem.ordered >= 0 ? :ordered : :bullet
    list.t.list_data.tight = !elem.loose
    if elem.ordered >= 0
        list.t.list_data.start = elem.ordered
    else
        list.t.list_data.bullet_char = '-'
    end
    for item_content in elem.items
        item = CommonMark.Node(CommonMark.Item())
        item.t.list_data = list.t.list_data
        for block in item_content
            child = from_stdlib_block(block)
            !isnothing(child) && CommonMark.append_child(item, child)
        end
        CommonMark.append_child(list, item)
    end
    return list
end

function from_stdlib_block(elem::Markdown.HorizontalRule)
    return CommonMark.Node(CommonMark.ThematicBreak())
end

function from_stdlib_block(elem::Markdown.Table)
    rows = elem.rows
    isempty(rows) && return nothing

    spec = elem.align
    table = CommonMark.Node(CommonMark.Table(spec))

    # First row is header
    if !isempty(rows)
        header = CommonMark.Node(CommonMark.TableHeader())
        CommonMark.append_child(table, header)
        header_row = table_row_from_stdlib(rows[1], spec, true)
        CommonMark.append_child(header, header_row)
    end

    # Rest are body
    if length(rows) > 1
        body = CommonMark.Node(CommonMark.TableBody())
        CommonMark.append_child(table, body)
        for i = 2:length(rows)
            row = table_row_from_stdlib(rows[i], spec, false)
            CommonMark.append_child(body, row)
        end
    end

    return table
end

function table_row_from_stdlib(cells::Vector, spec::Vector{Symbol}, is_header::Bool)
    row = CommonMark.Node(CommonMark.TableRow())
    for (i, cell_content) in enumerate(cells)
        align = i <= length(spec) ? spec[i] : :left
        cell = CommonMark.Node(CommonMark.TableCell(align, is_header, i))
        process_inlines!(cell, cell_content)
        CommonMark.append_child(row, cell)
    end
    return row
end

function from_stdlib_block(elem::Markdown.Admonition)
    node = CommonMark.Node(CommonMark.Admonition(elem.category, elem.title))
    for block in elem.content
        child = from_stdlib_block(block)
        !isnothing(child) && CommonMark.append_child(node, child)
    end
    return node
end

function from_stdlib_block(elem::Markdown.Footnote)
    # Footnote with text is a definition, without is a reference (handled inline)
    if !isnothing(elem.text)
        node = CommonMark.Node(CommonMark.FootnoteDefinition(elem.id))
        for block in elem.text
            child = from_stdlib_block(block)
            !isnothing(child) && CommonMark.append_child(node, child)
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

function process_inlines!(parent::CommonMark.Node, content)
    for elem in content
        child = from_stdlib_inline(elem)
        !isnothing(child) && CommonMark.append_child(parent, child)
    end
end

function from_stdlib_inline(s::AbstractString)
    node = CommonMark.Node(CommonMark.Text())
    node.literal = s
    return node
end

function from_stdlib_inline(elem::Markdown.Bold)
    node = CommonMark.Node(CommonMark.Strong())
    node.literal = "**"  # Delimiter for markdown writer
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Italic)
    node = CommonMark.Node(CommonMark.Emph())
    node.literal = "*"  # Delimiter for markdown writer
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Code)
    node = CommonMark.Node(CommonMark.Code())
    node.literal = elem.code
    return node
end

function from_stdlib_inline(elem::Markdown.Link)
    node = CommonMark.Node(CommonMark.Link())
    node.t.destination = elem.url
    node.t.title = ""
    process_inlines!(node, elem.text)
    return node
end

function from_stdlib_inline(elem::Markdown.Image)
    node = CommonMark.Node(CommonMark.Image())
    node.t.destination = elem.url
    node.t.title = ""
    # Alt text goes as Text child in CommonMark.jl
    if !isempty(elem.alt)
        alt_node = CommonMark.Node(CommonMark.Text())
        alt_node.literal = elem.alt
        CommonMark.append_child(node, alt_node)
    end
    return node
end

function from_stdlib_inline(elem::Markdown.LineBreak)
    return CommonMark.Node(CommonMark.LineBreak())
end

function from_stdlib_inline(elem::Markdown.LaTeX)
    node = CommonMark.Node(CommonMark.Math())
    node.literal = elem.formula
    return node
end

function from_stdlib_inline(elem::Markdown.Footnote)
    # Footnote reference (text is nothing)
    if isnothing(elem.text)
        return CommonMark.Node(CommonMark.FootnoteLink, elem.id)
    end
    return nothing
end

# Fallback for unknown inline types
function from_stdlib_inline(elem)
    @warn "Unknown Markdown inline type: $(typeof(elem))"
    return nothing
end

# Convert LazyCommonMarkDoc to Markdown.MD via MarkdownAST intermediate
function Base.convert(::Type{Markdown.MD}, doc::CommonMark.LazyCommonMarkDoc)
    mast = CommonMark.to_mast(doc)  # Calls MarkdownAST ext
    convert(Markdown.MD, mast)
end

end # module
