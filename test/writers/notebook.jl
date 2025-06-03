@testitem "notebook_writer" tags = [:writers, :notebook] begin
    using CommonMark
    using Test
    using ReferenceTests
    using JSON

    p = Parser()

    function test(filename, text)
        ast = p(text)
        json = notebook(ast)
        pretty = JSON.json(JSON.parse(json), 2)
        @test_reference filename Text(pretty)
    end

    # Code blocks.
    test("references/notebook/code.json", "`code`")
    # Inline HTML.
    test("references/notebook/inline_html.json", "<em>text</em>")
    # Links.
    test("references/notebook/link.json", "[link](url)")
    # Images.
    test("references/notebook/image.json", "![link](url)")
    # Emphasis.
    test("references/notebook/emphasis.json", "*text*")
    # Strong.
    test("references/notebook/strong.json", "**text**")
    # Headings.
    test("references/notebook/h1.json", "# h1")
    test("references/notebook/h2.json", "## h2")
    test("references/notebook/h3.json", "### h3")
    test("references/notebook/h4.json", "#### h4")
    test("references/notebook/h5.json", "##### h5")
    test("references/notebook/h6.json", "###### h6")
    # Block quotes.
    test("references/notebook/blockquote.json", "> quote")
    # Lists.
    test(
        "references/notebook/list_nested_ordered.json",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test("references/notebook/list_nested_unordered.json", "- - - - - - - item")
    # Thematic Breaks.
    test("references/notebook/thematic_break.json", "***")
    # Code blocks.
    test(
        "references/notebook/code_block_fenced_julia.json",
        """
        ```julia
        code
        ```
        """,
    )
    test(
        "references/notebook/code_block_indented.json",
        """
            code
        """,
    )
end
