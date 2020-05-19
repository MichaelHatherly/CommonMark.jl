@testset "Tables" begin
    p = CommonMark.Parser()
    pushfirst!(p.block_starts, CommonMark.gfm_table)

    text =
    """
    | 1 | 10 | 100 |
    | - | --:|:---:|
    | x | y  | z   |
    """
    ast = CommonMark.parse(p, text)

    # HTML
    html = "<table><thead><tr><th align=\"left\">1</th><th align=\"right\">10</th><th align=\"center\">100</th></tr></thead><tbody><tr><td align=\"left\">x</td><td align=\"right\">y</td><td align=\"center\">z</td></tr></tbody></table>"
    r = CommonMark.Renderer(CommonMark.HTML())
    result = read(CommonMark.render(r, ast), String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.LaTeX(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == "\\begin{longtable}[]{@{}lrc@{}}\n\\toprule\n1 & 10 & 100\\tabularnewline\n\\midrule\n\\endhead\nx & y & z\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Renderer(CommonMark.Term(), b)

    CommonMark.render(l, ast)
    result = String(take!(b))
    @test result == " ┏━━━┯━━━━┯━━━━━┓\n ┃ 1 │ 10 │ 100 ┃\n ┠───┼────┼─────┨\n ┃ x │  y │  z  ┃\n ┗━━━┷━━━━┷━━━━━┛\n"
end
