@testset "Admonitions" begin
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.AdmonitionRule())

    text =
    """
    !!! warning

        text
    """
    ast = p(text)

    # HTML
    html = "<div class=\"admonition warning\"><p class=\"amonition-title\"></p>\n<p>text</p>\n</div>"
    r = CommonMark.Writer(CommonMark.HTML())
    result = r(ast, String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Writer(CommonMark.LaTeX(), b)

    result = l(ast, String)
    # TODO: reduce extra newlines.
    @test result == "\\quote{\n\\textbf{warning}\n\n\n\n\n\ntext\n}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Writer(CommonMark.Term(), b)

    result = l(ast, String)
    @test result == " \e[33m│\e[39m \e[33mwarning\e[39m\n \e[33m│\e[39m \n \e[33m│\e[39m text\n"
end
