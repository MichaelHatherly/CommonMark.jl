# Pandoc AST JSON → CommonMark AST reader.

"""
    Node(data::AbstractDict) -> Node

Construct a CommonMark AST from a Pandoc AST JSON dictionary.

The input should be a parsed JSON dictionary with "pandoc-api-version",
"meta", and "blocks" keys. Use `JSON.parse(str)` to convert a JSON string first.

Inverse of `json(Dict, ast)`.

# Examples

```julia
using JSON
data = JSON.parse(json_string)
ast = Node(data)

# Round-trip:
ast2 = Node(json(Dict, ast))
```
"""
function Node(data::AbstractDict)
    doc = Node(Document())

    # Convert metadata to doc.meta.
    for (k, v) in get(data, "meta", Dict())
        setmeta!(doc, k, from_json_meta(v))
    end

    # Convert blocks.
    for block in get(data, "blocks", [])
        child = from_json_block(block)
        !isnothing(child) && append_child(doc, child)
    end

    return doc
end

# Metadata conversion.

function from_json_meta(val::AbstractDict)
    t = get(val, "t", "")
    c = get(val, "c", nothing)
    if t == "MetaString"
        return c
    elseif t == "MetaList"
        return Any[from_json_meta(x) for x in c]
    elseif t == "MetaMap"
        return Dict{String,Any}(string(k) => from_json_meta(v) for (k, v) in c)
    elseif t == "MetaBool"
        return c
    else
        @warn "Unknown meta type: $t"
        return c
    end
end
from_json_meta(val) = val

# Attribute helper: [id, classes, kvpairs] → node.meta.

function apply_attrs!(node::Node, attrs)
    isnothing(attrs) && return
    length(attrs) < 3 && return
    id, classes, kvs = attrs
    !isempty(id) && setmeta!(node, "id", id)
    if !isempty(classes)
        setmeta!(node, "class", classes isa AbstractVector ? join(classes, " ") : classes)
    end
    for kv in kvs
        length(kv) >= 2 && setmeta!(node, kv[1], kv[2])
    end
end

# Inline text accumulation - join Str/Space/SoftBreak into Text nodes.

mutable struct InlineContext
    buffer::IOBuffer
    InlineContext() = new(IOBuffer())
end

function flush_text!(ctx::InlineContext, parent::Node)
    s = String(take!(ctx.buffer))
    if !isempty(s)
        node = Node(Text())
        node.literal = s
        append_child(parent, node)
    end
end

function process_inlines!(parent::Node, inlines::AbstractVector)
    ctx = InlineContext()
    for inline in inlines
        t = get(inline, "t", "")
        if t == "Str"
            write(ctx.buffer, get(inline, "c", ""))
        elseif t == "Space"
            write(ctx.buffer, ' ')
        elseif t == "SoftBreak"
            write(ctx.buffer, '\n')
        else
            flush_text!(ctx, parent)
            child = from_json_inline(inline)
            !isnothing(child) && append_child(parent, child)
        end
    end
    flush_text!(ctx, parent)
end

# Block converters.

function from_json_block(el::AbstractDict)
    t = get(el, "t", "")
    c = get(el, "c", nothing)

    try
        if t == "Para" || t == "Plain"
            return para_from_json(c)
        elseif t == "Header"
            return header_from_json(c)
        elseif t == "CodeBlock"
            return codeblock_from_json(c)
        elseif t == "BlockQuote"
            return blockquote_from_json(c)
        elseif t == "HorizontalRule"
            return Node(ThematicBreak())
        elseif t == "RawBlock"
            return rawblock_from_json(c)
        elseif t == "BulletList"
            return bulletlist_from_json(c)
        elseif t == "OrderedList"
            return orderedlist_from_json(c)
        elseif t == "Div"
            return div_from_json(c)
        elseif t == "Table"
            return table_from_json(c)
        elseif t == "DefinitionList"
            # Skip - no direct equivalent
            @warn "DefinitionList not supported"
            return nothing
        elseif t == "Null"
            return nothing
        else
            @warn "Unknown block type: $t"
            return nothing
        end
    catch e
        @warn "Failed to convert block type $t" exception = (e, catch_backtrace())
        return nothing
    end
end

function para_from_json(inlines::AbstractVector)
    node = Node(Paragraph())
    process_inlines!(node, inlines)
    return node
end

function header_from_json(content::AbstractVector)
    level, attrs, inlines = content
    node = Node(Heading())
    node.t.level = level
    apply_attrs!(node, attrs)
    process_inlines!(node, inlines)
    return node
end

function codeblock_from_json(content::AbstractVector)
    attrs, code = content
    node = Node(CodeBlock())
    id, classes, kvs = attrs
    if !isempty(classes)
        node.t.info = first(classes)
    end
    node.t.is_fenced = true
    node.t.fence_char = '`'
    node.t.fence_length = 3
    # json() chomps trailing newline, restore it.
    node.literal = endswith(code, '\n') ? code : code * "\n"
    apply_attrs!(node, attrs)
    return node
end

function blockquote_from_json(blocks::AbstractVector)
    node = Node(BlockQuote())
    for block in blocks
        child = from_json_block(block)
        !isnothing(child) && append_child(node, child)
    end
    return node
end

function rawblock_from_json(content::AbstractVector)
    length(content) < 2 && return nothing
    format, raw = content
    if format == "html"
        node = Node(HtmlBlock())
        node.literal = raw
        return node
    elseif format == "latex"
        node = Node(LaTeXBlock())
        node.literal = raw
        return node
    elseif format == "typst"
        node = Node(TypstBlock())
        node.literal = raw
        return node
    else
        @warn "Unknown raw block format: $format"
        return nothing
    end
end

function bulletlist_from_json(items::AbstractVector)
    list = Node(List())
    list.t.list_data.type = :bullet
    list.t.list_data.bullet_char = '-'
    # Detect tight/loose: Plain = tight, Para = loose in Pandoc output.
    is_tight = true
    for item_blocks in items
        item = Node(Item())
        item.t.list_data = list.t.list_data
        for block in item_blocks
            # Check original type before conversion.
            if get(block, "t", "") == "Para"
                is_tight = false
            end
            child = from_json_block(block)
            !isnothing(child) && append_child(item, child)
        end
        append_child(list, item)
    end
    list.t.list_data.tight = is_tight
    return list
end

function orderedlist_from_json(content::AbstractVector)
    list_attrs, items = content
    start, style, delim = list_attrs

    list = Node(List())
    list.t.list_data.type = :ordered
    list.t.list_data.start = start
    list.t.list_data.delimiter = get(delim, "t", "") == "OneParen" ? ")" : "."

    # Detect tight/loose: Plain = tight, Para = loose in Pandoc output.
    is_tight = true
    for item_blocks in items
        item = Node(Item())
        item.t.list_data = list.t.list_data
        for block in item_blocks
            if get(block, "t", "") == "Para"
                is_tight = false
            end
            child = from_json_block(block)
            !isnothing(child) && append_child(item, child)
        end
        append_child(list, item)
    end
    list.t.list_data.tight = is_tight
    return list
end

function div_from_json(content::AbstractVector)
    attrs, blocks = content
    node = Node(FencedDiv())
    apply_attrs!(node, attrs)
    for block in blocks
        child = from_json_block(block)
        !isnothing(child) && append_child(node, child)
    end
    return node
end

# Table conversion (Pandoc table format).

function table_from_json(content::AbstractVector)
    # Pandoc 1.23 table format:
    # [attrs, caption, colspecs, thead, [tbody...], tfoot]
    length(content) < 5 && return nothing

    attrs, caption, colspecs, thead, tbodies = content[1:5]

    # Extract alignment from colspecs: [[align, width], ...]
    spec = Symbol[]
    for cs in colspecs
        align_info = cs[1]
        align_t = get(align_info, "t", "AlignDefault")
        push!(spec, if align_t == "AlignLeft"
            :left
        elseif align_t == "AlignRight"
            :right
        elseif align_t == "AlignCenter"
            :center
        else
            :left
        end)
    end

    table = Node(Table(spec))
    apply_attrs!(table, attrs)

    # Header: [attrs, rows]
    if !isempty(thead) && length(thead) >= 2
        header_rows = thead[2]
        if !isempty(header_rows)
            header = Node(TableHeader())
            append_child(table, header)
            for row_data in header_rows
                row = table_row_from_json(row_data, spec, true)
                !isnothing(row) && append_child(header, row)
            end
        end
    end

    # Bodies: [[attrs, row_head_cols, inter_head, rows], ...]
    if !isempty(tbodies)
        body = Node(TableBody())
        append_child(table, body)
        for tbody in tbodies
            length(tbody) >= 4 || continue
            rows = tbody[4]
            for row_data in rows
                row = table_row_from_json(row_data, spec, false)
                !isnothing(row) && append_child(body, row)
            end
        end
    end

    return table
end

function table_row_from_json(
    row_data::AbstractVector,
    spec::Vector{Symbol},
    is_header::Bool,
)
    # Row: [attrs, cells]
    length(row_data) >= 2 || return nothing
    attrs, cells = row_data

    row = Node(TableRow())
    apply_attrs!(row, attrs)

    for (i, cell_data) in enumerate(cells)
        # Cell: [attrs, alignment, rowspan, colspan, blocks]
        length(cell_data) >= 5 || continue
        cell_attrs, align_info, rowspan, colspan, blocks = cell_data

        align = i <= length(spec) ? spec[i] : :left
        cell = Node(TableCell(align, is_header, i))
        apply_attrs!(cell, cell_attrs)

        # Table cells contain blocks, but CommonMark TableCell contains inlines.
        # Extract inlines from paragraph blocks.
        for block in blocks
            t = get(block, "t", "")
            if t == "Para" || t == "Plain"
                process_inlines!(cell, get(block, "c", []))
            end
        end

        append_child(row, cell)
    end

    return row
end

# Inline converters.

function from_json_inline(el::AbstractDict)
    t = get(el, "t", "")
    c = get(el, "c", nothing)

    try
        if t == "LineBreak"
            return Node(LineBreak())
        elseif t == "Code"
            return code_from_json(c)
        elseif t == "Emph"
            return emph_from_json(c)
        elseif t == "Strong"
            return strong_from_json(c)
        elseif t == "Link"
            return link_from_json(c)
        elseif t == "Image"
            return image_from_json(c)
        elseif t == "RawInline"
            return rawinline_from_json(c)
        elseif t == "Math"
            return math_from_json(c)
        elseif t == "Strikeout"
            return strikethrough_from_json(c)
        elseif t == "Subscript"
            return subscript_from_json(c)
        elseif t == "Superscript"
            return superscript_from_json(c)
        elseif t == "Note"
            # Footnotes - skip for now (need context for id generation)
            @warn "Note (footnote) conversion not fully supported"
            return nothing
        elseif t == "Cite"
            # Citation - skip for now
            @warn "Cite conversion not fully supported"
            return nothing
        elseif t == "Quoted"
            return quoted_from_json(c)
        elseif t == "SmallCaps" || t == "Span"
            # Container types - extract content
            return span_from_json(c)
        else
            @warn "Unknown inline type: $t"
            return nothing
        end
    catch e
        @warn "Failed to convert inline type $t" exception = (e, catch_backtrace())
        return nothing
    end
end

function code_from_json(content::AbstractVector)
    attrs, code = content
    node = Node(Code())
    node.literal = code
    apply_attrs!(node, attrs)
    return node
end

function emph_from_json(inlines::AbstractVector)
    node = Node(Emph())
    process_inlines!(node, inlines)
    return node
end

function strong_from_json(inlines::AbstractVector)
    node = Node(Strong())
    process_inlines!(node, inlines)
    return node
end

function link_from_json(content::AbstractVector)
    attrs, inlines, target = content
    url, title = target

    node = Node(Link())
    node.t.destination = url
    node.t.title = title
    apply_attrs!(node, attrs)
    process_inlines!(node, inlines)
    return node
end

function image_from_json(content::AbstractVector)
    attrs, inlines, target = content
    url, title = target

    node = Node(Image())
    node.t.destination = url
    node.t.title = title
    apply_attrs!(node, attrs)
    process_inlines!(node, inlines)
    return node
end

function rawinline_from_json(content::AbstractVector)
    length(content) < 2 && return nothing
    format, raw = content
    if format == "html"
        node = Node(HtmlInline())
        node.literal = raw
        return node
    elseif format == "latex"
        node = Node(LaTeXInline())
        node.literal = raw
        return node
    elseif format == "typst"
        node = Node(TypstInline())
        node.literal = raw
        return node
    else
        @warn "Unknown raw inline format: $format"
        return nothing
    end
end

function math_from_json(content::AbstractVector)
    length(content) < 2 && return nothing
    math_type, tex = content
    t = get(math_type, "t", "")
    if t == "DisplayMath"
        node = Node(DisplayMath())
        node.literal = tex
        return node
    else  # InlineMath
        node = Node(Math())
        node.literal = tex
        return node
    end
end

function strikethrough_from_json(inlines::AbstractVector)
    node = Node(Strikethrough())
    process_inlines!(node, inlines)
    return node
end

function subscript_from_json(inlines::AbstractVector)
    node = Node(Subscript())
    process_inlines!(node, inlines)
    return node
end

function superscript_from_json(inlines::AbstractVector)
    node = Node(Superscript())
    process_inlines!(node, inlines)
    return node
end

function quoted_from_json(content::AbstractVector)
    # Quoted: [quote_type, inlines]
    # Convert to plain text with quotes.
    length(content) < 2 && return nothing
    quote_type, inlines = content
    t = get(quote_type, "t", "")

    # Create a container with quote chars + inlines.
    # Since we don't have a Quoted type, wrap in text.
    open_q = t == "SingleQuote" ? "'" : "\""
    close_q = t == "SingleQuote" ? "'" : "\""

    container = Node(Emph())  # Use Emph as container, then replace.
    process_inlines!(container, inlines)

    # Prepend/append quote text nodes.
    open_node = Node(Text())
    open_node.literal = open_q
    close_node = Node(Text())
    close_node.literal = close_q

    prepend_child(container, open_node)
    append_child(container, close_node)

    # Convert Emph back to plain - return first child if single text.
    # Actually, just return as-is; quotes embedded.
    return container
end

function span_from_json(content::AbstractVector)
    # Span/SmallCaps: [attrs, inlines] - extract inlines.
    length(content) < 2 && return nothing
    attrs, inlines = content

    # No direct Span type - create temporary container and extract.
    # For single inline, return it; for multiple, wrap in Emph.
    if length(inlines) == 1
        return from_json_inline(inlines[1])
    end

    # Multiple inlines - wrap in a container.
    container = Node(Emph())
    process_inlines!(container, inlines)
    return container
end
