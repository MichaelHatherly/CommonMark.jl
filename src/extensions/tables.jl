abstract type TableComponent <: AbstractBlock end

is_container(::TableComponent) = true
accepts_lines(::TableComponent) = false
finalize(table::TableComponent, parser::Parser, node::Node) = nothing
can_contain(::TableComponent, ::Any) = false

struct Table <: TableComponent
    spec::Vector{Symbol}
    Table(spec) = new(spec)
end

continue_(table::Table, parser::Parser, container::Node) = 0

struct TableHeader <: TableComponent
end

struct TableBody <: TableComponent
end

continue_(table::TableBody, parser::Parser, container::Node) = 1

struct TableRow <: TableComponent
end

contains_inlines(::TableRow) = true

struct TableCell <: TableComponent
    align::Symbol
    header::Bool
    column::Int
end

contains_inlines(::TableCell) = true

function gfm_table(parser::Parser, container::Node)
    if !parser.indented
        if container.t isa Paragraph
            header = container.literal
            spec_str = SubString(parser.buf, parser.next_nonspace)
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
                advance_offset(parser, length(parser.buf) - parser.pos + 1, false)
                return 2
            end
        end
        if container.t isa Table
            line = SubString(parser.buf, parser.next_nonspace)
            if valid_table_row(line)
                row = Node(TableRow(), container.sourcepos)
                append_child(container.last_child, row)
                row.literal = line
                advance_offset(parser, length(parser.buf) - parser.pos + 1, false)
                return 2
            end
        end
    end
    return 0
end

valid_table_row(str) = startswith(str, '|')
valid_table_spec(str) = !occursin(r"[^\|:\- ]", str)

function parse_table_spec(str)
    map(eachmatch(r"\|([ ]?[: ]?[-]+[ :]?[ ]?)\|", str; overlap=true)) do match
        str = strip(match[1])
        left, right = str[1] === ':', str[end] === ':'
        center = left && right
        align = center ? :center : right ? :right : :left
        return align
    end
end

struct TableRule
    pipes::Vector{Node}
    TableRule() = new([])
end

block_rule(::TableRule) = Rule(gfm_table, 0.5, "|")

struct TablePipe <:AbstractInline end

inline_rule(rule::TableRule) = Rule(0, "|") do parser, block
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
inline_modifier(rule::TableRule) = Rule(100) do parser, block
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
            cell = Node(TableCell(spec[min(col, max_cols)], isheader, col))
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
        append!(cells, (Node(TableCell(:left, isheader, n)) for n in extra))
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

html(::Table, f::Fmt, n::Node, enter::Bool) = tag(f, enter ? "table" : "/table", enter ? attributes(f, n) : [])
html(::TableHeader, f::Fmt, ::Node, enter::Bool) = tag(f, enter ? "thead" : "/thead")
html(::TableBody, f::Fmt, ::Node, enter::Bool) = tag(f, enter ? "tbody" : "/tbody")
html(::TableRow, f::Fmt, ::Node, enter::Bool) = tag(f, enter ? "tr" : "/tr")

function html(cell::TableCell, f::Fmt, ::Node, enter::Bool)
    tag_name = cell.header ? "th" : "td"
    tag(f, enter ? "$tag_name align=\"$(cell.align)\"" : "/$tag_name")
end

# LaTeX

function latex(table::Table, f::Fmt, ::Node, enter::Bool)
    if enter
        literal(f, "\\begin{longtable}[]{@{}")
        join(f.io, (string(align)[1] for align in table.spec))
        literal(f, "@{}}\n")
    else
        literal(f, "\\end{longtable}\n")
    end
end

function latex(::TableHeader, f::Fmt, ::Node, enter::Bool)
    if enter
        literal(f, "\\hline\n")
    else
        literal(f, "\\hline\n")
        literal(f, "\\endfirsthead\n")
    end
end

function latex(::TableBody, f::Fmt, ::Node, enter::Bool)
    if !enter
        literal(f, "\\hline\n")
    end
end

function latex(::TableRow, f::Fmt, ::Node, enter::Bool)
    enter ? nothing : literal(f, "\\tabularnewline\n")
end

function latex(::TableCell, f::Fmt, n::Node, enter::Bool)
    if !enter && n.parent.last_child !== n
        literal(f, " & ")
    end
end

# Term

function term(table::Table, f::Fmt, n::Node, enter::Bool)
    if enter
        cells, widths = calculate_columns_widths(table, n) do node
            length(replace(term(node), r"\e\[[0-9]+(?:;[0-9]+)*m" => ""))
        end
        f[:cells] = cells
        f[:widths] = widths

        print_margin(f)
        literal(f, "┏━")
        join(f.io, ("━"^w for w in widths), "━┯━")
        literal(f, "━┓\n")
    else
        print_margin(f)
        literal(f, "┗━")
        join(f.io, ("━"^w for w in f[:widths]), "━┷━")
        literal(f, "━┛\n")

        delete!(f.state, :cells)
        delete!(f.state, :widths)
    end
    return nothing
end

function term(::TableHeader, f::Fmt, ::Node, enter::Bool)
    if !enter
        print_margin(f)
        literal(f, "┠─")
        join(f.io, ("─"^w for w in f[:widths]), "─┼─")
        literal(f, "─┨\n")
    end
    return nothing
end

term(::TableBody, ::Fmt, ::Node, ::Bool) = nothing

function term(::TableRow, f::Fmt, ::Node, enter::Bool)
    if enter
        print_margin(f)
        literal(f, "┃ ")
    else
        literal(f, " ┃\n")
    end
    return nothing
end

function term(cell::TableCell, f::Fmt, n::Node, enter::Bool)
    if haskey(f.state, :widths)
        pad = f[:widths][cell.column] - f[:cells][n]
        if enter
            if cell.align == :left
            elseif cell.align == :right
                literal(f, ' '^pad)
            elseif cell.align == :center
                left = Int(round(pad/2, RoundDown))
                literal(f, ' '^left)
            end
        else
            if cell.align == :left
                literal(f, ' '^pad)
            elseif cell.align == :right
            elseif cell.align == :center
                right = Int(round(pad/2, RoundUp))
                literal(f, ' '^right)
            end
            if !isnull(n.nxt)
                literal(f, " │ ")
            end
        end
    end
    return nothing
end

# Markdown

function markdown(table::Table, f::Fmt, n::Node, enter::Bool)
    if enter
        cells, widths = calculate_columns_widths(node -> length(markdown(node)), table, n)
        f[:cells] = cells
        f[:widths] = widths
    else
        delete!(f.state, :cells)
        delete!(f.state, :widths)
        linebreak(f, n)
    end
    return nothing
end

function markdown(::TableHeader, f::Fmt, n::Node, enter::Bool)
    if !enter
        spec = n.parent.t.spec
        print_margin(f)
        literal(f, "|")
        for (width, align) in zip(f[:widths], spec)
            literal(f, align in (:left, :center)  ? ":" : " ")
            literal(f, "-"^width)
            literal(f, align in (:center, :right) ? ":" : " ")
            literal(f, "|")
        end
        cr(f)
    end
    return nothing
end

markdown(::TableBody, ::Fmt, ::Node, ::Bool) = nothing

function markdown(::TableRow, f::Fmt, ::Node, enter::Bool)
    if enter
        print_margin(f)
        literal(f, "| ")
    else
        literal(f, " |")
        cr(f)
    end
    return nothing
end

function markdown(cell::TableCell, f::Fmt, n::Node, enter::Bool)
    if !enter && haskey(f.state, :widths)
        padding = f[:widths][cell.column] - f[:cells][n]
        literal(f, " "^padding)
        isnull(n.nxt) || literal(f, " | ")
    end
    return nothing
end

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
