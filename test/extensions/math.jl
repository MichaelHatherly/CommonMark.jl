@testset "Math" begin
    p = Parser()
    enable!(p, MathRule())

    # Inline
    text = "Some ``math``."
    ast = p(text)

    @test html(ast) == "<p>Some <span class=\"math\">\\(math\\)</span>.</p>\n"
    @test latex(ast) == "Some \\(math\\).\\par\n"
    @test term(ast) == " Some \e[35mmath\e[39m.\n"
    @test markdown(ast) == "Some ``math``.\n"

    # Display
    text = "```math\nmath\n```"
    ast = p(text)

    @test html(ast) == "<div class=\"display-math\">\\[math\\]</div>"
    @test latex(ast) == "\\begin{equation*}\nmath\n\\end{equation*}\n"
    @test term(ast) == "   \e[35m│\e[39m \e[90mmath\e[39m\n"
    @test markdown(ast) == "```math\nmath\n```\n"

    p = enable!(Parser(), [MathRule(), AttributeRule()])
    text = "Some ``math``{key='value'}."
    ast = p(text)

    @test html(ast) == "<p>Some <span class=\"math\" key=\"value\">\\(math\\)</span>.</p>\n"

    text =
    """
    {#id}
    ```math
    math
    ```
    """
    ast = p(text)

    @test html(ast) == "<div class=\"display-math\" id=\"id\">\\[math\\]</div>"
    @test latex(ast) == "\\protect\\hyperlabel{id}{}\\begin{equation*}\nmath\n\\end{equation*}\n"
end
