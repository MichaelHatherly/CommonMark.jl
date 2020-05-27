struct ColumnSpec
    first::Int
    last::Int
    align::Symbol
end

abstract type TableComponent <: AbstractBlock end

is_container(::TableComponent) = true
accepts_lines(::TableComponent) = false
finalize(table::TableComponent, parser::Parser, node::Node) = nothing
can_contain(::TableComponent, ::Any) = false

struct Table <: TableComponent
    spec::Vector{ColumnSpec}
    ansi_widths::Vector{Int}

    Table(spec) = new(spec, [])
end

continue_(table::Table, parser::Parser, container::Node) = 0

struct TableHeader <: TableComponent
end

struct TableBody <: TableComponent
end

continue_(table::TableBody, parser::Parser, container::Node) = 1

struct TableRow <: TableComponent
end

struct TableCell <: TableComponent
    align::Symbol
    header::Bool
    column::Int
end

contains_inlines(::TableCell) = true

# TODO: currently requires strict aligment for columns. Do we
# actually want to relax that?
function gfm_table(parser::Parser, container::Node)
    if !parser.indented
        if container.t isa Paragraph
            header = container.string_content
            spec_str = SubString(parser.current_line, parser.next_nonspace)
            if valid_table_spec(spec_str)
                # Parse the table spec line.
                spec = parse_table_spec(spec_str)
                table = Node(Table(spec), container.sourcepos)
                # Build header row with cells for each column.
                head = Node(TableHeader(), container.sourcepos)
                append_child(table, head)
                row = Node(TableRow(), container.sourcepos)
                append_child(head, row)
                width = length(header)
                for (column, each) in enumerate(spec)
                    cell = Node(TableCell(each.align, true, column), container.sourcepos)
                    cell.string_content = SubString(header, min(each.first, width), min(each.last, width))
                    append_child(row, cell)
                end
                # Insert the empty body for the table.
                body = Node(TableBody(), container.sourcepos)
                append_child(table, body)
                # Splice the newly created table in place of the paragraph.
                insert_after(container, table)
                unlink(container)
                parser.tip = table
                advance_offset(parser, length(parser.current_line) - parser.offset + 1, false)
                return 2
            end
        end
        if container.t isa Table
            line = SubString(parser.current_line, parser.next_nonspace)
            if valid_table_row(line)
                row = Node(TableRow(), container.sourcepos)
                append_child(container.last_child, row)
                width = length(line)
                for (column, each) in enumerate(container.t.spec)
                    cell = Node(TableCell(each.align, false, column), container.sourcepos)
                    cell.string_content = SubString(line, min(each.first, width), min(each.last, width))
                    append_child(row, cell)
                end
                advance_offset(parser, length(parser.current_line) - parser.offset + 1, false)
                return 2
            end
        end
    end
    return 0
end

valid_table_row(str) = startswith(str, '|') && endswith(str, '|')
valid_table_spec(str) = !occursin(r"[^\|:\- ]", str)

function parse_table_spec(str)
    map(eachmatch(r"\|([: ][-]+[ :])\|", str; overlap=true)) do match
        str = match[1]
        left, right = str[1] === ':', str[end] === ':'
        center = left && right
        align = center ? :center : right ? :right : :left
        last = str.offset + str.ncodeunits
        return ColumnSpec(str.offset+1, last, align)
    end
end

struct TableRule end
block_rule(::TableRule) = Rule(gfm_table, 0.5, "|")

#
# Writers
#

# HTML

html(::Table, rend, node, enter) = tag(rend, enter ? "table" : "/table")
html(::TableHeader, rend, node, enter) = tag(rend, enter ? "thead" : "/thead")
html(::TableBody, rend, node, enter) = tag(rend, enter ? "tbody" : "/tbody")
html(::TableRow, rend, node, enter) = tag(rend, enter ? "tr" : "/tr")

function html(cell::TableCell, rend, node, enter)
    tag_name = cell.header ? "th" : "td"
    tag(rend, enter ? "$tag_name align=\"$(cell.align)\"" : "/$tag_name")
end

# LaTeX

function latex(table::Table, rend, node, enter)
    if enter
        print(rend.buffer, "\\begin{longtable}[]{@{}")
        join(rend.buffer, ("$(col.align)"[1] for col in table.spec))
        println(rend.buffer, "@{}}")
    else
        println(rend.buffer, "\\end{longtable}")
    end
end

function latex(::TableHeader, rend, node, enter)
    if enter
        println(rend.buffer, "\\toprule")
    else
        println(rend.buffer, "\\midrule")
        println(rend.buffer, "\\endhead")
    end
end

function latex(::TableBody, rend, node, enter)
    if !enter
        println(rend.buffer, "\\bottomrule")
    end
end

function latex(::TableRow, rend, node, enter)
    enter ? nothing : println(rend.buffer, "\\tabularnewline")
end

function latex(::TableCell, rend, node, enter)
    if !enter && node.parent.last_child !== node
        print(rend.buffer, " & ")
    end
end

# Term

function term(table::Table, rend, node, enter)
    if enter
        # Calculate the maximum column widths.
        if isempty(table.ansi_widths)
            columns = zeros(length(table.spec))
            index = 0
            for (n, enter) in node
                if enter
                    if n.t isa TableRow
                        index = 0
                    elseif n.t isa TableCell
                        index += 1
                        width = literal_width(n)
                        columns[index] = max(columns[index], width)
                    end
                end
            end
            append!(table.ansi_widths, columns)
        end
        print_margin(rend)
        print(rend.format.buffer, "┏━")
        join(rend.format.buffer, ("━"^w for w in table.ansi_widths), "━┯━")
        println(rend.format.buffer, "━┓")
    else
        print_margin(rend)
        print(rend.format.buffer, "┗━")
        join(rend.format.buffer, ("━"^w for w in table.ansi_widths), "━┷━")
        println(rend.format.buffer, "━┛")
    end
end

function term(::TableHeader, rend, node, enter)
    if enter
    else
        print_margin(rend)
        print(rend.format.buffer, "┠─")
        join(rend.format.buffer, ("─"^w for w in node.parent.t.ansi_widths), "─┼─")
        println(rend.format.buffer, "─┨")
    end
end

function term(::TableBody, rend, node, enter)
    # Nothing needed here for rendering.
end

function term(::TableRow, rend, node, enter)
    if enter
        print_margin(rend)
        print(rend.format.buffer, "┃ ")
    else
        println(rend.format.buffer, " ┃")
    end
end

function term(cell::TableCell, rend, node, enter)
    maxwidth = node.parent.parent.parent.t.ansi_widths[cell.column]
    pad = maxwidth - literal_width(node)
    if enter
        if cell.align == :left
        elseif cell.align == :right
            print(rend.format.buffer, ' '^pad)
        elseif cell.align == :center
            left = Int(round(pad/2, RoundDown))
            print(rend.format.buffer, ' '^left)
        end
    else
        if cell.align == :left
            print(rend.format.buffer, ' '^pad)
        elseif cell.align == :right
        elseif cell.align == :center
            right = Int(round(pad/2, RoundUp))
            print(rend.format.buffer, ' '^right)
        end
        if !isnull(node.nxt)
            print(rend.format.buffer, " │ ")
        end
    end
end
