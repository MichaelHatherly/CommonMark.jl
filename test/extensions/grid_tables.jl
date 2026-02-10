@testitem "grid_tables" tags = [:extensions, :grid_tables] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_grid = test_all_formats(pwd())

    p = create_parser(GridTableRule())

    # Basic header + body
    text = """
           +-------+-------+
           | Head1 | Head2 |
           +=======+=======+
           | Body1 | Body2 |
           +-------+-------+
           """
    ast = p(text)
    test_grid("basic", ast, "grid_tables")

    # Markdown round-trip
    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Body-only (no header separator)
    text = """
           +-------+-------+
           | Left  | Right |
           +-------+-------+
           """
    ast = p(text)
    test_grid("body_only", ast, "grid_tables")

    # Multi-line cells
    text = """
           +----------+----------+
           | Line one | Single   |
           | Line two |          |
           +==========+==========+
           | Body     | Multi    |
           |          | line too |
           +----------+----------+
           """
    ast = p(text)
    test_grid("multiline", ast, "grid_tables")

    # Colspan header (Temperature table) with rowspan
    text = """
           +----------+----------------------+
           | Location | Temperature          |
           |          +------+------+--------+
           |          | min  | mean | max    |
           +==========+======+======+========+
           | Chicago  | -10  | 15   | 35     |
           +----------+------+------+--------+
           | Berlin   | -5   | 12   | 30     |
           +----------+------+------+--------+
           """
    ast = p(text)
    test_grid("colspan_header", ast, "grid_tables")

    # Verify AST structure: header → TableRows → 2 TableRows
    header = ast.first_child.first_child
    @test header.t isa CommonMark.TableHeader
    group = header.first_child
    @test group.t isa CommonMark.TableRows
    row1 = group.first_child
    row2 = row1.nxt
    @test row1.t isa CommonMark.TableRow
    @test row2.t isa CommonMark.TableRow

    # Row 1: Location (rs=2) + Temperature (cs=3)
    row1_cells = CommonMark.Node[]
    let n = row1.first_child
        while !CommonMark.isnull(n)
            push!(row1_cells, n)
            n = n.nxt
        end
    end
    @test length(row1_cells) == 2
    @test row1_cells[1].t.column == 1
    @test row1_cells[1].t.colspan == 1
    @test row1_cells[1].t.rowspan == 2
    @test row1_cells[2].t.column == 2
    @test row1_cells[2].t.colspan == 3
    @test row1_cells[2].t.rowspan == 1

    # Row 2: min, mean, max
    row2_cells = CommonMark.Node[]
    let n = row2.first_child
        while !CommonMark.isnull(n)
            push!(row2_cells, n)
            n = n.nxt
        end
    end
    @test length(row2_cells) == 3
    for (i, col) in enumerate(2:4)
        @test row2_cells[i].t.column == col
        @test row2_cells[i].t.colspan == 1
        @test row2_cells[i].t.rowspan == 1
    end

    # Colspan header round-trip
    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Simple colspan in body
    text = """
           +------+------+------+
           | A    | B    | C    |
           +------+------+------+
           | wide span   | solo |
           +------+------+------+
           """
    ast = p(text)
    test_grid("colspan_body", ast, "grid_tables")

    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Header + body + footer (enclosed = separators)
    text = """
           +-------+-------+
           | Head1 | Head2 |
           +=======+=======+
           | Body1 | Body2 |
           +=======+=======+
           | Foot1 | Foot2 |
           +=======+=======+
           """
    ast = p(text)
    test_grid("footer", ast, "grid_tables")

    # Verify footer AST structure
    let sections = CommonMark.Node[]
        n = ast.first_child.first_child
        while !CommonMark.isnull(n)
            push!(sections, n)
            n = n.nxt
        end
        @test sections[1].t isa CommonMark.TableHeader
        @test sections[2].t isa CommonMark.TableBody
        @test sections[3].t isa CommonMark.TableFoot
    end

    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Non-enclosed = at end should NOT create footer
    text = """
           +-------+-------+
           | Head1 | Head2 |
           +=======+=======+
           | Body1 | Body2 |
           +-------+-------+
           | Row2  | Row2  |
           +=======+=======+
           """
    ast = p(text)
    let sections = CommonMark.Node[]
        n = ast.first_child.first_child
        while !CommonMark.isnull(n)
            push!(sections, n)
            n = n.nxt
        end
        @test length(sections) == 2
        @test sections[1].t isa CommonMark.TableHeader
        @test sections[2].t isa CommonMark.TableBody
    end

    # Footer with colspan
    text = """
           +------+------+------+
           | H1   | H2   | H3   |
           +======+======+======+
           | B1   | B2   | B3   |
           +======+=============+
           | F1   | F2 spanning |
           +======+=============+
           """
    ast = p(text)
    let sections = CommonMark.Node[]
        n = ast.first_child.first_child
        while !CommonMark.isnull(n)
            push!(sections, n)
            n = n.nxt
        end
        @test sections[1].t isa CommonMark.TableHeader
        @test sections[2].t isa CommonMark.TableBody
        @test sections[3].t isa CommonMark.TableFoot
        # Second footer cell spans 2 columns
        foot_row = sections[3].first_child
        foot_cell = foot_row.first_child.nxt
        @test foot_cell.t.colspan == 2
    end
    test_grid("footer_colspan", ast, "grid_tables")
    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Footer with rowspan
    text = """
           +------+------+
           | H1   | H2   |
           +======+======+
           | B1   | B2   |
           +======+======+
           | F1   | FA   |
           |      +------+
           |      | FB   |
           +======+======+
           """
    ast = p(text)
    let sections = CommonMark.Node[]
        n = ast.first_child.first_child
        while !CommonMark.isnull(n)
            push!(sections, n)
            n = n.nxt
        end
        @test sections[1].t isa CommonMark.TableHeader
        @test sections[2].t isa CommonMark.TableBody
        @test sections[3].t isa CommonMark.TableFoot
        # First footer cell spans 2 rows (TableFoot → TableRows → TableRow → TableCell)
        foot_rows = sections[3].first_child
        foot_row = foot_rows.first_child
        foot_cell = foot_row.first_child
        @test foot_cell.t.rowspan == 2
    end
    test_grid("footer_rowspan", ast, "grid_tables")
    md1 = markdown(ast)
    md2 = markdown(p(md1))
    @test md1 == md2

    # Round-trip all previous tests
    for input in [
        "+-------+-------+\n| Head1 | Head2 |\n+=======+=======+\n| Body1 | Body2 |\n+-------+-------+\n",
        "+-------+-------+\n| Left  | Right |\n+-------+-------+\n",
        "+----------+----------+\n| Line one | Single   |\n| Line two |          |\n+==========+==========+\n| Body     | Multi    |\n|          | line too |\n+----------+----------+\n",
    ]
        local ast = p(input)
        local md1 = markdown(ast)
        local md2 = markdown(p(md1))
        @test md1 == md2
    end

    # Width-80 explicit IOContext matches term() output (which uses IOBuffer → 80 cols)
    text = """
           +----------+----------------------+
           | Location | Temperature          |
           |          +------+------+--------+
           |          | min  | mean | max    |
           +==========+======+======+========+
           | Chicago  | -10  | 15   | 35     |
           +----------+------+------+--------+
           | Berlin   | -5   | 12   | 30     |
           +----------+------+------+--------+
           """
    ast = p(text)
    buf80 = IOBuffer()
    show(IOContext(buf80, :displaysize => (24, 80)), MIME"text/plain"(), ast)
    @test String(take!(buf80)) == term(ast)

    # Narrow terminal wraps content — all visible lines ≤ target width
    text = """
           +----------+------------------------------------------------+
           | Key      | Value                                          |
           +==========+================================================+
           | greeting | Hello world, this is a rather long piece of    |
           |          | text that should wrap when the terminal is narrow|
           +----------+------------------------------------------------+
           """
    ast = p(text)
    narrow_width = 40
    buf = IOBuffer()
    show(IOContext(buf, :displaysize => (24, narrow_width)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    for line in split(output, '\n')
        vis = CommonMark._term_visible_length(line)
        @test vis <= narrow_width
    end

    # Very narrow terminal (budget < ncols) still produces output
    ast = p("+---+---+\n| A | B |\n+---+---+\n")
    buf = IOBuffer()
    show(IOContext(buf, :displaysize => (24, 5)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    @test !isempty(output)

    # Truncated-to-empty cells show ellipsis
    text = "+----------+---+\n| Has text | B |\n+----------+---+\n"
    ast = p(text)
    buf = IOBuffer()
    show(IOContext(buf, :displaysize => (24, 12)), MIME"text/plain"(), ast)
    @test occursin("…", String(take!(buf)))

    # Nested grid table inside a cell
    text = """
           +-------------------------+-------------------+
           | Outer Left              | Outer Right       |
           +=========================+===================+
           | +------+------+         | Regular cell      |
           | | A    | B    |         |                   |
           | +------+------+         |                   |
           | | C    | D    |         |                   |
           | +------+------+         |                   |
           +-------------------------+-------------------+
           """
    ast = p(text)
    # Outer table should have 2 columns
    table = ast.first_child
    @test table.t isa CommonMark.GridTable
    @test length(table.t.spec) == 2
    # The inner table should be parsed as block content in the cell
    body = table.first_child.nxt  # TableBody (after TableHeader)
    row = body.first_child
    cell1 = row.first_child
    # First child of left cell should be a nested GridTable
    inner = cell1.first_child
    @test inner.t isa CommonMark.GridTable
    @test length(inner.t.spec) == 2
    test_grid("nested_table", ast, "grid_tables")

    # Unicode (CJK) content — multi-byte chars must not cause StringIndexError
    text = """
           +------------+------+
           | こんにちは | 世界 |
           +============+======+
           | テスト     | OK   |
           +------------+------+
           """
    ast = p(text)
    test_grid("unicode_cjk", ast, "grid_tables")

    # Colspan cell at narrow width wraps at combined target
    text = """
           +------+------+------+
           | A    | B    | C    |
           +------+------+------+
           | wide span   | solo |
           +------+------+------+
           """
    ast = p(text)
    buf = IOBuffer()
    show(IOContext(buf, :displaysize => (24, 35)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    for line in split(output, '\n')
        vis = CommonMark._term_visible_length(line)
        @test vis <= 35
    end
end
