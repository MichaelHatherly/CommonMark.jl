@testset "Highlights" begin
    abstract type HighlighterExtension end

    function hl(t, f::CM.Fmt{Ext}, n, enter, text) where Ext
        literal = n.literal
        n.literal = text
        f.fn(t, CM.Fmt(f, supertype(Ext)), n, enter)
        n.literal = literal
        return nothing
    end

    CM.html(t::CM.CodeBlock, f::CM.Fmt{E}, n::CM.Node, enter::Bool)  where E<:HighlighterExtension =
        hl(t, f, n, enter, "NO HTML HIGHLIGHTING")

    CM.latex(t::CM.CodeBlock, f::CM.Fmt{E}, n::CM.Node, enter::Bool)  where E<:HighlighterExtension =
        hl(t, f, n, enter, "NO LATEX HIGHLIGHTING")

    CM.term(t::CM.CodeBlock, f::CM.Fmt{E}, n::CM.Node, enter::Bool)  where E<:HighlighterExtension =
        hl(t, f, n, enter, "NO TERM HIGHLIGHTING")

    p = Parser()

    ast = p(
        """
        ```julia
        code
        ```
        """
    )
    @test html(ast, HighlighterExtension) == "<pre><code class=\"language-julia\">NO HTML HIGHLIGHTING</code></pre>\n"
    @test latex(ast, HighlighterExtension) == "\\begin{lstlisting}\nNO LATEX HIGHLIGHTING\n\\end{lstlisting}\n"
    @test term(ast, HighlighterExtension) == "   \e[36m│\e[39m \e[90mNO TERM HIGHLIGHTING\e[39m\n"
    @test markdown(ast, HighlighterExtension) == "```julia\ncode\n```\n"
end
