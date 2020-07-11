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
    text =
    """
    |1|10|100|
    | - | --:|:---:|
    |x|y|z|
    """
    ast = p(text)
    @test html(ast) == "<table><thead><tr><th align=\"left\">1</th><th align=\"right\">10</th><th align=\"center\">100</th></tr></thead><tbody><tr><td align=\"left\">x</td><td align=\"right\">y</td><td align=\"center\">z</td></tr></tbody></table>"

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

    # Internal pipes:
    text =
    """
    |1|10|`|`|
    | -:| - |:-:|
    |*|*|![|](url)|
    |1|2|3|4|
    """
    ast = p(text)

    @test html(ast) == "<table><thead><tr><th align=\"right\">1</th><th align=\"left\">10</th><th align=\"center\"><code>|</code></th></tr></thead><tbody><tr><td align=\"right\"><em>|</em></td><td align=\"left\"><img src=\"url\" alt=\"|\" /></td><td align=\"left\"></td></tr><tr><td align=\"right\">1</td><td align=\"left\">2</td><td align=\"center\">3</td></tr></tbody></table>"
    @test latex(ast) == "\\begin{longtable}[]{@{}rlc@{}}\n\\toprule\n1 & 10 & \\texttt{|}\\tabularnewline\n\\midrule\n\\endhead\n\\textit{|} & \n\\begin{figure}\n\\centering\n\\includegraphics{url}\n\\caption{|}\n\\end{figure}\n & \\tabularnewline\n1 & 2 & 3\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"
    @test term(ast) == " ┏━━━┯━━━━┯━━━┓\n ┃ 1 │ 10 │ \e[36m|\e[39m ┃\n ┠───┼────┼───┨\n ┃ \e[3m|\e[23m │ \e[32m|\e[39m  │   ┃\n ┃ 1 │ 2  │ 3 ┃\n ┗━━━┷━━━━┷━━━┛\n"
    @test markdown(ast) == "| 1   | 10        | `|` |\n| ---:|:--------- |:---:|\n| *|* | ![|](url) |     |\n| 1   | 2         | 3   |\n"

    # Empty columns:
    text =
    """
    |||
    |-|-|
    |||
    """
    ast = p(text)

    @test html(ast) == "<table><thead><tr><th align=\"left\"></th><th align=\"left\"></th></tr></thead><tbody><tr><td align=\"left\"></td><td align=\"left\"></td></tr></tbody></table>"
    @test latex(ast) == "\\begin{longtable}[]{@{}ll@{}}\n\\toprule\n & \\tabularnewline\n\\midrule\n\\endhead\n & \\tabularnewline\n\\bottomrule\n\\end{longtable}\n"
    @test term(ast) == " ┏━━━┯━━━┓\n ┃   │   ┃\n ┠───┼───┨\n ┃   │   ┃\n ┗━━━┷━━━┛\n"
    @test markdown(ast) == "|   |   |\n|:- |:- |\n|   |   |\n"

    text =
    """
    # Header

    | table |
    | ----- |
    | content |
    """
    ast = p(text)

    @test html(ast) == "<h1>Header</h1>\n<table><thead><tr><th align=\"left\">table</th></tr></thead><tbody><tr><td align=\"left\">content</td></tr></tbody></table>"
    @test latex(ast) == "\\section{Header}\n\\begin{longtable}[]{@{}l@{}}\n\\toprule\ntable\\tabularnewline\n\\midrule\n\\endhead\ncontent\\tabularnewline\n\\bottomrule\n\\end{longtable}\n"
    @test term(ast) == " \e[34;1m#\e[39;22m Header\n \n ┏━━━━━━━━━┓\n ┃ table   ┃\n ┠─────────┨\n ┃ content ┃\n ┗━━━━━━━━━┛\n"
    @test markdown(ast) == "# Header\n\n| table   |\n|:------- |\n| content |\n"
end
