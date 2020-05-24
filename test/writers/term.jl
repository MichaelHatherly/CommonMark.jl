@testset "Terminal" begin
    p = CommonMark.Parser()
    b = IOBuffer()
    r = CommonMark.Writer(CommonMark.Term(), b)

    test = function(text, expected)
        ast = p(text)
        result = r(ast, String)
        @test result == expected
    end

    # Code blocks.
    test(
        "`code`",
        " \e[36mcode\e[39m\n"
    )
    # Inline HTML.
    test(
        "<em>text</em>",
        " \e[90m<em>\e[39mtext\e[90m</em>\e[39m\n"
    )
    # Links.
    test(
        "[link](url)",
        " \e[34;4mlink\e[39;24m\n"
    )
    # Images.
    test(
        "![link](url)",
        " \e[32mlink\e[39m\n"
    )
    # Emphasis.
    test(
        "*text*",
        " \e[3mtext\e[23m\n"
    )
    # Strong.
    test(
        "**text**",
        " \e[1mtext\e[22m\n"
    )
    # Headings.
    test(
        "# h1",
        " \e[34;1m#\e[39;22m h1\n"
    )
    test(
        "## h2",
        " \e[34;1m##\e[39;22m h2\n"
    )
    test(
        "### h3",
        " \e[34;1m###\e[39;22m h3\n"
    )
    test(
        "#### h4",
        " \e[34;1m####\e[39;22m h4\n"
    )
    test(
        "##### h5",
        " \e[34;1m#####\e[39;22m h5\n"
    )
    test(
        "###### h6",
        " \e[34;1m######\e[39;22m h6\n"
    )
    # Block quotes.
    test(
        "> quote",
        " \e[1m│\e[22m quote\n"
    )
    # Lists.
    test(
        "- item",
        "  • item\n"
    )
    # Thematic Breaks.
    test(
        "***",
        " \e[35m* * *\e[39m\n"
    )
    # Code blocks.
    test(
        """
        ```
        code
        ```
        """,
        "   \e[36m│\e[39m \e[90mcode\e[39m\n"
    )
end
