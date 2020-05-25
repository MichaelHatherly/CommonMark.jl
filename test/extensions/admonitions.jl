@testset "Admonitions" begin
    p = Parser()
    enable!(p, AdmonitionRule())

    text =
    """
    !!! warning

        text
    """
    ast = p(text)

    @test html(ast) == "<div class=\"admonition warning\"><p class=\"amonition-title\">Warning</p>\n<p>text</p>\n</div>"
    @test latex(ast) == "\\quote{\n\\textbf{warning}\n\n\nWarning\n\n\ntext\n}\n"
    @test term(ast) == " \e[33m│\e[39m \e[33mWarning\e[39m\n \e[33m│\e[39m \n \e[33m│\e[39m text\n"

    text =
    """
    !!! info "Custom Title"

        text
    """
    ast = p(text)

    @test html(ast) == "<div class=\"admonition info\"><p class=\"amonition-title\">Custom Title</p>\n<p>text</p>\n</div>"
    @test latex(ast) == "\\quote{\n\\textbf{info}\n\n\nCustom Title\n\n\ntext\n}\n"
    @test term(ast) == " \e[36m│\e[39m \e[36mCustom Title\e[39m\n \e[36m│\e[39m \n \e[36m│\e[39m text\n"
end
