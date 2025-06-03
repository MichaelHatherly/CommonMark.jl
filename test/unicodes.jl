@testitem "unicode_handling" tags = [:unicode] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_unicode = test_all_formats(pwd())

    p = create_parser(AdmonitionRule())

    # Unicode in admonition title
    text = "!!! note \"Ju 的文字\"\n    Ju\n"
    ast = p(text)
    test_unicode("admonition_unicode_title", ast, "unicodes")
end
