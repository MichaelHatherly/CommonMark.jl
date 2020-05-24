@testset "LaTeX" begin
    p = CommonMark.Parser()
    b = IOBuffer()
    r = CommonMark.Writer(CommonMark.LaTeX(), b)

    test = function(text, expected)
        ast = p(text)
        result = r(ast, String)
        @test result == expected
    end

    # Code blocks.
    test(
        "`code`",
        "\n\\texttt{code}\n"
    )
    # Inline HTML.
    test(
        "<em>text</em>",
        "\ntext\n"
    )
    # Links.
    test(
        "[link](url)",
        "\n\\href{url}{link}\n"
    )
    # Images.
    test(
        "![link](url)",
        """

        \\begin{figure}
        \\centering
        \\includegraphics{url}
        \\caption{link}
        \\end{figure}

        """
    )
    # Emphasis.
    test(
        "*text*",
        "\n\\emph{text}\n"
    )
    # Strong.
    test(
        "**text**",
        "\n\\textbf{text}\n"
    )
    # Headings.
    test(
        "# h1",
        "\\section{h1}\n"
    )
    test(
        "## h2",
        "\\subsection{h2}\n"
    )
    test(
        "### h3",
        "\\subsubsection{h3}\n"
    )
    test(
        "#### h4",
        "\\paragraph{h4}\n"
    )
    test(
        "##### h5",
        "\\subparagraph{h5}\n"
    )
    test(
        "###### h6",
        "\\subsubparagraph{h6}\n"
    )
    # Block quotes.
    test(
        "> quote",
        "\\begin{quote}\n\nquote\n\\end{quote}\n"
    )
    # Lists.
    test(
        "- item",
        "\\begin{itemize}\n\\item\n\nitem\n\n\\end{itemize}\n"
    )
    # Thematic Breaks.
    test(
        "***",
        "\\begin{center}\\rule{0.5\\linewidth}{0.5pt}\\end{center}\n"
    )
    # Code blocks.
    test(
        """
        ```
        code
        ```
        """,
        "\\begin{verbatim}\ncode\n\\end{verbatim}\n"
    )
    # Escapes.
    test(
        "^~\\&%\$#_{}",
        "\n\\^{}{\\textasciitilde}\\&\\%\\\$\\#\\_\\{\\}\n"
    )
end
