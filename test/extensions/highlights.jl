@testset "Highlights" begin
    using ReferenceTests

    highlighter(::MIME"text/html", node) = "NO HTML HIGHLIGHTING"
    highlighter(::MIME"text/latex", node) = "NO LATEX HIGHLIGHTING"
    highlighter(::MIME"text/plain", node) = "NO TERM HIGHLIGHTING"

    p = Parser()
    env = Dict("syntax-highlighter" => highlighter)

    text = """
            ```julia
            code
            ```
            """
    ast = p(text)

    # Test with custom syntax highlighter
    formats = [(html, "html.txt"), (latex, "tex"), (term, "txt"), (markdown, "md")]
    for (func, ext) in formats
        filename = "references/highlights/custom_highlighter.$(ext)"
        output = func(ast, env)
        @test_reference filename Text(output)
    end
end
