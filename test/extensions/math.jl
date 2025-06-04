@testitem "math" tags = [:extensions, :math] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_math = test_all_formats(pwd())

    p = create_parser(MathRule())

    # Inline math
    text = "Some ``math``."
    ast = p(text)
    test_math("inline_math", ast, "math")

    # Single backtick should remain as code
    ast = p("`x`")
    @test html(ast) == "<p><code>x</code></p>\n"

    # Display math
    text = "```math\nmath\n```"
    ast = p(text)
    test_math("display_math", ast, "math")

    # Math with attributes
    p = create_parser([MathRule(), AttributeRule()])

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
    test_math("display_math_with_id", ast, "math")

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
    p = create_parser(DollarMathRule())

    # Inline dollar math
    text = raw"Some $math$."
    ast = p(text)
    test_math("inline_dollar_math", ast, "math")

    # Display dollar math
    text = raw"$$display math$$"
    ast = p(text)
    test_math("display_dollar_math", ast, "math")
end
