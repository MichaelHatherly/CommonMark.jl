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

    # UnresolvedReference - full style
    ast = p("[text][missing]")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "missing"
    @test unresolved[1].style == :full
    @test unresolved[1].image == false
    @test html(ast) == "<p>[text][missing]</p>\n"
    # The link text of an unresolved reference is plain text, so its brackets
    # are escaped to keep them out of the reparsed markup.
    @test markdown(ast) == "\\[text\\][missing]\n"

    # UnresolvedReference - collapsed style
    ast = p("[collapsed][]")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "collapsed"
    @test unresolved[1].style == :collapsed
    @test html(ast) == "<p>[collapsed][]</p>\n"
    @test markdown(ast) == "\\[collapsed\\][]\n"

    # UnresolvedReference - shortcut style
    ast = p("[undefined shortcut]")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "undefined shortcut"
    @test unresolved[1].style == :shortcut
    @test unresolved[1].image == false
    @test html(ast) == "<p>[undefined shortcut]</p>\n"
    @test markdown(ast) == "[undefined shortcut]\n"

    # UnresolvedReference - image shortcut
    ast = p("![undefined image]")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "undefined image"
    @test unresolved[1].image == true
    @test html(ast) == "<p>![undefined image]</p>\n"

    # UnresolvedReference - image full style
    ast = p("![img][missing]")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "missing"
    @test unresolved[1].style == :full
    @test unresolved[1].image == true
    @test html(ast) == "<p>![img][missing]</p>\n"

    # UnresolvedReference - mixed with valid refs
    ast = p("[valid][label]\n[undefined]\n\n[label]: /url")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test length(unresolved) == 1
    @test unresolved[1].label == "undefined"
    resolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.ReferenceLink]
    @test length(resolved) == 1
    @test resolved[1].label == "label"

    # Ambiguous case: [a][b][c] - must still parse correctly
    ast = p("[a][b][c]\n\n[c]: /url")
    unresolved = [n.t for (n, e) in ast if e && n.t isa CommonMark.UnresolvedReference]
    @test isempty(unresolved)  # [a][b] becomes text due to backtracking
    @test html(ast) == "<p>[a]<a href=\"/url\">b</a></p>\n"

    # Without extension, reference links become regular links
    p_no_ext = create_parser()
    ast = p_no_ext("[text][label]\n\n[label]: /url")
    @test html(ast) == "<p><a href=\"/url\">text</a></p>\n"
    @test markdown(ast) == "[text](/url)\n"  # converted to inline

    # All three styles together
    ast = p(
        """
        [full][label]
        [collapsed][]
        [shortcut]

        [label]: /url1
        [collapsed]: /url2
        [shortcut]: /url3
        """
    )
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

@testitem "referencelinks multibyte label" tags = [:extensions, :referencelinks] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())

    # Regression: a multibyte label must not crash the parse (byte-vs-char index).
    ast = p("[😀]: http://x.com\n\n[😀]")
    @test html(ast) == "<p><a href=\"http://x.com\">😀</a></p>\n"

    ast = p("[日本語]: http://x.com\n\n[日本語]")
    @test html(ast) == "<p><a href=\"http://x.com\">日本語</a></p>\n"
end

@testitem "referencelinks label survives escaping" tags = [:extensions, :referencelinks] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())

    # A shortcut or collapsed reference spells its own label, so escaping the
    # link text can leave it pointing at a definition that no longer matches.
    @test Utilities.faithful(p, "[foo*]: /url\n\n*[foo*]\n")
    @test Utilities.faithful(p, "[Foo*bar\\]]:my_(url) 'title (with parens)'\n\n[Foo*bar\\]]\n")
    @test Utilities.faithful(p, "[foo*]: /url\n\n[foo*][]\n")

    # A label needing no escaping keeps its original style.
    @test markdown(p("[foo]: /url\n\n[foo]\n")) == "[foo]: /url\n\n[foo]\n"
    @test markdown(p("[foo]: /url\n\n[foo][]\n")) == "[foo]: /url\n\n[foo][]\n"
end

@testitem "referencelinks label the text cannot spell" tags = [:extensions, :referencelinks] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())

    # An entity in the label spells a character the text writes back plainly, so
    # the shortcut and collapsed forms give up their label and name it in full.
    @test Utilities.faithful(p, "[a&amp;b]: /url\n\n[a&amp;b]\n")
    @test Utilities.faithful(p, "[a&amp;b]: /url\n\n[a&amp;b][]\n")
    @test markdown(p("[a&amp;b]: /url\n\n[a&amp;b]\n")) ==
        "[a&amp;b]: /url\n\n[a\\&b][a&amp;b]\n"

    # Typographic replacement rewrites the text the same way.
    smart = create_parser([ReferenceLinkRule(), TypographyRule()])
    @test Utilities.faithful(smart, "[a\"b]: /url\n\n[a\"b]\n")
    @test Utilities.faithful(smart, "[a--b]: /url\n\n[a--b]\n")
    @test Utilities.faithful(smart, "[a...b]: /url\n\n[a...b]\n")
end

@testitem "referencelinks definitions" tags = [:extensions, :referencelinks] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())
    plain = Parser()

    # A definition cannot interrupt a paragraph, with or without the rule.
    text = "foo\n[bar]: /url\nbaz\n"
    @test html(p(text)) == html(plain(text))

    # A definition reaches the output whatever shape it was written in.
    @test Utilities.faithful(p, "[foo]: /url\n\n[foo]\n")
    @test Utilities.faithful(p, "[foo]:\n/url\n\n[foo]\n")
    @test Utilities.faithful(p, "   [foo]: \n      /url  \n           'the title'  \n\n[foo]\n")
    @test Utilities.faithful(p, "[Foo bar]:\n<my url>\n'title'\n\n[Foo bar]\n")
    @test Utilities.faithful(p, "[foo]: <>\n\n[foo]\n")
    @test Utilities.faithful(p, "[Foo\n  bar]: /url\n\n[Baz][Foo bar]\n")
    @test Utilities.faithful(p, "[foo]: /url '\ntitle\nline1\nline2\n'\n\n[foo]\n")

    # Each definition keeps its own destination, first one wins for resolution.
    ast = p("[foo]: /first\n[foo]: /second\n\n[foo]\n")
    definitions = [n.t for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test [d.destination for d in definitions] == ["/first", "/second"]
    @test html(ast) == "<p><a href=\"/first\">foo</a></p>\n"

    # A setext underline takes the definitions out of the paragraph above it,
    # and the emptied paragraph leaves nothing behind.
    ast = p("[foo]: /url\n---\n")
    @test html(ast) == "<hr />\n"
    @test markdown(ast) == "[foo]: /url\n\n* * *\n"
    @test Utilities.faithful(p, "[foo]: /url\n---\n")
end

@testitem "referencelinks definition positions" tags = [:extensions, :referencelinks] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())

    # Definitions taken from one paragraph each report the span they occupied,
    # not the span of the paragraph that held them.
    ast = p("[a]: /1\n[b]: /2\n\ntext\n")
    positions = [n.sourcepos for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test positions == [((1, 2), (1, 7)), ((2, 2), (2, 7))]

    # A definition written over two lines spans both of them.
    ast = p("[a]:\n/1\n\ntext\n")
    positions = [n.sourcepos for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test positions == [((1, 2), (2, 2))]

    # A container holds its content away from the start of the line, so a
    # definition inside one is measured against the same columns as the block
    # that held it.
    ast = p("> [a]: /1\n")
    positions = [n.sourcepos for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test positions == [((1, 4), (1, 9))]

    ast = p("- [a]: /1\n")
    positions = [n.sourcepos for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test positions == [((1, 4), (1, 9))]

    ast = p("> [a]:\n> /1\n")
    positions = [n.sourcepos for (n, e) in ast if e && n.t isa CommonMark.ReferenceDefinition]
    @test positions == [((1, 4), (2, 4))]
end

@testitem "referencelinks definitions inside a block quote" tags =
    [:extensions, :referencelinks] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(ReferenceLinkRule())

    # A label and a title can hold newlines, and every line a definition writes
    # starts with the margin of the block that holds it.
    @test markdown(p("> [a\n> b]: /url \"ti\n> tle\"\n")) ==
        "> [a\n> b]: /url \"ti\n> tle\"\n"
    @test Utilities.faithful(p, "> [a\n> b]: /url \"ti\n> tle\"\n")
    @test Utilities.faithful(p, "> [a\n> b]: /url\n>\n> [a b]\n")
end
