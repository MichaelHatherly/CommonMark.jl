@testset "Typography" begin
    p = Parser()
    enable!(p, TypographyRule())

    text = "\"Double quotes\", 'single quotes', ellipses..., and-- dashes---"
    ast = p(text)

    @test html(ast) == "<p>“Double quotes”, ‘single quotes’, ellipses…, and– dashes—</p>\n"
    @test latex(ast) == "\n“Double quotes”, ‘single quotes’, ellipses…, and– dashes—\n"
    @test term(ast) == " “Double quotes”, ‘single quotes’, ellipses…, and– dashes—\n"
end
