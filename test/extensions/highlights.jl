@testitem "highlights" tags = [:extensions, :highlights] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    highlighter(::MIME"text/html", node) = "NO HTML HIGHLIGHTING"
    highlighter(::MIME"text/latex", node) = "NO LATEX HIGHLIGHTING"
    highlighter(::MIME"text/plain", node) = "NO TERM HIGHLIGHTING"

    p = create_parser()
    env = Dict("syntax-highlighter" => highlighter)
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
        env = env,
        formats = [:html, :latex, :term, :markdown],
    )
end
