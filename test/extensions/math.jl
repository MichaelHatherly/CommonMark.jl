@testset "Math" begin
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.MathRule())

    # Inline

    # HTML
    text = "Some ``math``."
    html = "<p>Some <span class=\"math\">\\(math\\)</span>.</p>\n"
    ast = CommonMark.parse(p, text)
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "\nSome \\(math\\).\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == " Some \e[35mmath\e[39m.\n"

    # Display

    # HTML
    text = "```math\nmath\n```"
    html = "<div class=\"display-math\">\\[math\\]</div>"
    ast = CommonMark.parse(p, text)
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "\\begin{equation*}\nmath\n\\end{equation*}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "   \e[35m│\e[39m \e[90mmath\e[39m\n"
end
