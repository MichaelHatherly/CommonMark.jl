@testset "LaTeX" begin
    using ReferenceTests
    p = Parser()

    function test(filename, text)
        ast = p(text)
        @test_reference filename Text(latex(ast))
    end

    # Code blocks.
    test("references/latex/code.tex", "`code`")
    # Inline HTML.
    test("references/latex/inline_html.tex", "<em>text</em>")
    # Links.
    test("references/latex/link.tex", "[link](url)")
    # Images.
    test("references/latex/image.tex", "![link](url)")
    # Emphasis.
    test("references/latex/emphasis.tex", "*text*")
    # Strong.
    test("references/latex/strong.tex", "**text**")
    # Headings.
    test("references/latex/h1.tex", "# h1")
    test("references/latex/h2.tex", "## h2")
    test("references/latex/h3.tex", "### h3")
    test("references/latex/h4.tex", "#### h4")
    test("references/latex/h5.tex", "##### h5")
    test("references/latex/h6.tex", "###### h6")
    # Block quotes.
    test("references/latex/blockquote.tex", "> quote")
    # Lists.
    test("references/latex/list_unordered.tex", "- item")
    test("references/latex/list_ordered.tex", "1. item")
    test("references/latex/list_ordered_start.tex", "3. item")
    test(
        "references/latex/list_unordered_multiple.tex",
        """
        - item
        - item
        """,
    )
    test(
        "references/latex/list_ordered_multiple.tex",
        """
        1. item
        2. item
        """,
    )
    test(
        "references/latex/list_loose.tex",
        """
        - item

        - item
        """,
    )

    # Thematic Breaks.
    test("references/latex/thematic_break.tex", "***")
    # Code blocks.
    test(
        "references/latex/code_block_indented.tex",
        """
            code
        """,
    )
    test(
        "references/latex/code_block_fenced.tex",
        """
        ```
        code
        ```
        """,
    )
    # Escapes.
    test("references/latex/escapes.tex", "^~\\&%\$#_{}")
end
