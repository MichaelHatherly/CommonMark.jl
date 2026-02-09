"""
    GridTableRule()

Parse Pandoc-style grid tables with multi-line cells and block content.

Not enabled by default. Grid tables use `+` and `-` for borders and `|` for
column separators. Header rows use `=` instead of `-` in the separator.

```markdown
+-------+-------+
| Cell  | Cell  |
+=======+=======+
| Body  | Body  |
+-------+-------+
```

Supports alignment (`:` in separator) and multi-line cells with block
content (paragraphs, lists, code blocks).
"""
struct GridTableRule end

block_rule(::GridTableRule) = Rule(parse_grid_table, 7.5, "+")

"""Grid table container. Same children as Table (TableHeader, TableBody, TableFoot, TableRow, TableCell)."""
struct GridTable <: TableComponent
    spec::Vector{Symbol}
    col_widths::Vector{Float64}
end

const re_grid_border = r"^\+[-=:]+(\+[-=:]+)*\+\s*$"

function parse_grid_table(parser::Parser, container::Node)
    parser.indented && return 0

    line = rest_from_nonspace(parser)
    occursin(re_grid_border, line) || return 0

    close_unmatched_blocks(parser)
    add_child(parser, _GridTableCollector(), parser.next_nonspace)
    advance_next_nonspace(parser)
    return 2
end

# Intermediate collector — not part of the public AST.
struct _GridTableCollector <: AbstractBlock end

accepts_lines(::_GridTableCollector) = true
can_contain(::_GridTableCollector, t) = false
is_container(::_GridTableCollector) = false

function continue_(::_GridTableCollector, parser::Parser, container::Node)
    line = SubString(parser.buf, parser.pos)
    stripped = strip(line)
    if !isempty(stripped) && (startswith(stripped, '|') || startswith(stripped, '+'))
        return 0
    end
    return 1
end

function finalize(::_GridTableCollector, parser::Parser, block::Node)
    finalize_literal!(block)
    lines = split(block.literal, '\n'; keepempty = false)
    if !isempty(lines)
        table_node = _build_grid_table(parser, lines)
        if table_node !== nothing
            # Mark all nodes as closed so the block parser doesn't try to
            # continue into them on subsequent lines.
            for (node, entering) in table_node
                entering && (node.is_open = false)
            end
            insert_after(block, table_node)
        end
    end
    unlink(block)
    return nothing
end

# --- Parser internals ---

# A full border starts with + and matches re_grid_border.
_is_full_border(line) = occursin(re_grid_border, strip(line))

function _build_grid_table(parser::Parser, lines::AbstractVector)
    # Step 1: Find finest column grid from ALL lines.
    col_set = Set{Int}()
    for line in lines
        stripped = strip(line)
        if _is_full_border(line)
            union!(col_set, findall(c -> c == '+', line))
        else
            for pos in findall(c -> c == '+', line)
                if pos < lastindex(line) && line[pos+1] in ('-', '=', ':')
                    push!(col_set, pos)
                end
            end
        end
    end
    col_positions = sort!(collect(col_set))
    length(col_positions) < 2 && return nothing
    ncols = length(col_positions) - 1

    # Find the first border that has ALL fine-grid positions for alignment/spec.
    spec_border = ""
    for line in lines
        _is_full_border(line) || continue
        has_all = all(p -> p <= lastindex(line) && line[p] == '+', col_positions)
        if has_all
            spec_border = line
            break
        end
    end
    isempty(spec_border) && (spec_border = lines[1])

    spec, col_widths = _parse_grid_spec(spec_border, col_positions)

    # Step 2: Classify lines into row groups separated by full borders
    # that have + at ALL fine-grid positions.
    sections = Vector{Vector{String}}()
    separators = String[string(strip(lines[1]))]
    current_section = String[]

    for i = 2:length(lines)
        line = lines[i]
        stripped = strip(line)
        if _is_full_border(line) &&
           all(p -> p <= lastindex(line) && line[p] == '+', col_positions)
            push!(sections, current_section)
            push!(separators, string(stripped))
            current_section = String[]
        else
            push!(current_section, string(line))
        end
    end

    isempty(sections) && return nothing

    has_header = length(separators) >= 2 && occursin('=', separators[2])
    has_footer = length(separators) > 2 && occursin('=', separators[end])
    if has_header && has_footer && length(sections) == 1
        has_footer = false
    end

    table = Node(GridTable(spec, col_widths))
    header_end = has_header ? 1 : 0
    footer_start = has_footer ? length(sections) : length(sections) + 1

    if has_header
        head = Node(TableHeader())
        append_child(table, head)
        _parse_row_group!(
            parser,
            head,
            sections[1],
            separators[1],
            col_positions,
            spec,
            true,
        )
    end

    body_start = header_end + 1
    body_end = footer_start - 1
    if body_start <= body_end
        body = Node(TableBody())
        append_child(table, body)
        for i = body_start:body_end
            _parse_row_group!(
                parser,
                body,
                sections[i],
                separators[i],
                col_positions,
                spec,
                false,
            )
        end
    end

    if has_footer
        foot = Node(TableFoot())
        append_child(table, foot)
        _parse_row_group!(
            parser,
            foot,
            sections[footer_start],
            separators[footer_start],
            col_positions,
            spec,
            false,
        )
    end

    return table
end

function _parse_grid_spec(border::AbstractString, col_positions::Vector{Int})
    ncols = length(col_positions) - 1
    spec = Vector{Symbol}(undef, ncols)
    widths = Vector{Float64}(undef, ncols)
    total = 0.0

    for i = 1:ncols
        start = col_positions[i] + 1
        stop = col_positions[i+1] - 1
        if stop >= start && stop <= lastindex(border)
            seg = SubString(border, start, stop)
            left = startswith(seg, ':')
            right = endswith(seg, ':')
            spec[i] = (left && right) ? :center : right ? :right : :left
        else
            spec[i] = :left
        end
        widths[i] = Float64(max(stop - start + 1, 1))
        total += widths[i]
    end
    total > 0 && (widths ./= total)
    return spec, widths
end

# Check if a content line is a partial border (contains + grid markers not at all positions).
function _is_partial_border(line, col_positions)
    _is_full_border(line) && return false
    for pos in col_positions[2:end-1]
        if pos <= lastindex(line) &&
           line[pos] == '+' &&
           pos < lastindex(line) &&
           line[pos+1] in ('-', '=', ':')
            return true
        end
    end
    return false
end

# Detect which fine-grid column boundary positions have + in a partial border line.
function _partial_border_positions(line, col_positions)
    positions = Set{Int}()
    for pos in col_positions
        if pos <= lastindex(line) && line[pos] == '+'
            push!(positions, pos)
        end
    end
    return positions
end

"""
Parse a row group (content lines between two full borders) into TableRow nodes.
Handles colspan via missing + in borders and rowspan via partial borders.
`border_above` is the separator line above this row group.
"""
# Split content lines into sub-groups separated by partial border lines.
function _split_by_partial_borders(content_lines, col_positions)
    sub_groups = Vector{Vector{String}}()
    partial_borders = Vector{String}()
    current = String[]
    for line in content_lines
        if _is_partial_border(line, col_positions)
            push!(sub_groups, current)
            push!(partial_borders, line)
            current = String[]
        else
            push!(current, line)
        end
    end
    push!(sub_groups, current)
    return sub_groups, partial_borders
end

# Emit a rowspan group: multiple sub-rows with colspan/rowspan detection.
function _emit_rowspan_group!(
    parser,
    parent,
    sub_groups,
    partial_borders,
    border_above,
    col_positions,
    spec,
    is_header,
)
    ncols = length(col_positions) - 1
    n_sub = length(sub_groups)

    sub_row_cells = Vector{Vector{NamedTuple{(:col, :colspan),Tuple{Int,Int}}}}()

    above_plus = _partial_border_positions(border_above, col_positions)
    push!(sub_row_cells, _detect_colspan_from_plus(col_positions, above_plus))

    for k = 2:n_sub
        border_plus = _partial_border_positions(partial_borders[k-1], col_positions)
        push!(sub_row_cells, _detect_colspan_from_plus(col_positions, border_plus))
    end

    # Build an occupation grid and cell registry for rowspan merging.
    cell_registry =
        NamedTuple{(:col, :colspan, :rowspan, :sub_rows),Tuple{Int,Int,Int,Vector{Int}}}[]
    occupied = [zeros(Int, ncols) for _ = 1:n_sub]

    for sr = 1:n_sub
        for cell_def in sub_row_cells[sr]
            col, cspan = cell_def.col, cell_def.colspan
            occupied[sr][col] != 0 && continue
            rspan = 1
            for next_sr = sr+1:n_sub
                pb = partial_borders[next_sr-1]
                left_pos = col_positions[col]
                if left_pos <= lastindex(pb) && pb[left_pos] == '+'
                    break
                end
                rspan += 1
            end
            cell_id = length(cell_registry) + 1
            push!(
                cell_registry,
                (
                    col = col,
                    colspan = cspan,
                    rowspan = rspan,
                    sub_rows = collect(sr:sr+rspan-1),
                ),
            )
            for osr = sr:sr+rspan-1
                for c = col:col+cspan-1
                    occupied[osr][c] = cell_id
                end
            end
        end
    end

    group = Node(TableRows())
    append_child(parent, group)

    cell_nodes = Vector{Node}(undef, length(cell_registry))
    for (cell_id, cell_def) in enumerate(cell_registry)
        col, cspan, rspan = cell_def.col, cell_def.colspan, cell_def.rowspan
        cell_lines = String[]
        for sr in cell_def.sub_rows
            append!(
                cell_lines,
                _extract_cell_lines(sub_groups[sr], col_positions, col, cspan),
            )
        end
        cell_content = _strip_cell_padding(cell_lines)
        align = col <= length(spec) ? spec[col] : :left
        cell_node = Node(TableCell(align, is_header, col, rspan, cspan))
        _parse_cell_content!(parser, cell_node, cell_content)
        cell_nodes[cell_id] = cell_node
    end

    for sr = 1:n_sub
        row = Node(TableRow())
        append_child(group, row)
        for (cell_id, cell_def) in enumerate(cell_registry)
            cell_def.sub_rows[1] == sr || continue
            append_child(row, cell_nodes[cell_id])
        end
    end
end

function _parse_row_group!(
    parser,
    parent,
    content_lines,
    border_above,
    col_positions,
    spec,
    is_header,
)
    isempty(content_lines) && return

    sub_groups, partial_borders = _split_by_partial_borders(content_lines, col_positions)

    if length(sub_groups) == 1
        above_plus = _partial_border_positions(border_above, col_positions)
        _emit_row!(
            parser,
            parent,
            sub_groups[1],
            col_positions,
            above_plus,
            spec,
            is_header,
        )
    else
        _emit_rowspan_group!(
            parser,
            parent,
            sub_groups,
            partial_borders,
            border_above,
            col_positions,
            spec,
            is_header,
        )
    end
end

# Extract cell content lines from raw grid lines for the given column span.
function _extract_cell_lines(lines, col_positions, col, cspan)
    start_col = col_positions[col] + 1
    stop_col = col_positions[col+cspan] - 1
    cell_lines = String[]
    for line in lines
        if start_col <= lastindex(line)
            s = min(stop_col, lastindex(line))
            push!(cell_lines, string(SubString(line, start_col, s)))
        else
            push!(cell_lines, "")
        end
    end
    return cell_lines
end

# Detect colspan from a set of + positions in a border line.
function _detect_colspan_from_plus(col_positions, plus_set::Set{Int})
    ncols = length(col_positions) - 1
    cells = NamedTuple{(:col, :colspan),Tuple{Int,Int}}[]
    col = 1
    while col <= ncols
        span = 1
        while col + span <= ncols
            pos = col_positions[col+span]
            pos in plus_set && break
            span += 1
        end
        push!(cells, (col = col, colspan = span))
        col += span
    end
    return cells
end

# Emit a single row with colspan detection (no partial borders / no rowspan).
function _emit_row!(
    parser,
    parent,
    content_lines,
    col_positions,
    above_plus,
    spec,
    is_header,
)
    isempty(content_lines) && return

    cells = _detect_colspan_from_plus(col_positions, above_plus)

    row = Node(TableRow())
    append_child(parent, row)

    for cell_def in cells
        col, cspan = cell_def.col, cell_def.colspan
        cell_lines = _extract_cell_lines(content_lines, col_positions, col, cspan)

        cell_content = _strip_cell_padding(cell_lines)
        align = col <= length(spec) ? spec[col] : :left
        cell_node = Node(TableCell(align, is_header, col, 1, cspan))
        _parse_cell_content!(parser, cell_node, cell_content)
        append_child(row, cell_node)
    end
end

function _parse_cell_content!(parser, cell_node, cell_content)
    isempty(strip(cell_content)) && return
    sub_parser = Parser()
    for rule in parser.rules
        ruleoccursin(rule, sub_parser.rules) && continue
        enable!(sub_parser, rule)
    end
    sub_doc = sub_parser(cell_content)
    child = sub_doc.first_child
    while !isnull(child)
        nxt = child.nxt
        append_child(cell_node, child)
        child = nxt
    end
end

function _strip_cell_padding(lines::Vector{String})
    stripped = map(lines) do line
        s = startswith(line, ' ') ? SubString(line, 2) : line
        string(rstrip(s))
    end
    while !isempty(stripped) && isempty(strip(stripped[end]))
        pop!(stripped)
    end
    while !isempty(stripped) && isempty(strip(stripped[1]))
        popfirst!(stripped)
    end
    return join(stripped, '\n')
end

# --- Writers ---

# Term

function write_term(gt::GridTable, rend, node, enter)
    if enter
        _write_grid_table_term(rend, node, gt)
        rend.context[:_saved_term_buffer] = rend.format.buffer
        rend.format.buffer = IOBuffer()
    else
        rend.format.buffer = rend.context[:_saved_term_buffer]
        delete!(rend.context, :_saved_term_buffer)
    end
    return nothing
end

# Render a cell's children via term(), returning lines.
# When wrap_width > 0, constrains paragraph word-wrapping to that width.
function _render_term_cell(cell_node::Node, wrap_width::Int = -1)
    buf = IOBuffer()
    child = cell_node.first_child
    while !isnull(child)
        if wrap_width > 0
            child_buf = IOBuffer()
            sized_io = IOContext(child_buf, :displaysize => (24, wrap_width))
            show(sized_io, MIME"text/plain"(), child)
            write(buf, take!(child_buf))
        else
            write(buf, term(child))
        end
        child = child.nxt
    end
    text = rstrip(String(take!(buf)))
    lines = split(text, '\n')
    isempty(lines) && return String[""]
    result = String.(lines)
    if !isnull(cell_node.first_child) && all(isempty ∘ strip, result)
        return String["…"]
    end
    return result
end

# Write a term border line with directional junctions.
# `bounds_above`/`bounds_below` are sets of column indices where cell boundaries exist
# in the row above/below. Junction char is chosen based on which sides have boundaries.
function _write_term_border(
    rend,
    col_widths,
    bounds_above,
    bounds_below,
    ncols,
    left,
    fill,
    junc_cross,
    junc_down,
    junc_up,
    right,
)
    print_margin(rend)
    buf = rend.format.buffer
    print(buf, left, fill)
    for i = 1:ncols
        print(buf, fill^col_widths[i])
        if i < ncols
            above = (i + 1) in bounds_above
            below = (i + 1) in bounds_below
            if above && below
                print(buf, fill, junc_cross, fill)
            elseif below
                print(buf, fill, junc_down, fill)
            elseif above
                print(buf, fill, junc_up, fill)
            else
                print(buf, fill^3)
            end
        end
    end
    println(buf, fill, right)
end

# Write a partial border between visual sub-rows.
# Each line matches content line structure: LEFT COL1 SEP COL2 SEP ... COLn RIGHT
# where LEFT=2chars, SEP=3chars, RIGHT=2chars, COLi=col_widths[i] chars.
# Junction characters depend on whether boundaries exist above and/or below:
#   above+below: ┼   below only: ┬   above only: ┴
function _write_term_partial_border(
    rend,
    col_widths,
    spanning_cols,
    cells_above,
    cells_below,
    ncols,
)
    bounds_above = _cell_boundaries(cells_above, ncols)
    bounds_below = _cell_boundaries(cells_below, ncols)
    print_margin(rend)
    buf = rend.format.buffer
    for i = 1:ncols
        span = spanning_cols[i]
        fill_char = span ? ' ' : '─'
        above = i in bounds_above
        below = i in bounds_below
        # Left edge / separator before this column
        if i == 1
            print(buf, span ? "┃" : "┠", fill_char)
        else
            prev_span = spanning_cols[i-1]
            if prev_span && span
                print(buf, "   ")
            elseif prev_span && !span
                # Transition from spanning to non-spanning
                junction = above ? "├" : "┌"
                print(buf, " ", junction, fill_char)
            elseif !prev_span && span
                junction = above ? "┤" : "┐"
                print(buf, "─", junction, " ")
            else
                # Both non-spanning: junction type depends on boundaries
                if above && below
                    print(buf, "─┼", fill_char)
                elseif below
                    print(buf, "─┬", fill_char)
                elseif above
                    print(buf, "─┴", fill_char)
                else
                    print(buf, "──", fill_char)
                end
            end
        end
        # Column content area
        print(buf, string(fill_char)^col_widths[i])
        # Right edge after last column
        if i == ncols
            if span
                println(buf, " ┃")
            else
                println(buf, "─┨")
            end
        end
    end
end

# Pre-render all term cells, computing column widths from content.
function _prerender_term_cells(rend, table_node, gt::GridTable)
    spec = gt.spec
    ncols = length(spec)

    overhead = 3 * ncols + 1
    budget = available_columns(rend) - overhead
    target_widths = if budget >= ncols
        _allocate_column_widths(gt.col_widths, budget, ncols)
    else
        fill(max(1, fld(budget, ncols)), ncols)
    end

    rendered = Dict{Node,Vector{String}}()
    col_widths = fill(1, ncols)

    for (n, ent) in table_node
        if ent && n.t isa TableCell
            tc = n.t
            cell_target = if tc.colspan == 1 && tc.column <= ncols
                target_widths[tc.column]
            elseif tc.colspan > 1 && tc.column + tc.colspan - 1 <= ncols
                tw =
                    sum(target_widths[tc.column:tc.column+tc.colspan-1]) +
                    3 * (tc.colspan - 1)
                tw > 0 ? tw : -1
            else
                -1
            end
            lines = _render_term_cell(n, cell_target)
            rendered[n] = lines
            max_w = mapreduce(_term_visible_length, max, lines; init = 0)
            if tc.colspan == 1 && tc.column <= ncols
                col_widths[tc.column] = max(col_widths[tc.column], max_w)
            end
        end
    end

    _redistribute_spanning_widths!(col_widths, table_node, rendered, _term_visible_length)
    return rendered, col_widths
end

function _write_grid_table_term(rend, table_node, gt::GridTable)
    ncols = length(gt.spec)
    rendered, col_widths = _prerender_term_cells(rend, table_node, gt)

    group_data = _collect_row_groups(table_node)
    isempty(group_data) && return

    for (grp_idx, g) in enumerate(group_data)
        subrows, after_header, before_footer = g.subrows, g.after_header, g.before_footer
        cell_subrow_lines = _distribute_rowspan_lines(subrows, rendered)

        for (sr_idx, sr_cells) in enumerate(subrows)
            active_cells = _get_active_cells_for_subrow(subrows, sr_idx, ncols)

            # Top border for first sub-row of first group.
            if grp_idx == 1 && sr_idx == 1
                bounds = _cell_boundaries(active_cells, ncols)
                _write_term_border(
                    rend,
                    col_widths,
                    Set{Int}(),
                    bounds,
                    ncols,
                    "┏",
                    "━",
                    "┯",
                    "┯",
                    "┯",
                    "┓",
                )
            end

            max_lines = 1
            for cell in active_cells
                max_lines = max(
                    max_lines,
                    length(
                        _get_cell_lines(cell, sr_idx, cell_subrow_lines, rendered, subrows),
                    ),
                )
            end

            for line_idx = 1:max_lines
                print_margin(rend)
                for (ci, cell) in enumerate(active_cells)
                    col = cell.t.column
                    cspan = cell.t.colspan
                    width = _spanning_width(col_widths, col, cspan)
                    lines =
                        _get_cell_lines(cell, sr_idx, cell_subrow_lines, rendered, subrows)
                    cell_line = line_idx <= length(lines) ? lines[line_idx] : ""
                    vis_len = _term_visible_length(cell_line)
                    pad = width - vis_len

                    # Left border
                    if ci == 1
                        print(rend.format.buffer, "┃ ")
                    else
                        print(rend.format.buffer, " │ ")
                    end
                    print(rend.format.buffer, cell_line, " "^max(pad, 0))
                end
                println(rend.format.buffer, " ┃")
            end

            # Partial border between sub-rows.
            if sr_idx < length(subrows)
                next_occupied, next_sr_cells =
                    _compute_partial_border_info(active_cells, subrows, sr_idx, ncols)
                _write_term_partial_border(
                    rend,
                    col_widths,
                    next_occupied,
                    active_cells,
                    next_sr_cells,
                    ncols,
                )
            end
        end

        # Full border after group.
        last_subrow_cells = _get_active_cells_for_subrow(subrows, length(subrows), ncols)
        if grp_idx < length(group_data)
            next_subrows = group_data[grp_idx+1][1]
            next_first_cells = next_subrows[1]
            bounds_above = _cell_boundaries(last_subrow_cells, ncols)
            bounds_below = _cell_boundaries(next_first_cells, ncols)
            if after_header || before_footer
                _write_term_border(
                    rend,
                    col_widths,
                    bounds_above,
                    bounds_below,
                    ncols,
                    "┣",
                    "━",
                    "┿",
                    "┯",
                    "┷",
                    "┫",
                )
            else
                _write_term_border(
                    rend,
                    col_widths,
                    bounds_above,
                    bounds_below,
                    ncols,
                    "┠",
                    "─",
                    "┼",
                    "┬",
                    "┴",
                    "┨",
                )
            end
        else
            bounds = _cell_boundaries(last_subrow_cells, ncols)
            _write_term_border(
                rend,
                col_widths,
                bounds,
                Set{Int}(),
                ncols,
                "┗",
                "━",
                "┷",
                "┷",
                "┷",
                "┛",
            )
        end
    end
end

# Markdown: render entire grid table, suppressing child traversal.

function write_markdown(gt::GridTable, w, node, enter)
    if enter
        _write_grid_table_markdown(w, node, gt)
        w.enabled = false
    else
        w.enabled = true
        linebreak(w, node)
    end
    return nothing
end

# --- Shared writer helpers ---

# Redistribute excess width from spanning cells into col_widths.
# `width_fn` measures a line's display width (e.g. `length` or `_term_visible_length`).
function _redistribute_spanning_widths!(col_widths, table_node, rendered, width_fn)
    for (n, ent) in table_node
        if ent && n.t isa TableCell && n.t.colspan > 1
            max_w = mapreduce(width_fn, max, get(rendered, n, String[""]); init = 0)
            tc = n.t
            combined = _spanning_width(col_widths, tc.column, tc.colspan)
            if max_w > combined
                excess = max_w - combined
                per_col = cld(excess, tc.colspan)
                for c = tc.column:tc.column+tc.colspan-1
                    col_widths[c] += per_col
                end
            end
        end
    end
end

# Distribute rendered lines across sub-rows for rowspan cells.
function _distribute_rowspan_lines(subrows, rendered)
    all_cells = _flatten_subrows(subrows)
    cell_subrow_lines = Dict{Node,Vector{Vector{String}}}()
    for cell in all_cells
        tc = cell.t
        lines = get(rendered, cell, String[""])
        if tc.rowspan > 1
            n_visual = tc.rowspan
            lines_per = cld(length(lines), n_visual)
            dist = Vector{Vector{String}}()
            for sr = 1:n_visual
                start_l = (sr - 1) * lines_per + 1
                end_l = min(sr * lines_per, length(lines))
                if start_l <= length(lines)
                    push!(dist, lines[start_l:end_l])
                else
                    push!(dist, String[""])
                end
            end
            cell_subrow_lines[cell] = dist
        end
    end
    return cell_subrow_lines
end

# Get lines for a cell at a given sub-row index, handling rowspan distribution.
function _get_cell_lines(cell, sr_idx, cell_subrow_lines, rendered, subrows)
    if haskey(cell_subrow_lines, cell)
        dist = cell_subrow_lines[cell]
        cell_sr = sr_idx - _cell_start_subrow(cell, subrows) + 1
        if cell_sr >= 1 && cell_sr <= length(dist)
            return dist[cell_sr]
        end
        return String[""]
    else
        return get(rendered, cell, String[""])
    end
end

# Compute spanning columns and next-row cells for partial borders between sub-rows.
function _compute_partial_border_info(active_cells, subrows, sr_idx, ncols)
    next_occupied = falses(ncols)
    for cell in active_cells
        tc = cell.t
        cell_start = _cell_start_subrow(cell, subrows)
        if cell_start + tc.rowspan - 1 > sr_idx
            col_range = tc.column:tc.column+tc.colspan-1
            next_occupied[col_range] .= true
        end
    end
    next_sr_cells = Node[]
    for cell in subrows[sr_idx+1]
        col_range = cell.t.column:cell.t.column+cell.t.colspan-1
        if !any(next_occupied[col_range])
            push!(next_sr_cells, cell)
        end
    end
    sort!(next_sr_cells; by = c -> c.t.column)
    return next_occupied, next_sr_cells
end

# Compute the effective width of a spanning cell: sum of spanned column widths
# plus separator space absorbed (3 chars per internal separator: " | ").
function _spanning_width(col_widths, col, colspan)
    w = 0
    for i = col:col+colspan-1
        w += col_widths[i]
    end
    w += 3 * (colspan - 1)
    return w
end

# Distribute `budget` columns among `ncols` using floor-then-distribute.
# Guarantees sum(result) == budget exactly.
function _allocate_column_widths(proportions::Vector{Float64}, budget::Int, ncols::Int)
    widths = Vector{Int}(undef, ncols)
    for i = 1:ncols
        widths[i] = max(1, floor(Int, proportions[i] * budget))
    end
    remainder = budget - sum(widths)
    fracs = [proportions[i] * budget - floor(proportions[i] * budget) for i = 1:ncols]
    order = sortperm(fracs; rev = true)
    for i = 1:min(remainder, ncols)
        widths[order[i]] += 1
    end
    return widths
end

function _collect_row_cells(row_node)
    cells = Node[]
    c = row_node.first_child
    while !isnull(c)
        push!(cells, c)
        c = c.nxt
    end
    return cells
end

# Collect sub-rows from a TableRows grouping node.
function _collect_tablerows_subrows(tablerows_node)
    subrows = Vector{Vector{Node}}()
    row = tablerows_node.first_child
    while !isnull(row)
        push!(subrows, _collect_row_cells(row))
        row = row.nxt
    end
    return subrows
end

# Collect row groups from a grid table, yielding per-group metadata.
# Returns Vector of (subrows, is_header, after_header, before_footer, is_footer).
function _collect_row_groups(table_node)
    groups = NamedTuple{
        (:subrows, :is_header, :after_header, :before_footer, :is_footer),
        Tuple{Vector{Vector{Node}},Bool,Bool,Bool,Bool},
    }[]
    child = table_node.first_child
    while !isnull(child)
        section = child
        is_header = section.t isa TableHeader
        is_foot = section.t isa TableFoot
        entry = section.first_child
        while !isnull(entry)
            is_last_in_section = isnull(entry.nxt)
            subrows = if entry.t isa TableRows
                _collect_tablerows_subrows(entry)
            else
                [_collect_row_cells(entry)]
            end
            after_header = is_last_in_section && is_header
            before_footer =
                is_last_in_section &&
                !is_foot &&
                !isnull(child.nxt) &&
                child.nxt.t isa TableFoot
            push!(
                groups,
                (
                    subrows = subrows,
                    is_header = is_header,
                    after_header = after_header,
                    before_footer = before_footer,
                    is_footer = is_foot,
                ),
            )
            entry = entry.nxt
        end
        child = child.nxt
    end
    return groups
end

# Flatten sub-rows into a single cell list.
function _flatten_subrows(subrows)
    cells = Node[]
    for sr in subrows
        append!(cells, sr)
    end
    return cells
end

function _render_grid_cell(cell_node::Node)
    buf = IOBuffer()
    child = cell_node.first_child
    while !isnull(child)
        write(buf, markdown(child))
        child = child.nxt
    end
    text = rstrip(String(take!(buf)))
    lines = split(text, '\n')
    isempty(lines) && return String[""]
    return String.(lines)
end

# Build the set of fine-column boundary indices where cells start/end.
function _cell_boundaries(cells, ncols)
    bounds = Set{Int}()
    push!(bounds, 1)
    for cell in cells
        push!(bounds, cell.t.column)
        push!(bounds, cell.t.column + cell.t.colspan)
    end
    push!(bounds, ncols + 1)
    return bounds
end

function _write_grid_table_markdown(w, table_node, gt::GridTable)
    spec = gt.spec
    ncols = length(spec)

    # Pre-render all cells and collect per-fine-column width requirements.
    rendered = Dict{Node,Vector{String}}()
    col_widths = fill(3, ncols)

    for (n, ent) in table_node
        if ent && n.t isa TableCell
            lines = _render_grid_cell(n)
            rendered[n] = lines
            max_w = mapreduce(length, max, lines; init = 0)
            tc = n.t
            if tc.colspan == 1 && tc.column <= ncols
                col_widths[tc.column] = max(col_widths[tc.column], max_w)
            end
        end
    end

    _redistribute_spanning_widths!(col_widths, table_node, rendered, length)

    raw_groups = _collect_row_groups(table_node)
    isempty(raw_groups) && return

    # Derive separator char per group: '=' at section boundaries, '-' elsewhere.
    group_data = map(raw_groups) do g
        sep = (g.is_header || g.before_footer || g.is_footer) ? '=' : '-'
        (g.subrows, sep)
    end

    for (grp_idx, (subrows, sep)) in enumerate(group_data)
        cell_subrow_lines = _distribute_rowspan_lines(subrows, rendered)

        for (sr_idx, sr_cells) in enumerate(subrows)
            active_cells = _get_active_cells_for_subrow(subrows, sr_idx, ncols)

            # Top border for first sub-row of first group.
            if grp_idx == 1 && sr_idx == 1
                _write_grid_border_for_cells(
                    w,
                    col_widths,
                    spec,
                    '-',
                    active_cells,
                    ncols;
                    align = true,
                )
            end

            max_lines = 1
            for cell in active_cells
                max_lines = max(
                    max_lines,
                    length(
                        _get_cell_lines(cell, sr_idx, cell_subrow_lines, rendered, subrows),
                    ),
                )
            end

            for line_idx = 1:max_lines
                print_margin(w)
                for cell in active_cells
                    col = cell.t.column
                    cspan = cell.t.colspan
                    width = _spanning_width(col_widths, col, cspan)
                    lines =
                        _get_cell_lines(cell, sr_idx, cell_subrow_lines, rendered, subrows)
                    cell_line = line_idx <= length(lines) ? lines[line_idx] : ""
                    pad = width - length(cell_line)
                    literal(w, "| ", cell_line, " "^max(pad, 0), " ")
                end
                literal(w, "|")
                cr(w)
            end

            # Partial border between sub-rows.
            if sr_idx < length(subrows)
                next_occupied, next_sr_cells =
                    _compute_partial_border_info(active_cells, subrows, sr_idx, ncols)
                _write_grid_partial_border(
                    w,
                    col_widths,
                    '-',
                    next_occupied,
                    next_sr_cells,
                    ncols,
                )
            end
        end

        # Full border after group.
        last_subrow_cells = _get_active_cells_for_subrow(subrows, length(subrows), ncols)
        if grp_idx < length(group_data)
            next_subrows = group_data[grp_idx+1][1]
            next_first_cells = next_subrows[1]
            _write_grid_border_between_rows(
                w,
                col_widths,
                spec,
                sep,
                last_subrow_cells,
                next_first_cells,
                ncols,
            )
        else
            _write_grid_border_for_cells(w, col_widths, spec, sep, last_subrow_cells, ncols)
        end
    end
end

# Find which sub-row a cell starts in.
function _cell_start_subrow(cell, subrows)
    for (i, sr) in enumerate(subrows)
        if cell in sr
            return i
        end
    end
    return 1
end

# Get all active cells (including rowspan) for a given sub-row index.
function _get_active_cells_for_subrow(subrows, sr_idx, ncols)
    active = Node[]
    occupied = falses(ncols)
    for prev_sr = 1:sr_idx
        for cell in subrows[prev_sr]
            tc = cell.t
            cell_spans_here = (prev_sr == sr_idx) || (prev_sr + tc.rowspan - 1 >= sr_idx)
            if cell_spans_here
                col_range = tc.column:tc.column+tc.colspan-1
                if !any(occupied[col_range])
                    push!(active, cell)
                    occupied[col_range] .= true
                end
            end
        end
    end
    sort!(active; by = c -> c.t.column)
    return active
end

# Write a border line where cell boundaries determine + placement.
function _write_grid_border_for_cells(
    w,
    col_widths,
    spec,
    sep::Char,
    cells,
    ncols;
    align::Bool = false,
)
    bounds = _cell_boundaries(cells, ncols)
    has_all = align && length(bounds) == ncols + 1

    print_margin(w)
    s = string(sep)
    for i = 1:ncols
        if i in bounds
            literal(w, "+")
        else
            literal(w, s)
        end
        a = has_all && i <= length(spec) ? spec[i] : :left
        left_colon = has_all && a in (:left, :center)
        right_colon = has_all && a in (:right, :center)
        fill_len = col_widths[i] + 2 - left_colon - right_colon
        left_colon && literal(w, ":")
        literal(w, s^fill_len)
        right_colon && literal(w, ":")
    end
    literal(w, "+")
    cr(w)
end

# Write a border between two rows, merging cell boundaries from both.
function _write_grid_border_between_rows(
    w,
    col_widths,
    spec,
    sep::Char,
    cells_above,
    cells_below,
    ncols,
)
    bounds_above = _cell_boundaries(cells_above, ncols)
    bounds_below = _cell_boundaries(cells_below, ncols)
    bounds = union(bounds_above, bounds_below)

    print_margin(w)
    s = string(sep)
    for i = 1:ncols
        if i in bounds
            literal(w, "+")
        else
            literal(w, s)
        end
        literal(w, s^(col_widths[i] + 2))
    end
    literal(w, "+")
    cr(w)
end

# Write a partial border between sub-rows within the same row group.
# Rowspan cells from above that span past this border get | and spaces instead of + and ---.
function _write_grid_partial_border(
    w,
    col_widths,
    sep::Char,
    spanning_cols::BitVector,
    cells_below,
    ncols,
)
    bounds_below = _cell_boundaries(cells_below, ncols)

    print_margin(w)
    s = string(sep)
    for i = 1:ncols
        if spanning_cols[i]
            literal(w, "|")
            literal(w, " "^(col_widths[i] + 2))
        else
            if i in bounds_below
                literal(w, "+")
            else
                literal(w, s)
            end
            literal(w, s^(col_widths[i] + 2))
        end
    end
    literal(w, "+")
    cr(w)
end
