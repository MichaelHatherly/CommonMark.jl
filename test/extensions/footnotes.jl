@testset "Footnotes" begin
    p = Parser()
    enable!(p, FootnoteRule())

    # Links
    text = "text[^1]"
    ast = p(text)

    @test html(ast) == "<p>text<a href=\"#footnote-1\" class=\"footnote\">1</a></p>\n"
    @test latex(ast) == "\ntext\\footnotemark[1]\n"
    @test term(ast) == " text\e[31m[^1]\e[39m\n"

    # Definitions
    text = "[^1]: text"
    ast = p(text)

    @test html(ast) == "<div class=\"footnote\" id=\"footnote-1\"><p class=\"footnote-title\">1</p>\n<p>text</p>\n</div>"
    @test latex(ast) == "\\footnotetext[1]{\n\ntext\n}\n"
    @test term(ast) == " \e[31m┌ [^1] ───────────────────────────────────────────────────────────────────────\e[39m\n \e[31m│\e[39m text\n \e[31m└─────────────────────────────────────────────────────────────────────────────\e[39m\n"
end
