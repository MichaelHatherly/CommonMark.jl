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

@testitem "unicode_punctuation" tags = [:unicode] begin
    using CommonMark
    using Test

    p = Parser()

    # Unicode Symbol category (S) should count as punctuation for emphasis flanking
    # Spec example 356: § (U+00A7, category So) should allow left-flanking delimiter
    @test html(p("*§ foo*\n")) == "<p><em>§ foo</em></p>\n"

    # Other Symbol category chars
    @test html(p("*© foo*\n")) == "<p><em>© foo</em></p>\n"  # ©  = So
    @test html(p("*€ foo*\n")) == "<p><em>€ foo</em></p>\n"  # €  = Sc (currency)
    @test html(p("*→ foo*\n")) == "<p><em>→ foo</em></p>\n"  # →  = Sm (math)

    # Punctuation category (P) still works
    @test html(p("*« foo*\n")) == "<p><em>« foo</em></p>\n"  # «  = Pi (initial quote)
end

@testitem "unicode_case_folding" tags = [:unicode] begin
    using CommonMark
    using Test

    p = Parser()

    # Unicode case folding for reference link matching
    # Spec example 542: ẞ (German capital sharp S) folds to "ss", not "ß"
    @test html(p("[ẞ]\n\n[SS]: /url\n")) == "<p><a href=\"/url\">ẞ</a></p>\n"
    @test html(p("[SS]\n\n[ẞ]: /url\n")) == "<p><a href=\"/url\">SS</a></p>\n"

    # Standard case insensitivity still works
    @test html(p("[Foo]\n\n[foo]: /url\n")) == "<p><a href=\"/url\">Foo</a></p>\n"
    @test html(p("[FOO]\n\n[foo]: /url\n")) == "<p><a href=\"/url\">FOO</a></p>\n"
end
