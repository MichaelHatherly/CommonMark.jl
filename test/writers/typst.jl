@testset "Typst" begin
    p = Parser()

    test = function (text, expected)
        ast = p(text)
        @test typst(ast) == expected
    end

    # Code blocks.
    test("`code`", "`code`\n")
    # Inline HTML.
    test("<em>text</em>", "text\n")
    # Links.
    test("[link](url)", "#link(\"url\")[link]\n")
    # Images.
    test("![link](url)", "#figure(image(\"url\"), caption: [link])\n")
    # Emphasis.
    test("*text*", "#emph[text]\n")
    # Strong.
    test("**text**", "#strong[text]\n")
    # Headings.
    test("# h1", "= h1\n")
    test("## h2", "== h2\n")
    test("### h3", "=== h3\n")
    test("#### h4", "==== h4\n")
    test("##### h5", "===== h5\n")
    test("###### h6", "====== h6\n")
    # Block quotes.
    test("> quote", "#quote(block: true)[\nquote\n]\n")
    # Lists.
    test("- item", "  - item\n")
    test("1. item", " 1. item\n")
    test("3. item", " 3. item\n")
    test("- item\n- item", "  - item\n  - item\n")
    test("1. item\n2. item", " 1. item\n 2. item\n")
    test("- item\n\n- item", "  - item\n\n  - item\n")

    # Thematic Breaks.
    test("***", "#line(start: (25%, 0%), end: (75%, 0%))\n")
    # Code blocks.
    test(
        """
            code
        """,
        "```\ncode\n```\n",
    )
    test(
        """
        ```
        code
        ```
        """,
        "```\ncode\n```\n",
    )
    # Escapes.
    test("^~\\&%\$#_{}", "^\\~\\&%\\\$\\#\\_{}\n")
end
