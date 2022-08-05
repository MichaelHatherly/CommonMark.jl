function custom_parser()
    p = Parser()
    enable!(p, MathRule())
    return p
end

@testset "Interpolation" begin
    ast = cm""
    @test html(ast) == ""
    @test latex(ast) == ""
    @test markdown(ast) == ""
    @test term(ast) == ""

    ast = cm"no interpolation"
    @test html(ast) == "<p>no interpolation</p>\n"
    @test latex(ast) == "no interpolation\\par\n"
    @test markdown(ast) == "no interpolation\n"
    @test term(ast) == " no interpolation\n"

    value = :interpolation
    ast = cm"'some' $value $(value)"
    @test html(ast) == "<p>‘some’ <span class=\"julia-value\">interpolation</span> <span class=\"julia-value\">interpolation</span></p>\n"
    @test latex(ast) == "‘some’ interpolation interpolation\\par\n"
    @test markdown(ast) == "‘some’ \$(value) \$(value)\n"
    @test term(ast) == " ‘some’ \e[33minterpolation\e[39m \e[33minterpolation\e[39m\n"

    ast = cm"*expressions* $(1 + 2) and $(2 + 3)"
    @test html(ast) == "<p><em>expressions</em> <span class=\"julia-value\">3</span> and <span class=\"julia-value\">5</span></p>\n"
    @test latex(ast) == "\\textit{expressions} 3 and 5\\par\n"
    @test markdown(ast) == "*expressions* \$(1 + 2) and \$(2 + 3)\n"
    @test term(ast) == " \e[3mexpressions\e[23m \e[33m3\e[39m and \e[33m5\e[39m\n"

    ast = cm"> *expressions* $(1 + 2) and $(2 + 3)"
    @test html(ast) == "<blockquote>\n<p><em>expressions</em> <span class=\"julia-value\">3</span> and <span class=\"julia-value\">5</span></p>\n</blockquote>\n"
    @test latex(ast) == "\\begin{quote}\n\\textit{expressions} 3 and 5\\par\n\\end{quote}\n"
    @test markdown(ast) == "> *expressions* \$(1 + 2) and \$(2 + 3)\n"
    @test term(ast) == " \e[1m│\e[22m \e[3mexpressions\e[23m \e[33m3\e[39m and \e[33m5\e[39m\n"

    value = :interpolation
    ast = cm"'some' $value $(value)"basic
    @test html(ast) == "<p>'some' <span class=\"julia-value\">interpolation</span> <span class=\"julia-value\">interpolation</span></p>\n"
    @test latex(ast) == "'some' interpolation interpolation\\par\n"
    @test markdown(ast) == "'some' \$(value) \$(value)\n"
    @test term(ast) == " 'some' \e[33minterpolation\e[39m \e[33minterpolation\e[39m\n"

    value = :interpolation
    ast = cm"'some' ``math`` $value $(value)"custom_parser
    @test html(ast) == "<p>'some' <span class=\"math tex\">\\(math\\)</span> <span class=\"julia-value\">interpolation</span> <span class=\"julia-value\">interpolation</span></p>\n"
    @test latex(ast) == "'some' \\(math\\) interpolation interpolation\\par\n"
    @test markdown(ast) == "'some' ``math`` \$(value) \$(value)\n"
    @test term(ast) == " 'some' \e[35mmath\e[39m \e[33minterpolation\e[39m \e[33minterpolation\e[39m\n"

    value = 1
    ast = cm"$(value) $(value + 1) $(value += 1) $(value += 1)"
    @test html(ast) == "<p><span class=\"julia-value\">1</span> <span class=\"julia-value\">2</span> <span class=\"julia-value\">2</span> <span class=\"julia-value\">3</span></p>\n"
    @test latex(ast) == "1 2 2 3\\par\n"
    @test markdown(ast) == "\$(value) \$(value + 1) \$(value += 1) \$(value += 1)\n"
    @test term(ast) == " \e[33m1\e[39m \e[33m2\e[39m \e[33m2\e[39m \e[33m3\e[39m\n"

    # A case that can fail if the @cm_str macro relies on evaluating the passed expressions in argument
    # lists (like the constructor of a vector).
    # https://github.com/JuliaLang/julia/issues/46251
    let
        global value_global
        value_global = 1
        ast = cm"$(value_global) $(value_global + 1) $(value_global += 1) $(value_global += 1)"
        @test latex(ast) == "1 2 2 3\\par\n"
    end

    # Interpolated strings are not markdown-interpreted
    ast = cm"""*expressions* $("**test**")"""
    @test html(ast) == "<p><em>expressions</em> <span class=\"julia-value\">**test**</span></p>\n"
    @test latex(ast) == "\\textit{expressions} **test**\\par\n"
    @test markdown(ast) == "*expressions* \$(**test**)\n"
    @test term(ast) == " \e[3mexpressions\e[23m \e[33m**test**\e[39m\n"

    # Interpolated values are not linked to their macroexpansion origin.
    asts = [cm"Value = **$(each)**" for each in 1:3]
    @test html(asts[1]) == "<p>Value = <strong><span class=\"julia-value\">1</span></strong></p>\n"
    @test html(asts[2]) == "<p>Value = <strong><span class=\"julia-value\">2</span></strong></p>\n"
    @test html(asts[3]) == "<p>Value = <strong><span class=\"julia-value\">3</span></strong></p>\n"

    # Interpolating collections.
    worlds = [HTML("<div>world $i</div>") for i in 1:3]
    @test html(cm"Hello $(worlds)") == "<p>Hello <span class=\"julia-value\"><div>world 1</div> <div>world 2</div> <div>world 3</div> </span></p>\n"

    worlds = (HTML("<div>world $i</div>") for i in 1:3)
    @test html(cm"Hello $(worlds)") == "<p>Hello <span class=\"julia-value\"><div>world 1</div> <div>world 2</div> <div>world 3</div> </span></p>\n"

    worlds = Tuple(HTML("<div>world $i</div>") for i in 1:3)
    @test html(cm"Hello $(worlds)") == "<p>Hello <span class=\"julia-value\"><div>world 1</div> <div>world 2</div> <div>world 3</div> </span></p>\n"

    # Make sure that the evaluation of values happens at runtime.
    f(x) = cm"if x = $(x), then x² = $(x^2)"
    let ast = f(2)
        @test markdown(ast) == "if x = \$(x), then x² = \$(x ^ 2)\n"
        @test term(ast) == " if x = \e[33m2\e[39m, then x² = \e[33m4\e[39m\n"
    end
    let ast = f(-3)
        @test markdown(ast) == "if x = \$(x), then x² = \$(x ^ 2)\n"
        @test term(ast) == " if x = \e[33m-3\e[39m, then x² = \e[33m9\e[39m\n"
    end
end
