@testset "Footnotes" begin
    p = Parser()
    enable!(p, FootnoteRule())

    # Links
    text = "text[^1]"
    ast = p(text)

    @test html(ast) == "<p>text<a href=\"#footnote-1\" class=\"footnote\">1</a></p>\n"
    @test latex(ast) == "text\\par\n" # No definition so not displayed in LaTeX.
    @test term(ast) == " text\e[31m[^1]\e[39m\n"
    @test markdown(ast) == "text[^1]\n"

    # Definitions
    text = "[^1]: text"
    ast = p(text)

    @test html(ast) == "<div class=\"footnote\" id=\"footnote-1\"><p class=\"footnote-title\">1</p>\n<p>text</p>\n</div>"
    @test latex(ast) == "" # Definitions vanish in LaTeX since they are inlined.
    @test term(ast) == " \e[31m┌ [^1] ───────────────────────────────────────────────────────────────────────\e[39m\n \e[31m│\e[39m text\n \e[31m└─────────────────────────────────────────────────────────────────────────────\e[39m\n"
    @test markdown(ast) == "[^1]: text\n"

    text = "text[^1].\n\n[^1]: text"
    ast = p(text)
    @test latex(ast) == "text\\footnote{text\\par\n\\label{fn:1}}.\\par\n"
    @test markdown(ast) == "text[^1].\n\n[^1]: text\n"
end
