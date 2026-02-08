abstract type TableComponent <: AbstractBlock end

is_container(::TableComponent) = true
accepts_lines(::TableComponent) = false
finalize(table::TableComponent, parser::Parser, node::Node) = nothing
can_contain(::TableComponent, ::Any) = false

"""Table container. Build with `Node(Table, header, body_rows...; align=[:left, :center, :right])`."""
struct Table <: TableComponent
    spec::Vector{Symbol}
    Table(spec) = new(spec)
end

continue_(::Table, parser::Parser, ::Node) = parser.blank ? 1 : 0

function Node(
    ::Type{Table},
    header::Node,
    body_rows::Node...;
    align::Vector{Symbol} = Symbol[],
)
    spec =
        isempty(align) ?
        fill(
            :left,
            length(header.first_child.first_child === nothing ? 0 : count_cells(header)),
        ) : align
    t = Table(spec)
    node = Node(t)
    append_child(node, header)
    body = Node(TableBody())
    for row in body_rows
        append_child(body, row)
    end
    append_child(node, body)
    node
end

function count_cells(header::Node)
    count = 0
    cell = header.first_child.first_child
    while !isnull(cell)
        count += 1
        cell = cell.nxt
    end
    count
end

"""Table header section containing one row."""
struct TableHeader <: TableComponent end

function Node(::Type{TableHeader}, row::Node)
    node = Node(TableHeader())
    append_child(node, row)
    node
end

"""Table body section containing data rows."""
struct TableBody <: TableComponent end

Node(::Type{TableBody}, rows::Node...) = _build(TableBody(), rows)

continue_(table::TableBody, parser::Parser, container::Node) = 1

"""Table footer section containing footer rows."""
struct TableFoot <: TableComponent end

Node(::Type{TableFoot}, rows::Node...) = _build(TableFoot(), rows)

"""Table row containing cells."""
struct TableRow <: TableComponent end

"""Grouping container for visual sub-rows of one logical row group in grid tables."""
struct TableRows <: TableComponent end

Node(::Type{TableRow}, cells::Node...) = _build(TableRow(), cells)

contains_inlines(::TableRow) = true

"""Table cell. Build with `Node(TableCell, children...; align=:left, header=false, column=1)`."""
struct TableCell <: TableComponent
    align::Symbol
    header::Bool
    column::Int
    rowspan::Int
    colspan::Int
end

contains_inlines(::TableCell) = true

function Node(
    ::Type{TableCell},
    children...;
    align::Symbol = :left,
    header::Bool = false,
    column::Int = 1,
    rowspan::Int = 1,
    colspan::Int = 1,
)
    tc = TableCell(align, header, column, rowspan, colspan)
    _build(tc, children)
end

function gfm_table(parser::Parser, container::Node)
    if !parser.indented
        if container.t isa Paragraph
            finalize_literal!(container)
            header = container.literal
            spec_str = rest_from_nonspace(parser)
            if valid_table_spec(spec_str)
                # Parse the table spec line.
                spec = parse_table_spec(spec_str)
                table = Node(Table(spec), container.sourcepos)
                # Build header row with cells for each column.
                head = Node(TableHeader(), container.sourcepos)
                append_child(table, head)
                row = Node(TableRow(), container.sourcepos)
                row.literal = header
                append_child(head, row)
                # Insert the empty body for the table.
                body = Node(TableBody(), container.sourcepos)
                append_child(table, body)
                # Splice the newly created table in place of the paragraph.
                insert_after(container, table)
                unlink(container)
                parser.tip = table
                advance_to_end(parser)
                return 2
            end
        end
        if container.t isa Table
            line = rest_from_nonspace(parser)
            if valid_table_row(line)
                row = Node(TableRow(), container.sourcepos)
                append_child(container.last_child, row)
                row.literal = line
                advance_to_end(parser)
                return 2
            end
        end
    end
    return 0
end

valid_table_row(str) = startswith(str, '|')
valid_table_spec(str) = all(c -> c in "|-: ", str)

function parse_table_spec(str)
    map(eachmatch(r"\|([ ]*[: ]?[-]+[ :]?[ ]*)\|", str; overlap = true)) do match
        str = strip(match[1])
        left, right = str[1] === ':', str[end] === ':'
        center = left && right
        align = center ? :center : right ? :right : :left
        return align
    end
end

"""
    TableRule()

Parse GitHub Flavored Markdown pipe tables.

Not enabled by default. Tables use `|` to separate columns and require a
header separator row.

```markdown
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
```

Alignment can be specified with `:` in the separator row:
- `:---` left align
- `:---:` center align
- `---:` right align
"""
struct TableRule
    pipes::Vector{Node}
    TableRule() = new([])
end

block_rule(::TableRule) = Rule(gfm_table, 0.5, "|")

struct TablePipe <: AbstractInline end

inline_rule(rule::TableRule) =
    Rule(0, "|") do parser, block
        block.t isa TableRow || return false
        @assert read(parser, Char) == '|'
        eof(parser) && return true # Skip last pipe.
        pipe = Node(TablePipe())
        append_child(block, pipe)
        push!(rule.pipes, pipe)
        return true
    end

# Low priority since this *must* happen after nested structure of emphasis and
# links is determined. 100 should do fine.
inline_modifier(rule::TableRule) =
    Rule(100) do parser, block
        block.t isa TableRow || return
        isheader = block.parent.t isa TableHeader
        spec = block.parent.parent.t.spec
        max_cols = length(spec)
        col = 1
        cells = Node[]
        while !isempty(rule.pipes)
            pipe = popfirst!(rule.pipes)
            if pipe.parent === block
                # Top-level pipe must be replaced with a table cell containing
                # everything up until the next pipe.
                cell = Node(TableCell(spec[min(col, max_cols)], isheader, col, 1, 1))
                n = pipe.nxt
                elems = Node[]
                # Find all nodes between this pipe and the next.
                while !isnull(n) && !(n.t isa TablePipe)
                    push!(elems, n)
                    n = n.nxt
                end
                total = length(elems)
                for (nth, elem) in enumerate(elems)
                    # Strip surronding whitespace in each cell.
                    lit = elem.literal
                    lit = (nth === 1 && elem.t isa Text) ? lstrip(lit) : lit
                    lit = (nth === total && elem.t isa Text) ? rstrip(lit) : lit
                    elem.literal = lit
                    append_child(cell, elem)
                end
                push!(cells, cell)
                unlink(pipe)
                col += 1
            else
                # Replace nested pipes with text literals since they can't
                # demarcate a cell boarder.
                pipe.t = Text()
                pipe.literal = "|"
            end
        end
        if length(cells) < max_cols
            # Add addtional cells in this row is below number in spec.
            extra = (length(cells)+1):max_cols
            append!(cells, (Node(TableCell(:left, isheader, n, 1, 1)) for n in extra))
        end
        for (nth, cell) in enumerate(cells)
            # Drop additional cells if they are longer that the spec.
            nth ≤ length(spec) ? append_child(block, cell) : unlink(cell)
        end
    end

#
# Writers
#

# HTML

write_html(::Table, rend, n, ent) =
    tag(rend, ent ? "table" : "/table", ent ? attributes(rend, n) : [])
write_html(::TableHeader, rend, node, enter) = tag(rend, enter ? "thead" : "/thead")
write_html(::TableBody, rend, node, enter) = tag(rend, enter ? "tbody" : "/tbody")
write_html(::TableFoot, rend, node, enter) = tag(rend, enter ? "tfoot" : "/tfoot")
write_html(::TableRows, rend, node, enter) = nothing
write_html(::TableRow, rend, node, enter) = tag(rend, enter ? "tr" : "/tr")

function write_html(cell::TableCell, rend, node, enter)
    tag_name = cell.header ? "th" : "td"
    if enter
        attrs = ["align" => string(cell.align)]
        cell.rowspan > 1 && push!(attrs, "rowspan" => string(cell.rowspan))
        cell.colspan > 1 && push!(attrs, "colspan" => string(cell.colspan))
        tag(rend, tag_name, attrs)
    else
        tag(rend, "/$tag_name")
    end
end

# LaTeX

function write_latex(table::Table, rend, node, enter)
    if enter
        print(rend.buffer, "\\begin{longtable}[]{@{}")
        join(rend.buffer, (string(align)[1] for align in table.spec))
        println(rend.buffer, "@{}}")
    else
        println(rend.buffer, "\\end{longtable}")
    end
end

function write_latex(::TableHeader, rend, node, enter)
    if enter
        println(rend.buffer, "\\hline")
    else
        println(rend.buffer, "\\hline")
        println(rend.buffer, "\\endfirsthead")
    end
end

function write_latex(::TableBody, rend, node, enter)
    if !enter
        println(rend.buffer, "\\hline")
    end
end

write_latex(::TableRows, rend, node, enter) = nothing

function write_latex(::TableFoot, rend, node, enter)
    if enter
        println(rend.buffer, "\\hline")
    else
        println(rend.buffer, "\\endlastfoot")
    end
end

function write_latex(::TableRow, rend, node, enter)
    enter ? nothing : println(rend.buffer, "\\tabularnewline")
end

function write_latex(::TableCell, rend, node, enter)
    if !enter && node.parent.last_child !== node
        print(rend.buffer, " & ")
    end
end

# Typst

function write_typst(table::Table, rend, node, enter)
    if enter
        align = "align: (" * join(table.spec, ", ") * ")"
        columns = "columns: $(length(table.spec))"
        fill = "fill: (x, y) => if y == 0 { rgb(\"#e5e7eb\") }"
        println(rend.buffer, "#table($align, $columns, $fill,")
    else
        println(rend.buffer, ")")
    end
end

function write_typst(::TableHeader, rend, node, enter)
    if enter
        println(rend.buffer, "table.header(")
    else
        println(rend.buffer, "),")
    end
end

write_typst(::TableBody, rend, node, enter) = nothing
write_typst(::TableRows, rend, node, enter) = nothing
function write_typst(::TableFoot, rend, node, enter)
    if enter
        println(rend.buffer, "table.footer(")
    else
        println(rend.buffer, "),")
    end
end

function write_typst(::TableRow, rend, node, enter)
    if enter
    else
        println(rend.buffer)
    end
end

function write_typst(::TableCell, rend, node, enter)
    if enter
        print(rend.buffer, "[")
    else
        print(rend.buffer, "],")
    end
end

# Term

function write_term(table::Table, rend, node, enter)
    if enter
        cells, widths = calculate_columns_widths(table, node) do node
            length(replace(term(node), r"\e\[[0-9]+(?:;[0-9]+)*m" => ""))
        end
        rend.context[:cells] = cells
        rend.context[:widths] = widths

        print_margin(rend)
        print(rend.format.buffer, "┏━")
        join(rend.format.buffer, ("━"^w for w in widths), "━┯━")
        println(rend.format.buffer, "━┓")
    else
        print_margin(rend)
        print(rend.format.buffer, "┗━")
        join(rend.format.buffer, ("━"^w for w in rend.context[:widths]), "━┷━")
        println(rend.format.buffer, "━┛")

        delete!(rend.context, :cells)
        delete!(rend.context, :widths)
    end
    return nothing
end

function write_term(::TableHeader, rend, node, enter)
    haskey(rend.context, :widths) || return nothing
    if !enter
        print_margin(rend)
        print(rend.format.buffer, "┠─")
        join(rend.format.buffer, ("─"^w for w in rend.context[:widths]), "─┼─")
        println(rend.format.buffer, "─┨")
    end
    return nothing
end

write_term(::TableBody, rend, node, enter) = nothing
write_term(::TableRows, rend, node, enter) = nothing
write_term(::TableFoot, rend, node, enter) = nothing

function write_term(::TableRow, rend, node, enter)
    haskey(rend.context, :widths) || return nothing
    if enter
        print_margin(rend)
        print(rend.format.buffer, "┃ ")
    else
        println(rend.format.buffer, " ┃")
    end
    return nothing
end

function write_term(cell::TableCell, rend, node, enter)
    if haskey(rend.context, :widths)
        widths = rend.context[:widths]
        col_w = widths[cell.column]
        for i = cell.column+1:min(cell.column + cell.colspan - 1, length(widths))
            col_w += 3 + widths[i]  # " │ " separator + next column width
        end
        pad = col_w - rend.context[:cells][node]
        if enter
            if cell.align == :left
            elseif cell.align == :right
                print(rend.format.buffer, ' '^pad)
            elseif cell.align == :center
                left = Int(round(pad / 2, RoundDown))
                print(rend.format.buffer, ' '^left)
            end
        else
            if cell.align == :left
                print(rend.format.buffer, ' '^pad)
            elseif cell.align == :right
            elseif cell.align == :center
                right = Int(round(pad / 2, RoundUp))
                print(rend.format.buffer, ' '^right)
            end
            if !isnull(node.nxt)
                print(rend.format.buffer, " │ ")
            end
        end
    end
    return nothing
end

# Markdown

function write_markdown(table::Table, w::Writer, node, enter)
    if enter
        cells, widths =
            calculate_columns_widths(node -> length(markdown(node)), table, node)
        w.context[:cells] = cells
        w.context[:widths] = widths
    else
        delete!(w.context, :cells)
        delete!(w.context, :widths)
        linebreak(w, node)
    end
    return nothing
end

function write_markdown(::TableHeader, w, node, enter)
    if !enter
        haskey(w.context, :widths) || return nothing
        spec = node.parent.t.spec
        print_margin(w)
        literal(w, "|")
        for (width, align) in zip(w.context[:widths], spec)
            literal(w, align in (:left, :center) ? ":" : " ")
            literal(w, "-"^width)
            literal(w, align in (:center, :right) ? ":" : " ")
            literal(w, "|")
        end
        cr(w)
    end
    return nothing
end

write_markdown(::TableBody, w, node, enter) = nothing
write_markdown(::TableRows, w, node, enter) = nothing
write_markdown(::TableFoot, w, node, enter) = nothing

function write_markdown(::TableRow, w, node, enter)
    if enter
        print_margin(w)
        literal(w, "| ")
    else
        literal(w, " |")
        cr(w)
    end
    return nothing
end

function write_markdown(cell::TableCell, w, node, enter)
    if haskey(w.context, :widths)
        if !enter
            padding = w.context[:widths][cell.column] - w.context[:cells][node]
            literal(w, " "^padding)
            isnull(node.nxt) || literal(w, " | ")
        end
    end
    return nothing
end

# JSON

function write_json(table::Table, ctx, node, enter)
    if enter
        # Build colspecs from table alignment spec.
        colspecs = Any[]
        for align in table.spec
            a =
                align === :left ? json_el(ctx, "AlignLeft") :
                align === :right ? json_el(ctx, "AlignRight") :
                align === :center ? json_el(ctx, "AlignCenter") :
                json_el(ctx, "AlignDefault")
            push!(colspecs, Any[a, json_el(ctx, "ColWidthDefault")])
        end
        push_container!(ctx, colspecs)
        push_container!(ctx, Any[])  # head rows
        push_container!(ctx, Any[])  # body rows
    else
        body_rows = pop_container!(ctx)
        head_rows = pop_container!(ctx)
        colspecs = pop_container!(ctx)

        caption = Any[nothing, Any[]]  # [short_caption, long_caption_blocks]
        head = Any[empty_attr(), head_rows]
        body = Any[Any[empty_attr(), 0, Any[], body_rows]]
        foot = Any[empty_attr(), Any[]]
        push_element!(
            ctx,
            json_el(ctx, "Table", Any[empty_attr(), caption, colspecs, head, body, foot]),
        )
    end
end

write_json(::TableHeader, ctx, node, enter) = nothing
write_json(::TableBody, ctx, node, enter) = nothing
write_json(::TableRows, ctx, node, enter) = nothing
write_json(::TableFoot, ctx, node, enter) = nothing

function write_json(::TableRow, ctx, node, enter)
    if enter
        cells = Any[]
        push_container!(ctx, cells)
    else
        cells = pop_container!(ctx)
        row = Any[empty_attr(), cells]
        # Stack is: [blocks, colspecs, head_rows, body_rows]
        # head_rows = end-1, body_rows = end
        section = node.parent
        section.t isa TableRows && (section = section.parent)
        if section.t isa TableHeader
            push!(ctx.stack[end-1], row)
        else
            push!(ctx.stack[end], row)
        end
    end
end

function write_json(cell::TableCell, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        a =
            cell.align === :left ? json_el(ctx, "AlignLeft") :
            cell.align === :right ? json_el(ctx, "AlignRight") :
            cell.align === :center ? json_el(ctx, "AlignCenter") :
            json_el(ctx, "AlignDefault")
        blocks = isempty(inlines) ? Any[] : Any[json_el(ctx, "Plain", inlines)]
        push_element!(ctx, Any[empty_attr(), a, cell.rowspan, cell.colspan, blocks])
    end
end

write_json(::TablePipe, ctx, node, enter) = nothing

# Utilities.

function calculate_columns_widths(width_func, table, node)
    cells, widths = Dict{Node,Int}(), ones(Int, length(table.spec))
    index = 0
    for (n, enter) in node
        if enter
            if n.t isa TableRow
                index = 0
            elseif n.t isa TableCell
                index += 1
                cell = width_func(n)
                widths[index] = max(widths[index], cell)
                cells[n] = cell
            end
        end
    end
    return cells, widths
end
