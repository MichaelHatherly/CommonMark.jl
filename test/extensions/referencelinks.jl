@testitem "referencelinks" tags = [:extensions, :referencelinks] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(ReferenceLinkRule())
    test_reflink = test_all_formats(pwd())

    # Full reference style [text][label]
    ast = p("[text][label]\n\n[label]: /url")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[text][label]\n\n[label]: /url\n"

    # Collapsed reference style [text][]
    ast = p("[text][]\n\n[text]: /url")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[text][]\n\n[text]: /url\n"

    # Shortcut reference style [text]
    ast = p("[text]\n\n[text]: /url")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[text]\n\n[text]: /url\n"

    # Reference with title
    ast = p("[text][label]\n\n[label]: /url \"Title\"")
    @test html(ast) == "<p><a href=\"/url\" title=\"Title\">text</a></p>\n"

    # Reference image - full style
    ast = p("![alt][label]\n\n[label]: /img.png")
    @test html(ast) == "<p><img src=\"/img.png\" alt=\"alt\" /></p>\n"
    @test markdown(ast) == "![alt][label]\n\n[label]: /img.png\n"

    # Reference image - collapsed style
    ast = p("![alt][]\n\n[alt]: /img.png")
    @test html(ast) == "<p><img src=\"/img.png\" alt=\"alt\" /></p>\n"
    @test markdown(ast) == "![alt][]\n\n[alt]: /img.png\n"

    # Reference image - shortcut style
    ast = p("![alt]\n\n[alt]: /img.png")
    @test html(ast) == "<p><img src=\"/img.png\" alt=\"alt\" /></p>\n"
    @test markdown(ast) == "![alt]\n\n[alt]: /img.png\n"

    # Mixed with inline links (inline should still work)
    ast = p("[ref][label] and [inline](/url)\n\n[label]: /ref")
    @test html(ast) == "<p><a href=\"/ref\">ref</a> and <a href=\"/url\">inline</a></p>\n"
    @test occursin("[ref][label]", markdown(ast))
    @test occursin("[inline](/url)", markdown(ast))

    # Missing definition - falls through to literal text
    ast = p("[text][missing]")
    @test html(ast) == "<p>[text][missing]</p>\n"

    # Without extension, reference links become regular links
    p_no_ext = create_parser()
    ast = p_no_ext("[text][label]\n\n[label]: /url")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[text](/url)\n"  # converted to inline

    # All three styles together
    ast = p("""
[full][label]
[collapsed][]
[shortcut]

[label]: /url1
[collapsed]: /url2
[shortcut]: /url3
""")
    md = markdown(ast)
    @test occursin("[full][label]", md)
    @test occursin("[collapsed][]", md)
    @test occursin("[shortcut]", md)

    # Edge cases

    # Case insensitive label matching
    ast = p("[TEXT][Label]\n\n[label]: /url")
    @test html(ast) == "<p><a href=\"/url\">TEXT</a></p>\n"
    @test occursin("[TEXT][Label]", markdown(ast))  # preserves original case

    # Multiple definitions - first wins
    ast = p("[text][label]\n\n[label]: /first\n[label]: /second")
    @test html(ast) == "<p><a href=\"/first\">text</a></p>\n"

    # Emphasis in link text preserved
    ast = p("[*emph* text][label]\n\n[label]: /url")
    @test html(ast) == "<p><a href=\"/url\"><em>emph</em> text</a></p>\n"

    # Escaped brackets are not links
    ast = p("\\[not a ref\\]\n\n[not a ref]: /url")
    @test html(ast) == "<p>[not a ref]</p>\n"

    # Bracket after prevents shortcut
    ast = p("[foo][bar][baz]\n\n[baz]: /url")
    @test html(ast) == "<p>[foo]<a href=\"/url\">bar</a></p>\n"

    # Nested brackets in label are invalid
    ast = p("[text][label[nested]]\n\n[label[nested]]: /url")
    @test !occursin("<a", html(ast))  # no link created

    # Definition can come before reference
    ast = p("[label]: /url\n\n[text][label]")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[label]: /url\n\n[text][label]\n"

    # Angle-bracket destination with spaces
    ast = p("[text][label]\n\n[label]: </url with spaces>")
    @test html(ast) == "<p><a href=\"/url%20with%20spaces\">text</a></p>\n"

    # URL-encoded destination preserved
    ast = p("[text][label]\n\n[label]: /path%20encoded")
    @test html(ast) == "<p><a href=\"/path%20encoded\">text</a></p>\n"

    # Title with escaped quotes - roundtrips correctly
    ast = p("[text][label]\n\n[label]: /url \"Title \\\"quoted\\\"\"")
    @test occursin("Title &quot;quoted&quot;", html(ast))  # HTML-escaped
    md = markdown(ast)
    @test occursin("\\\"", md)  # quotes escaped in markdown output

    # Multiple references to same label preserved
    ast = p("A [cool ref][ref] and [here][ref].\n\n[ref]: https://example.com")
    md = markdown(ast)
    @test occursin("[cool ref][ref]", md)
    @test occursin("[here][ref]", md)
    @test occursin("[ref]: https://example.com", md)
    @test markdown(p(md)) == md  # roundtrip stable

    test_reflink(
        "multiple_refs_same_label",
        p("A [cool ref][ref] and [here][ref].\n\n[ref]: https://example.com"),
        "referencelinks",
    )
end
