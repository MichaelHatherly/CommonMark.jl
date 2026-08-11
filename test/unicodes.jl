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

@testitem "unicode_markdown_roundtrip" tags = [:unicode, :roundtrip] setup = [Utilities] begin
    using CommonMark
    using Test

    p = Parser()

    # The Markdown writer tracks escape positions in bitvectors sized by
    # codeunits and walks them one character at a time, so multi-byte text must
    # not shift an escape onto a continuation byte.
    @test Utilities.faithful(p, "é*x*\n")
    @test Utilities.faithful(p, "café [link](u)\n")
    @test Utilities.faithful(p, "你好 **bold**\n")
    @test Utilities.faithful(p, "« quoted »\n")
end

@testitem "unicode_whitespace_is_content" tags = [:unicode] begin
    using CommonMark
    using Test

    p = Parser()

    # The spec strips space, tab, and the line ending characters from paragraph
    # content. Everything else Unicode calls whitespace is content, and an
    # entity already decodes to content.
    @test html(p("\u00a0x")) == "<p>\u00a0x</p>\n"
    @test html(p("&nbsp;x")) == html(p("\u00a0x"))
    @test html(p("x\u00a0")) == "<p>x\u00a0</p>\n"
    @test html(p("x\u00a0\ny")) == "<p>x\u00a0\ny</p>\n"
    # Dropping the space before the line end stops at the non-breaking one.
    @test html(p("x\u00a0 \ny")) == "<p>x\u00a0\ny</p>\n"
    @test html(p("\u2003x")) == "<p>\u2003x</p>\n"

    # Spaces and tabs are still stripped.
    @test html(p(" x ")) == "<p>x</p>\n"
    @test html(p("x \ny")) == "<p>x\ny</p>\n"
end
