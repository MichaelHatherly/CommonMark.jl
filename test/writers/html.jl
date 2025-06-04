@testitem "html_writer" tags = [:writers, :html] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    # Code blocks.
    test("references/html/code.html.txt", "`code`", html)
    # Inline HTML.
    test("references/html/inline_html.html.txt", "<em>text</em>", html)
    # Links.
    test("references/html/link.html.txt", "[link](url)", html)
    # Images.
    test("references/html/image.html.txt", "![link](url)", html)
    # Emphasis.
    test("references/html/emphasis.html.txt", "*text*", html)
    # Strong.
    test("references/html/strong.html.txt", "**text**", html)
    # Headings.
    test("references/html/h1.html.txt", "# h1", html)
    test("references/html/h2.html.txt", "## h2", html)
    test("references/html/h3.html.txt", "### h3", html)
    test("references/html/h4.html.txt", "#### h4", html)
    test("references/html/h5.html.txt", "##### h5", html)
    test("references/html/h6.html.txt", "###### h6", html)
    # Block quotes.
    test("references/html/blockquote.html.txt", "> quote", html)
    # Lists.
    test("references/html/list_unordered.html.txt", "- item", html)
    test("references/html/list_ordered.html.txt", "1. item", html)
    test("references/html/list_ordered_start.html.txt", "3. item", html)
    test(
        "references/html/list_unordered_multiple.html.txt",
        """
        - item
        - item
        """,
        html,
    )
    test(
        "references/html/list_ordered_multiple.html.txt",
        """
        1. item
        2. item
        """,
        html,
    )
    test(
        "references/html/list_loose.html.txt",
        """
        - item

        - item
        """,
        html,
    )

    # Thematic Breaks.
    test("references/html/thematic_break.html.txt", "***", html)
    # Code blocks.
    test(
        "references/html/code_block_indented.html.txt",
        """
            code
        """,
        html,
    )
    test(
        "references/html/code_block_fenced.html.txt",
        """
        ```
        code
        ```
        """,
        html,
    )
    # Escapes.
    test("references/html/escapes.html.txt", "^~\\&%\$#_{}", html)
    # Line breaks and paragraphs
    test("references/html/line_break.html.txt", "line 1\\\nline 2", html)
    test(
        "references/html/paragraph_multiple.html.txt",
        """
        paragraph 1

        paragraph 2
        """,
        html,
    )
end