@testitem "typst_writer" tags = [:writers, :typst] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = Parser()

    function test(filename, text)
        ast = p(text)
        @test_reference filename Text(typst(ast))
    end

    # Code blocks.
    test("references/typst/code.typ", "`code`")
    # Inline HTML.
    test("references/typst/inline_html.typ", "<em>text</em>")
    # Links.
    test("references/typst/link.typ", "[link](url)")
    # Images.
    test("references/typst/image.typ", "![link](url)")
    # Emphasis.
    test("references/typst/emphasis.typ", "*text*")
    # Strong.
    test("references/typst/strong.typ", "**text**")
    # Headings.
    test("references/typst/h1.typ", "# h1")
    test("references/typst/h2.typ", "## h2")
    test("references/typst/h3.typ", "### h3")
    test("references/typst/h4.typ", "#### h4")
    test("references/typst/h5.typ", "##### h5")
    test("references/typst/h6.typ", "###### h6")
    # Block quotes.
    test("references/typst/blockquote.typ", "> quote")
    # Lists.
    test("references/typst/list_unordered.typ", "- item")
    test("references/typst/list_ordered.typ", "1. item")
    test("references/typst/list_ordered_start.typ", "3. item")
    test(
        "references/typst/list_unordered_multiple.typ",
        """
        - item
        - item
        """,
    )
    test(
        "references/typst/list_ordered_multiple.typ",
        """
        1. item
        2. item
        """,
    )
    test(
        "references/typst/list_loose.typ",
        """
        - item

        - item
        """,
    )

    # Thematic Breaks.
    test("references/typst/thematic_break.typ", "***")
    # Code blocks.
    test(
        "references/typst/code_block_indented.typ",
        """
            code
        """,
    )
    test(
        "references/typst/code_block_fenced.typ",
        """
        ```
        code
        ```
        """,
    )
    # Escapes.
    test("references/typst/escapes.typ", "^~\\&%\$#_{}")
end
