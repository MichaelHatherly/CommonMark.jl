@testitem "terminal_writer" tags = [:writers, :term] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = Parser()

    function test(filename, text)
        ast = p(text)
        @test_reference filename Text(term(ast))
    end

    # Code blocks.
    test("references/term/code.txt", "`code`")
    # Inline HTML.
    test("references/term/inline_html.txt", "<em>text</em>")
    # Links.
    test("references/term/link.txt", "[link](url)")
    # Images.
    test("references/term/image.txt", "![link](url)")
    # Emphasis.
    test("references/term/emphasis.txt", "*text*")
    # Strong.
    test("references/term/strong.txt", "**text**")
    # Headings.
    test("references/term/h1.txt", "# h1")
    test("references/term/h2.txt", "## h2")
    test("references/term/h3.txt", "### h3")
    test("references/term/h4.txt", "#### h4")
    test("references/term/h5.txt", "##### h5")
    test("references/term/h6.txt", "###### h6")
    # Block quotes.
    test("references/term/blockquote.txt", "> quote")
    test("references/term/blockquote_empty.txt", ">")
    # Lists.
    test(
        "references/term/list_nested_ordered.txt",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test("references/term/list_nested_unordered.txt", "- - - - - - - item")
    test("references/term/list_empty_bullet.txt", "  - ")
    test("references/term/list_empty_ordered.txt", "1. ")
    test("references/term/list_mixed_markers.txt", "  - one\n  *\n  + three\n")
    test("references/term/list_ordered_with_empty.txt", "1. one\n2.\n3. three")

    # Thematic Breaks.
    test("references/term/thematic_break.txt", "***")
    # Code blocks.
    test(
        "references/term/code_block_fenced.txt",
        """
        ```
        code
        ```
        """,
    )
end
