@testitem "typst_writer" tags = [:writers, :typst] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    # Code blocks.
    test("references/typst/code.typ", "`code`", typst)
    # Inline HTML.
    test("references/typst/inline_html.typ", "<em>text</em>", typst)
    # Links.
    test("references/typst/link.typ", "[link](url)", typst)
    # Images.
    test("references/typst/image.typ", "![link](url)", typst)
    # Emphasis.
    test("references/typst/emphasis.typ", "*text*", typst)
    # Strong.
    test("references/typst/strong.typ", "**text**", typst)
    # Headings.
    test("references/typst/h1.typ", "# h1", typst)
    test("references/typst/h2.typ", "## h2", typst)
    test("references/typst/h3.typ", "### h3", typst)
    test("references/typst/h4.typ", "#### h4", typst)
    test("references/typst/h5.typ", "##### h5", typst)
    test("references/typst/h6.typ", "###### h6", typst)
    # Block quotes.
    test("references/typst/blockquote.typ", "> quote", typst)
    # Lists.
    test("references/typst/list_unordered.typ", "- item", typst)
    test("references/typst/list_ordered.typ", "1. item", typst)
    test("references/typst/list_ordered_start.typ", "3. item", typst)
    test(
        "references/typst/list_unordered_multiple.typ",
        """
        - item
        - item
        """,
        typst,
    )
    test(
        "references/typst/list_ordered_multiple.typ",
        """
        1. item
        2. item
        """,
        typst,
    )
    test(
        "references/typst/list_loose.typ",
        """
        - item

        - item
        """,
        typst,
    )

    # Thematic Breaks.
    test("references/typst/thematic_break.typ", "***", typst)
    # Code blocks.
    test(
        "references/typst/code_block_indented.typ",
        """
            code
        """,
        typst,
    )
    test(
        "references/typst/code_block_fenced.typ",
        """
        ```
        code
        ```
        """,
        typst,
    )
    # Escapes.
    test("references/typst/escapes.typ", "^~\\&%\$#_{}", typst)
end
