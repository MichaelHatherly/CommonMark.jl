@testset "Tables" begin
    p = Parser()
    enable!(p, TableRule())

    text =
    """
    | 1 | 10 | 100 |
    | - | --:|:---:|
    | x | y  | z   |
    """
    ast = p(text)

    # HTML
    @test html(ast) == "<table><thead><tr><th align=\"left\">1</th><th align=\"right\">10</th><th align=\"center\">100</th></tr></thead><tbody><tr><td align=\"left\">x</td><td align=\"right\">y</td><td align=\"center\">z</td></tr></tbody></table>"
    @test latex(ast) == "\\begin{longtable}[]{@{}lrc@{}}\n\\toprule\n1 & 10 & 100\\tabularnewline\n\\midrule\n\\endhead\nx & y & z\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"
    @test term(ast) == " ┏━━━┯━━━━┯━━━━━┓\n ┃ 1 │ 10 │ 100 ┃\n ┠───┼────┼─────┨\n ┃ x │  y │  z  ┃\n ┗━━━┷━━━━┷━━━━━┛\n"
    @test markdown(ast) == "| 1 | 10 | 100 |\n|:- | --:|:---:|\n| x | y  | z   |\n"
    @test markdown(p(markdown(ast))) == "| 1 | 10 | 100 |\n|:- | --:|:---:|\n| x | y  | z   |\n"

    # Mis-aligned table pipes:
    #
    # We require correct alignment of pipes for parsing, but if incorrect table
    # syntax is given we still make it a table, rather than throwing an error
    # or backing out of table parsing.
    text =
    """
    |1|10|100|
    | - | --:|:---:|
    |x|y|z|
    """
    ast = p(text)
    @test html(ast) == "<table><thead><tr><th align=\"left\">1|1</th><th align=\"right\">|100</th><th align=\"center\"></th></tr></thead><tbody><tr><td align=\"left\">x|y</td><td align=\"right\">z|</td><td align=\"center\">|</td></tr></tbody></table>"

    p = enable!(Parser(), [TableRule(), AttributeRule()])

    text =
    """
    {#id}
    | 1 | 10 | 100 |
    | - | --:|:---:|
    | x | y  | z   |
    """
    ast = p(text)

    # HTML
    @test html(ast) == "<table id=\"id\"><thead><tr><th align=\"left\">1</th><th align=\"right\">10</th><th align=\"center\">100</th></tr></thead><tbody><tr><td align=\"left\">x</td><td align=\"right\">y</td><td align=\"center\">z</td></tr></tbody></table>"
    @test latex(ast) == "\\protect\\hyperlabel{id}{}\\begin{longtable}[]{@{}lrc@{}}\n\\toprule\n1 & 10 & 100\\tabularnewline\n\\midrule\n\\endhead\nx & y & z\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"
end
