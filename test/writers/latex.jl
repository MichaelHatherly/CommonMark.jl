@testitem "latex_writer" tags = [:writers, :latex] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    # Code blocks.
    test("references/latex/code.tex", "`code`", latex)
    # Inline HTML.
    test("references/latex/inline_html.tex", "<em>text</em>", latex)
    # Links.
    test("references/latex/link.tex", "[link](url)", latex)
    # Images.
    test("references/latex/image.tex", "![link](url)", latex)
    # Emphasis.
    test("references/latex/emphasis.tex", "*text*", latex)
    # Strong.
    test("references/latex/strong.tex", "**text**", latex)
    # Headings.
    test("references/latex/h1.tex", "# h1", latex)
    test("references/latex/h2.tex", "## h2", latex)
    test("references/latex/h3.tex", "### h3", latex)
    test("references/latex/h4.tex", "#### h4", latex)
    test("references/latex/h5.tex", "##### h5", latex)
    test("references/latex/h6.tex", "###### h6", latex)
    # Block quotes.
    test("references/latex/blockquote.tex", "> quote", latex)
    # Lists.
    test("references/latex/list_unordered.tex", "- item", latex)
    test("references/latex/list_ordered.tex", "1. item", latex)
    test("references/latex/list_ordered_start.tex", "3. item", latex)
    test(
        "references/latex/list_unordered_multiple.tex",
        """
        - item
        - item
        """,
        latex
    )
    test(
        "references/latex/list_ordered_multiple.tex",
        """
        1. item
        2. item
        """,
        latex
    )
    test(
        "references/latex/list_loose.tex",
        """
        - item

        - item
        """,
        latex
    )

    # Thematic Breaks.
    test("references/latex/thematic_break.tex", "***", latex)
    # Code blocks.
    test(
        "references/latex/code_block_indented.tex",
        """
            code
        """,
        latex
    )
    test(
        "references/latex/code_block_fenced.tex",
        """
        ```
        code
        ```
        """,
        latex
    )
    # Escapes.
    test("references/latex/escapes.tex", "^~\\&%\$#_{}", latex)
end
