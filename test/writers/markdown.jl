@testitem "markdown_writer" tags = [:writers, :markdown] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = Parser()

    function test(filename, text)
        ast = p(text)
        output = markdown(ast)
        @test_reference filename Text(output)
        @test markdown(p(output)) == output # Is markdown output round-trip-able?
    end

    # Code blocks.
    test("references/markdown/code.md", "`code`")
    # Inline HTML.
    test("references/markdown/inline_html.md", "<em>text</em>")
    # Links.
    test("references/markdown/link.md", "[link](url)")
    # Images.
    test("references/markdown/image.md", "![link](url)")
    # Emphasis.
    test("references/markdown/emphasis_star.md", "*text*")
    # Strong.
    test("references/markdown/strong_star.md", "**text**")
    # Emphasis.
    test("references/markdown/emphasis_underscore.md", "_text_")
    # Strong.
    test("references/markdown/strong_underscore.md", "__text__")
    # Emphasis.
    test("references/markdown/emphasis_nested.md", "_**text**_")
    # Strong.
    test("references/markdown/strong_nested.md", "*__text__*")
    # Headings.
    test("references/markdown/h1.md", "# h1")
    test("references/markdown/h2.md", "## h2")
    test("references/markdown/h3.md", "### h3")
    test("references/markdown/h4.md", "#### h4")
    test("references/markdown/h5.md", "##### h5")
    test("references/markdown/h6.md", "###### h6")
    # Block quotes.
    test("references/markdown/blockquote.md", "> quote")
    test("references/markdown/blockquote_empty.md", ">")
    # Lists.
    test(
        "references/markdown/list_nested_ordered.md",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test("references/markdown/list_nested_unordered.md", "- - - - - - - item")
    test("references/markdown/list_empty_bullet.md", "  - ")
    test("references/markdown/list_empty_ordered.md", "1. ")
    test("references/markdown/list_with_empty_item.md", "  - one\n  - \n  - three\n")
    test("references/markdown/list_ordered_with_empty.md", "1. one\n2.\n3. three")
    # Thematic Breaks.
    test("references/markdown/thematic_break.md", "***")
    # Code blocks.
    test(
        "references/markdown/code_block_fenced_julia.md",
        """
        ```julia
        code
        ```
        """,
    )
    test(
        "references/markdown/code_block_indented.md",
        """
            code
        """,
    )
    test(
        "references/markdown/code_block_jldoctest.md",
        """
        ```jldoctest
        julia> a = 1
        1

        julia> b = 2
        2
        ```
        """,
    )
    test(
        "references/markdown/code_block_indented_julia.md",
        """
            julia> a = 1
            1

            julia> b = 2
            2
        """,
    )
    # Escapes.
    test("references/markdown/escape_backslash.md", "\\\\")
    test("references/markdown/escape_backtick.md", "\\`x\\`")
end
