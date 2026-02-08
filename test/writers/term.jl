@testitem "terminal_writer" tags = [:writers, :term] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    # Code blocks.
    test("references/term/code.txt", "`code`", term)
    # Inline HTML.
    test("references/term/inline_html.txt", "<em>text</em>", term)
    # Links.
    test("references/term/link.txt", "[link](url)", term)
    # Images.
    test("references/term/image.txt", "![link](url)", term)
    # Emphasis.
    test("references/term/emphasis.txt", "*text*", term)
    # Strong.
    test("references/term/strong.txt", "**text**", term)
    # Headings.
    test("references/term/h1.txt", "# h1", term)
    test("references/term/h2.txt", "## h2", term)
    test("references/term/h3.txt", "### h3", term)
    test("references/term/h4.txt", "#### h4", term)
    test("references/term/h5.txt", "##### h5", term)
    test("references/term/h6.txt", "###### h6", term)
    # Block quotes.
    test("references/term/blockquote.txt", "> quote", term)
    test("references/term/blockquote_empty.txt", ">", term)
    # Lists.
    test(
        "references/term/list_nested_ordered.txt",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
        term,
    )
    test("references/term/list_nested_unordered.txt", "- - - - - - - item", term)
    test("references/term/list_empty_bullet.txt", "  - ", term)
    test("references/term/list_empty_ordered.txt", "1. ", term)
    test("references/term/list_mixed_markers.txt", "  - one\n  *\n  + three\n", term)
    test("references/term/list_ordered_with_empty.txt", "1. one\n2.\n3. three", term)

    # Thematic Breaks.
    test("references/term/thematic_break.txt", "***", term)
    # Code blocks.
    test(
        "references/term/code_block_fenced.txt",
        """
        ```
        code
        ```
        """,
        term,
    )
end

@testitem "term_wrapping" tags = [:writers, :term] begin
    using CommonMark
    using Test

    # Test A: exact-fit text stays on one line (exposes off-by-one bug).
    # Document margin = 1 col, so at width=8, available = 7 cols.
    # "aaa bbb" = 7 chars, should fit on one content line.
    buf = IOBuffer()
    ast = Parser()("aaa bbb")
    show(IOContext(buf, :displaysize => (24, 8)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    lines = filter(!isempty, split(output, '\n'))
    @test length(lines) == 1

    # Test B: multi-byte chars don't cause premature wrapping.
    # "café morning" = 12 cols. At width=14, available=13. Should fit one line.
    buf = IOBuffer()
    ast = Parser()("café morning")
    show(IOContext(buf, :displaysize => (24, 14)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    lines = filter(!isempty, split(output, '\n'))
    @test length(lines) == 1

    # Test C: CJK wide characters don't cause premature wrapping.
    # "你好 hi" = 4+1+2 = 7 cols. At width=8, available=7. Should fit one line.
    buf = IOBuffer()
    ast = Parser()("你好 hi")
    show(IOContext(buf, :displaysize => (24, 8)), MIME"text/plain"(), ast)
    output = String(take!(buf))
    lines = filter(!isempty, split(output, '\n'))
    @test length(lines) == 1
end
