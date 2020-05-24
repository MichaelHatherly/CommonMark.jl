@testset "Tables" begin
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.TableRule())

    text =
    """
    | 1 | 10 | 100 |
    | - | --:|:---:|
    | x | y  | z   |
    """
    ast = p(text)

    # HTML
    html = "<table><thead><tr><th align=\"left\">1</th><th align=\"right\">10</th><th align=\"center\">100</th></tr></thead><tbody><tr><td align=\"left\">x</td><td align=\"right\">y</td><td align=\"center\">z</td></tr></tbody></table>"
    r = CommonMark.Writer(CommonMark.HTML())

    result = r(ast, String)
    @test result == html

    # LaTeX
    b = IOBuffer()
    l = CommonMark.Writer(CommonMark.LaTeX(), b)

    result = l(ast, String)
    @test result == "\\begin{longtable}[]{@{}lrc@{}}\n\\toprule\n1 & 10 & 100\\tabularnewline\n\\midrule\n\\endhead\nx & y & z\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"

    # Term
    b = IOBuffer()
    l = CommonMark.Writer(CommonMark.Term(), b)

    result = l(ast, String)
    @test result == " ┏━━━┯━━━━┯━━━━━┓\n ┃ 1 │ 10 │ 100 ┃\n ┠───┼────┼─────┨\n ┃ x │  y │  z  ┃\n ┗━━━┷━━━━┷━━━━━┛\n"
end
