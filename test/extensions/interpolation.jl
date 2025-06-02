function custom_parser()
    p = Parser()
    enable!(p, MathRule())
    return p
end

@testset "Interpolation" begin
    using ReferenceTests

    # Helper function for tests that can use references
    function test_interpolation(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/interpolation/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end
    # Empty string
    ast = cm""
    test_interpolation("empty", ast)

    # No interpolation
    ast = cm"no interpolation"
    test_interpolation("no_interpolation", ast)

    value = :interpolation
    ast = cm"'some' $value $(value)"
    test_interpolation("basic", ast)

    ast = cm"*expressions* $(1 + 2) and $(2 + 3)"
    test_interpolation("expressions", ast)

    ast = cm"> *expressions* $(1 + 2) and $(2 + 3)"
    test_interpolation("block_quote", ast)

    value = :interpolation
    ast = cm"'some' $value $(value)"basic
    test_interpolation("basic_interpolation", ast)

    value = :interpolation
    ast = cm"'some' ``math`` $value $(value)"custom_parser
    test_interpolation("math_interpolation", ast)

    value = 1
    ast = cm"$(value) $(value + 1) $(value += 1) $(value += 1)"
    test_interpolation("expression_with_assignment", ast)

    # A case that can fail if the @cm_str macro relies on evaluating the passed expressions in argument
    # lists (like the constructor of a vector).
    # https://github.com/JuliaLang/julia/issues/46251
    let
        global value_global
        value_global = 1
        ast =
            cm"$(value_global) $(value_global + 1) $(value_global += 1) $(value_global += 1)"
        @test latex(ast) == "1 2 2 3\\par\n"
    end

    # Interpolated strings are not markdown-interpreted
    ast = cm"""*expressions* $("**test**")"""
    test_interpolation("interpolated_string", ast)

    # Interpolated values are not linked to their macroexpansion origin.
    asts = [cm"Value = **$(each)**" for each = 1:3]
    test_interpolation("interpolated_values_1", asts[1])
    test_interpolation("interpolated_values_2", asts[2])
    test_interpolation("interpolated_values_3", asts[3])

    # Interpolating collections.
    worlds = [HTML("<div>world $i</div>") for i = 1:3]
    test_interpolation("interpolated_collection", cm"Hello $(worlds)")

    worlds = (HTML("<div>world $i</div>") for i = 1:3)
    @test html(cm"Hello $(worlds)") ==
          "<p>Hello <span class=\"julia-value\"><div>world 1</div> <div>world 2</div> <div>world 3</div> </span></p>\n"

    worlds = Tuple(HTML("<div>world $i</div>") for i = 1:3)
    test_interpolation("interpolated_tuple", cm"Hello $(worlds)")

    # Make sure that the evaluation of values happens at runtime.
    f(x) = cm"if x = $(x), then x² = $(x^2)"
    let ast = f(2)
        test_interpolation("interpolation_runtime_evaluation", ast)
    end
    let ast = f(-3)
        test_interpolation("interpolation_runtime_evaluation_negative", ast)
    end

    # Make sure that a variable that evaluates to different values in different positions
    # gets interpolated correctly.
    let x = 1
        function f!()
            x += 1
            42
        end # closure that updates the local `x` variable
        ast = cm"$(x), $(f!()), $(x)"
        test_interpolation("variable_update", ast)
    end

    # IOContext passthrough
    struct MyInterpolatedType end

    function Base.show(io::IO, m::MIME"text/html", x::MyInterpolatedType)
        write(io, get(io, :secret, "not found"))
    end

    value = MyInterpolatedType()
    ast = cm"hello $(value)"
    out1 = repr(MIME"text/html"(), ast)
    out2 = repr(MIME"text/html"(), ast; context = (:secret => "🙊"))
    @test out1 == "<p>hello <span class=\"julia-value\">not found</span></p>\n"
    @test out2 == "<p>hello <span class=\"julia-value\">🙊</span></p>\n"

    # ASTs containing JuliaExpression elements
    p = Parser()
    enable!(p, CommonMark.JuliaInterpolationRule())
    ast = p("foo: \$(foo), \$(x ^ 2), \$1234")
    test_interpolation("julia_expressions", ast)
end
