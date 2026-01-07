@testitem "highlights" tags = [:extensions, :highlights] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    # Transform function using new API - dispatches on CodeBlock container type
    # Returns HtmlBlock/LaTeXBlock/Text node with pre-rendered content
    function transform(::MIME"text/html", ::CommonMark.CodeBlock, node, entering, writer)
        new_node = CommonMark.Node(
            CommonMark.HtmlBlock,
            "<pre><code class=\"language-julia\">NO HTML HIGHLIGHTING</code></pre>\n",
        )
        (new_node, entering)
    end
    function transform(::MIME"text/latex", ::CommonMark.CodeBlock, node, entering, writer)
        new_node = CommonMark.Node(
            CommonMark.LaTeXBlock,
            "\\begin{lstlisting}\nNO LATEX HIGHLIGHTING\n\\end{lstlisting}\n",
        )
        (new_node, entering)
    end
    function transform(::MIME"text/plain", ::CommonMark.CodeBlock, node, entering, writer)
        # For terminal, we modify the literal and let normal rendering happen
        new_node = CommonMark.Node(CommonMark.CodeBlock, "NO TERM HIGHLIGHTING")
        (new_node, entering)
    end
    transform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
        (node, entering)

    p = create_parser()
    test_highlight = test_all_formats(pwd())

    text = """
            ```julia
            code
            ```
            """
    ast = p(text)

    # Test with custom syntax highlighter
    test_highlight(
        "custom_highlighter",
        ast,
        "highlights",
        transform = transform,
        formats = [:html, :latex, :term, :markdown],
    )
end
