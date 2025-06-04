@testitem "unicode_handling" tags = [:unicode] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(AdmonitionRule())
    test_unicode = test_single_format(pwd(), p)

    # Unicode in admonition title
    text = "!!! note \"Ju 的文字\"\n    Ju\n"
    test_unicode("references/admonition_unicode_title.html.txt", text, html)
end
