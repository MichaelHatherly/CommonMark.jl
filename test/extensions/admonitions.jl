@testset "Admonitions" begin
    p = Parser()
    enable!(p, AdmonitionRule())

    text =
    """
    !!! warning

        text
    """
    ast = p(text)

    @test html(ast) == "<div class=\"admonition warning\"><p class=\"amonition-title\"></p>\n<p>text</p>\n</div>"
    @test latex(ast) == "\\quote{\n\\textbf{warning}\n\n\n\n\n\ntext\n}\n"
    @test term(ast) == " \e[33m│\e[39m \e[33mwarning\e[39m\n \e[33m│\e[39m \n \e[33m│\e[39m text\n"
end
