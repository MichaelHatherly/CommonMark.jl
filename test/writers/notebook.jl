@testitem "notebook_writer" tags = [:writers, :notebook] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    using JSON

    p = create_parser()
    dir = pwd()

    function test(filename, text)
        ast = p(text)
        json = JSON.parse(notebook(ast))
        markdown = join(json["cells"][1]["source"])
        @test_reference joinpath(dir, filename) Text(markdown)
    end

    # Code blocks.
    test("references/notebook/code.md", "`code`")
    # Inline HTML.
    test("references/notebook/inline_html.md", "<em>text</em>")
    # Links.
    test("references/notebook/link.md", "[link](url)")
    # Images.
    test("references/notebook/image.md", "![link](url)")
    # Emphasis.
    test("references/notebook/emphasis.md", "*text*")
    # Strong.
    test("references/notebook/strong.md", "**text**")
    # Headings.
    test("references/notebook/h1.md", "# h1")
    test("references/notebook/h2.md", "## h2")
    test("references/notebook/h3.md", "### h3")
    test("references/notebook/h4.md", "#### h4")
    test("references/notebook/h5.md", "##### h5")
    test("references/notebook/h6.md", "###### h6")
    # Block quotes.
    test("references/notebook/blockquote.md", "> quote")
    # Lists.
    test(
        "references/notebook/list_nested_ordered.md",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test("references/notebook/list_nested_unordered.md", "- - - - - - - item")
    # Thematic Breaks.
    test("references/notebook/thematic_break.md", "***")
    # Code blocks.
    test(
        "references/notebook/code_block_fenced_julia.md",
        """
        ```julia
        code
        ```
        """,
    )
    test(
        "references/notebook/code_block_indented.md",
        """
            code
        """,
    )
end
