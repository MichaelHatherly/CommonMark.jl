@testset "Math" begin
    using ReferenceTests

    # Helper function for tests that can use references
    function test_math(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/math/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    p = Parser()
    enable!(p, MathRule())

    # Inline math
    text = "Some ``math``."
    ast = p(text)
    test_math("inline_math", ast)

    # Single backtick should remain as code
    ast = p("`x`")
    @test html(ast) == "<p><code>x</code></p>\n"

    # Display math
    text = "```math\nmath\n```"
    ast = p(text)
    test_math("display_math", ast)

    # Math with attributes
    p = enable!(Parser(), [MathRule(), AttributeRule()])

    # Inline math with attributes
    text = "Some ``math``{key='value'}."
    ast = p(text)
    @test html(ast) ==
          "<p>Some <span class=\"math tex\" key=\"value\">\\(math\\)</span>.</p>\n"

    # Display math with id
    text = """
           {#id}
           ```math
           math
           ```
           """
    ast = p(text)
    test_math("display_math_with_id", ast)

    # Display math with class
    text = """
           {.red}
           ```math
           E=mc^2
           ```
           """
    ast = p(text)
    @test html(ast) == "<div class=\"display-math tex red\">\\[E=mc^2\\]</div>"

    # Display math with id and class
    text = """
           {#id .red}
           ```math
           E=mc^2
           ```
           """
    ast = p(text)
    @test html(ast) == "<div class=\"display-math tex red\" id=\"id\">\\[E=mc^2\\]</div>"

    # Dollar math
    p = enable!(Parser(), DollarMathRule())

    # Inline dollar math
    text = raw"Some $math$."
    ast = p(text)
    test_math("inline_dollar_math", ast)

    # Display dollar math
    text = raw"$$display math$$"
    ast = p(text)
    test_math("display_dollar_math", ast)
end
