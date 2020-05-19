@testset "Footnotes" begin
    p = CommonMark.Parser()
    pushfirst!(p.block_starts, CommonMark.parse_footnote_definition)
    pushfirst!(p.inline_parser.inline_parsers['['], CommonMark.parse_footnote)

    # Links

    # HTML
    text = "text[^1]"
    html = "<p>text<a href=\"#footnote-1\" class=\"footnote\">1</a></p>\n"
    ast = CommonMark.parse(p, text)
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "\ntext\\footnotemark[1]\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == " text\e[31m[^1]\e[39m\n"

    # Definitions

    # HTML
    text = "[^1]: text"
    html = "<div class=\"footnote\" id=\"footnote-1\"><p class=\"footnote-title\">1</p>\n<p>text</p>\n</div>"
    ast = CommonMark.parse(p, text)
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "\\footnotetext[1]{\n\ntext\n}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == " \e[31m│\e[39m \e[31m[^1]\e[39m\n \e[31m│\e[39m \n \e[31m│\e[39m text\n"
end
