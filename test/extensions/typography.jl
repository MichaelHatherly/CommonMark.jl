@testitem "typography" tags = [:extensions, :typography] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_typography = test_all_formats(pwd())

    p = create_parser(TypographyRule())

    # Basic typography replacements
    text = "\"Double quotes\", 'single quotes', ellipses...., and-- dashes---"
    ast = p(text)
    test_typography("basic", ast, "typography")
end
