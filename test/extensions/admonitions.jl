@testset "Admonitions" begin
    p = CommonMark.Parser()
    pushfirst!(p.block_starts, CommonMark.parse_admonition)

    text =
    """
    !!! warning

        text
    """
    ast = CommonMark.parse(p, text)

    # HTML
    html = "<div class=\"admonition warning\"><p class=\"amonition-title\"></p>\n<p>text</p>\n</div>"
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    # TODO: reduce extra newlines.
    @test result == "\\quote{\n\\textbf{warning}\n\n\n\n\n\ntext\n}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == " \e[33m│\e[39m \e[33mwarning\e[39m\n \e[33m│\e[39m \n \e[33m│\e[39m text\n"
end
