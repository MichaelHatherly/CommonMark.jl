@testitem "markdown_writer" tags = [:writers, :markdown] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    function test_with_roundtrip(filename, text)
        test(filename, text, markdown)
        # Also test round-trip
        ast = p(text)
        output = markdown(ast)
        @test markdown(p(output)) == output # Is markdown output round-trip-able?
    end

    # Code blocks.
    test_with_roundtrip("references/markdown/code.md", "`code`")
    # Inline HTML.
    test_with_roundtrip("references/markdown/inline_html.md", "<em>text</em>")
    # Links.
    test_with_roundtrip("references/markdown/link.md", "[link](url)")
    # Images.
    test_with_roundtrip("references/markdown/image.md", "![link](url)")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_star.md", "*text*")
    # Strong.
    test_with_roundtrip("references/markdown/strong_star.md", "**text**")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_underscore.md", "_text_")
    # Strong.
    test_with_roundtrip("references/markdown/strong_underscore.md", "__text__")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_nested.md", "_**text**_")
    # Strong.
    test_with_roundtrip("references/markdown/strong_nested.md", "*__text__*")
    # Headings.
    test_with_roundtrip("references/markdown/h1.md", "# h1")
    test_with_roundtrip("references/markdown/h2.md", "## h2")
    test_with_roundtrip("references/markdown/h3.md", "### h3")
    test_with_roundtrip("references/markdown/h4.md", "#### h4")
    test_with_roundtrip("references/markdown/h5.md", "##### h5")
    test_with_roundtrip("references/markdown/h6.md", "###### h6")
    # Block quotes.
    test_with_roundtrip("references/markdown/blockquote.md", "> quote")
    test_with_roundtrip("references/markdown/blockquote_empty.md", ">")
    # Lists.
    test_with_roundtrip(
        "references/markdown/list_nested_ordered.md",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test_with_roundtrip(
        "references/markdown/list_nested_unordered.md",
        "- - - - - - - item",
    )
    # Issue #43: nested list with content before it should not add blank lines
    test_with_roundtrip(
        "references/markdown/list_nested_with_content.md",
        "- item 1\n  + nested 1\n  + nested 2\n- item 2\n",
    )
    test_with_roundtrip("references/markdown/list_empty_bullet.md", "  - ")
    test_with_roundtrip("references/markdown/list_empty_ordered.md", "1. ")
    test_with_roundtrip(
        "references/markdown/list_with_empty_item.md",
        "  - one\n  - \n  - three\n",
    )
    test_with_roundtrip(
        "references/markdown/list_ordered_with_empty.md",
        "1. one\n2.\n3. three",
    )
    # Thematic Breaks.
    test_with_roundtrip("references/markdown/thematic_break.md", "***")
    # Code blocks.
    test_with_roundtrip(
        "references/markdown/code_block_fenced_julia.md",
        """
        ```julia
        code
        ```
        """,
    )
    test_with_roundtrip(
        "references/markdown/code_block_indented.md",
        """
            code
        """,
    )
    test_with_roundtrip(
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
    test_with_roundtrip(
        "references/markdown/code_block_indented_julia.md",
        """
            julia> a = 1
            1

            julia> b = 2
            2
        """,
    )
    # Escapes.
    test_with_roundtrip("references/markdown/escape_backslash.md", "\\\\")
    test_with_roundtrip("references/markdown/escape_backtick.md", "\\`x\\`")

    # Link title with quotes - must escape for valid markdown output
    ast = p("[link](/url \"Title \\\"quoted\\\"\")")
    md = markdown(ast)
    @test occursin("\\\"", md)  # quotes escaped
    @test markdown(p(md)) == md  # roundtrip works

    # Multi-line setext heading roundtrip: SoftBreak collapses to space in ATX
    ast = p("heading\ncontinued\n======")
    md = markdown(ast)
    @test markdown(p(md)) == md

    # Inline code backtick handling - use odd counts to avoid math syntax
    # No backticks in content → single backtick delimiter
    @test markdown(p("`simple`")) == "`simple`\n"
    # Single backtick in content → triple delimiter with padding
    @test markdown(p("`` `tick` ``")) == "``` `tick` ```\n"
    # Double backticks in content → triple delimiter (no edge backticks, no padding)
    @test markdown(p("``` ``ticks`` ```")) == "``` ``ticks`` ```\n"
    # Triple backticks in content → 5 delimiter with padding
    @test markdown(p("````` ```ticks``` `````")) == "````` ```ticks``` `````\n"
    # Mixed single and double → triple (max run is 2), no edge backticks
    @test markdown(p("``` `` and ` ```")) == "``` `` and ` ```\n"
end
