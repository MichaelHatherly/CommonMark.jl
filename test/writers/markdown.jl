@testitem "markdown_writer" tags = [:writers, :markdown] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser()
    test = test_single_format(pwd(), p)

    function test_with_roundtrip(filename, text)
        test(filename, text, markdown)
        # Also test round-trip
        ast = p(text)
        output = markdown(ast)
        @test markdown(p(output)) == output # Is markdown output round-trip-able?
    end

    # Code blocks.
    test_with_roundtrip("references/markdown/code.md", "`code`")
    # Inline HTML.
    test_with_roundtrip("references/markdown/inline_html.md", "<em>text</em>")
    # Links.
    test_with_roundtrip("references/markdown/link.md", "[link](url)")
    # Images.
    test_with_roundtrip("references/markdown/image.md", "![link](url)")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_star.md", "*text*")
    # Strong.
    test_with_roundtrip("references/markdown/strong_star.md", "**text**")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_underscore.md", "_text_")
    # Strong.
    test_with_roundtrip("references/markdown/strong_underscore.md", "__text__")
    # Emphasis.
    test_with_roundtrip("references/markdown/emphasis_nested.md", "_**text**_")
    # Strong.
    test_with_roundtrip("references/markdown/strong_nested.md", "*__text__*")
    # Headings.
    test_with_roundtrip("references/markdown/h1.md", "# h1")
    test_with_roundtrip("references/markdown/h2.md", "## h2")
    test_with_roundtrip("references/markdown/h3.md", "### h3")
    test_with_roundtrip("references/markdown/h4.md", "#### h4")
    test_with_roundtrip("references/markdown/h5.md", "##### h5")
    test_with_roundtrip("references/markdown/h6.md", "###### h6")
    # Block quotes.
    test_with_roundtrip("references/markdown/blockquote.md", "> quote")
    test_with_roundtrip("references/markdown/blockquote_empty.md", ">")
    # Lists.
    test_with_roundtrip(
        "references/markdown/list_nested_ordered.md",
        "1. one\n2. 5. five\n   6. six\n3. three\n4. four\n",
    )
    test_with_roundtrip(
        "references/markdown/list_nested_unordered.md",
        "- - - - - - - item",
    )
    # Issue #43: nested list with content before it should not add blank lines
    test_with_roundtrip(
        "references/markdown/list_nested_with_content.md",
        "- item 1\n  + nested 1\n  + nested 2\n- item 2\n",
    )
    test_with_roundtrip("references/markdown/list_empty_bullet.md", "  - ")
    test_with_roundtrip("references/markdown/list_empty_ordered.md", "1. ")
    test_with_roundtrip(
        "references/markdown/list_with_empty_item.md",
        "  - one\n  - \n  - three\n",
    )
    test_with_roundtrip(
        "references/markdown/list_ordered_with_empty.md",
        "1. one\n2.\n3. three",
    )
    # Thematic Breaks.
    test_with_roundtrip("references/markdown/thematic_break.md", "***")
    # Code blocks.
    test_with_roundtrip(
        "references/markdown/code_block_fenced_julia.md",
        """
        ```julia
        code
        ```
        """,
    )
    test_with_roundtrip(
        "references/markdown/code_block_indented.md",
        """
            code
        """,
    )
    test_with_roundtrip(
        "references/markdown/code_block_jldoctest.md",
        """
        ```jldoctest
        julia> a = 1
        1

        julia> b = 2
        2
        ```
        """,
    )
    test_with_roundtrip(
        "references/markdown/code_block_jldoctest_escapes.md",
        """
        ```jldoctest; filter="a\\\\.b"
        julia> a = 1
        1
        ```

        ```jldoctest
        julia> name = :hello; @varname(x.\\\$name)
        x.hello
        ```
        """,
    )
    test_with_roundtrip(
        "references/markdown/code_block_indented_julia.md",
        """
            julia> a = 1
            1

            julia> b = 2
            2
        """,
    )
    # Escapes.
    test_with_roundtrip("references/markdown/escape_backslash.md", "\\\\")
    test_with_roundtrip("references/markdown/escape_backtick.md", "\\`x\\`")

    # Link title with quotes - must escape for valid markdown output
    ast = p("[link](/url \"Title \\\"quoted\\\"\")")
    md = markdown(ast)
    @test occursin("\\\"", md)  # quotes escaped
    @test markdown(p(md)) == md  # roundtrip works

    # Multi-line setext heading roundtrip: SoftBreak collapses to space in ATX
    ast = p("heading\ncontinued\n======")
    md = markdown(ast)
    @test markdown(p(md)) == md

    # Inline code backtick handling - use odd counts to avoid math syntax
    # No backticks in content → single backtick delimiter
    @test markdown(p("`simple`")) == "`simple`\n"
    # Single backtick in content → triple delimiter with padding
    @test markdown(p("`` `tick` ``")) == "``` `tick` ```\n"
    # Double backticks in content → triple delimiter (no edge backticks, no padding)
    @test markdown(p("``` ``ticks`` ```")) == "``` ``ticks`` ```\n"
    # Triple backticks in content → 5 delimiter with padding
    @test markdown(p("````` ```ticks``` `````")) == "````` ```ticks``` `````\n"
    # Mixed single and double → triple (max run is 2), no edge backticks
    @test markdown(p("``` `` and ` ```")) == "``` `` and ` ```\n"

    # Raw inline HTML round-trip: fence must exceed the longest internal backtick run
    rawp = create_parser(RawContentRule())
    for content in ["plain", "a`b", "a``b", "a```b", "`x`", "x`", "`x", "``", "`{=html}`"]
        doc = CommonMark.Node(CommonMark.Document())
        para = CommonMark.Node(CommonMark.Paragraph())
        raw = CommonMark.Node(CommonMark.HtmlInline(raw = true))
        raw.literal = content
        CommonMark.append_child(para, raw)
        CommonMark.append_child(doc, para)
        out = markdown(doc)
        lit = nothing
        for (n, ent) in rawp(out)
            n.t isa CommonMark.HtmlInline && ent && (lit = n.literal)
        end
        @test lit == content
    end
end

@testitem "markdown_writer_escaping" tags = [:writers, :markdown] setup = [Utilities] begin
    using CommonMark
    using Test

    p = Parser()
    faithful(text) = Utilities.faithful(p, text)

    # Issue #179: an indented line continues the paragraph, so the bullet is
    # text. Dropping the indent must not turn it back into a list.
    @test faithful("a\n    - b")

    # Text that never passed through a backslash escape still needs escaping.
    @test faithful("&#35; hi")
    @test faithful("&#42;foo&#42;\n*foo*\n")
    @test faithful("&#42; foo\n\n* foo\n")
    @test faithful("&#91;a&#93;(b)")
    @test faithful("&amp;amp;")
    @test faithful("&#96;foo&#96;")

    # Control characters have no literal Markdown spelling.
    @test faithful("&#9;foo")
    @test faithful("foo&#10;&#10;bar")

    # A tab away from both ends of a line marks nothing, so it stays a tab.
    @test faithful("a\tb")
    @test occursin("a\tb", markdown(p("a\tb")))

    # Block starters at the beginning of a continuation line.
    @test faithful("Foo\n    ***\n")
    @test faithful("foo\n    # bar\n")
    @test faithful("Foo\n    ---\n")
    @test faithful("> foo\nbar\n===\n")
    @test faithful("foo\n    1. bar\n")
    @test faithful("foo\n    > bar\n")

    # A digit opens an ordered list only where its marker follows, so the digits
    # keep the line-start rules alive for `.` and `)` alone. Every other
    # character after them is mid-line and spells nothing.
    @test faithful("1. item\n")
    @test faithful("1&#46; not a list\n")
    @test markdown(p("1 + 1\n")) == "1 + 1\n"
    @test markdown(p("1 > 2\n")) == "1 > 2\n"
    @test markdown(p("1 # 2\n")) == "1 # 2\n"

    # A marker at the end of a line opens a block just as one at the end of the
    # document does.
    @test faithful("foo\n&#61;")
    @test faithful("foo\n&#45;")
    @test faithful("foo\n&#35;")
    @test faithful("&#42;")
    @test faithful("&#45;")
    @test faithful("&#43;")
    @test faithful("> foo\n> &#61;")
    @test faithful("- foo\n  &#61;")

    # A whitespace-surrounded underscore delimits no emphasis but still breaks
    # a thematic line.
    @test faithful("&#95; &#95; &#95;")

    # Both fence characters open a code block.
    @test faithful("&#126;&#126;&#126;")
    @test faithful("x\n&#126;&#126;&#126;")

    # Whitespace before a line end is dropped by the parser, and a pair of it
    # becomes a hard break.
    @test faithful("a&#32;")
    @test faithful("a&#32;&#32;&#32;\nb")
    # The space is content, not a hard break the writer can spell as two spaces.
    @test !occursin("  \n", markdown(p("a&#32;&#32;&#32;\nb")))

    # Link destinations and titles carry their own delimiters.
    @test faithful("[link](foo\\(and\\(bar\\))")
    @test faithful("[link](foo\\)\\:)")
    @test faithful("[a](<b)c>)")
    @test faithful("[a](url &quot;tit&quot;)")
    @test faithful("[a](b \"tit\\\\\\\"le\")")
    # A backtick in a title would open a code span across the whole link, and
    # angle brackets would close the bracketed form of the destination.
    @test faithful("[a](b \"ti&#96;t&#96; &#60;le&#62;\")")

    # A line ending fits neither destination form: bare it delimits the
    # destination, bracketed it is not allowed. Percent encoding spells it.
    link = CommonMark.Node(CommonMark.Link, "x"; dest = "a\nb")
    doc = CommonMark.Node(CommonMark.Document, CommonMark.Node(CommonMark.Paragraph, link))
    @test markdown(doc) == "[x](a%0Ab)\n"
    @test occursin("href=\"a%0Ab\"", html(p(markdown(doc))))

    # A backslash escape only hides ASCII punctuation, which is what the parser
    # reads back as the character itself.
    @test all(Char(0):Char(127)) do c
        CommonMark.is_ascii_punct(c) ==
            occursin(Regex(CommonMark.ESCAPABLE), string(c))
    end
end

@testitem "markdown_writer_structure" tags = [:writers, :markdown] setup = [Utilities] begin
    using CommonMark
    using Test

    p = Parser()
    faithful(text) = Utilities.faithful(p, text)

    # An autolink is written back as an autolink, not as an inline link whose
    # text needs escaping.
    @test markdown(p("<https://example.com>")) == "<https://example.com>\n"
    @test markdown(p("<foo@bar.example.com>")) == "<foo@bar.example.com>\n"
    @test faithful("<https://example.com?find=\\*>")
    @test faithful("<https://foo.bar.`baz>`")
    @test faithful("[foo<https://example.com/?search=](uri)>")

    # A link whose text repeats its destination is only an autolink when the
    # angle bracket form spells one; otherwise the brackets read as raw HTML.
    @test faithful("[foo](foo)")
    @test faithful("[/url](/url)")
    @test faithful("[a b](a%20b)")
    @test faithful("[www.x.com](www.x.com)")
    @test faithful("[#frag](#frag)")
    # Text carrying its own `>` would close the brackets early.
    @test faithful("[https://a>b](https://a%3Eb)")

    # A code span keeps the spaces that its delimiters would otherwise strip.
    @test faithful("`  ``  `")
    @test faithful("` a `")
    @test faithful("`  `")

    # An empty code span has no spelling of its own, so it holds one space.
    empty_code = CommonMark.Node(
        CommonMark.Document,
        CommonMark.Node(CommonMark.Paragraph, CommonMark.Node(CommonMark.Code, "")),
    )
    @test markdown(empty_code) == "` `\n"

    # A hand-built code block carries a fence, and the closing one starts its
    # own line even when the content does not end with one.
    block = CommonMark.Node(CommonMark.CodeBlock, "foo")
    @test markdown(CommonMark.Node(CommonMark.Document, block)) == "```\nfoo\n```\n"
    tagged = CommonMark.Node(CommonMark.CodeBlock, "foo\n"; info = "julia")
    @test markdown(CommonMark.Node(CommonMark.Document, tagged)) ==
        "```julia\nfoo\n```\n"

    # Content the fence does not clear would close the block early, so the
    # fence grows past the longest run the content holds.
    nested = CommonMark.Node(CommonMark.CodeBlock, "```\nx\n```\n")
    rendered = markdown(CommonMark.Node(CommonMark.Document, nested))
    @test rendered == "````\n```\nx\n```\n````\n"
    reparsed = p(rendered).first_child
    @test reparsed.t isa CommonMark.CodeBlock
    @test reparsed.literal == nested.literal

    # A tilde fence is closed by tildes, so backticks in its content leave it
    # alone.
    @test faithful("~~~\n```\nx\n```\n~~~\n")

    # Only an indented code block merges with the indentation of the block after
    # it, so a fenced one leaves the next block free to indent.
    @test markdown(p("```\nfenced\n```\n\n    indented\n")) ==
        "```\nfenced\n```\n\n    indented\n"

    # Sibling lists stay separate documents rather than merging into one list.
    @test faithful("- foo\n- bar\n+ baz\n")
    @test faithful("1. foo\n2. bar\n3) baz\n")

    # An indented code block cannot follow a list, and cannot carry a line of
    # significant spaces, so those are written fenced.
    @test faithful("    chunk1\n      \n      chunk2\n")
    @test faithful(" -    one\n\n     two\n")
    @test faithful("1. a\n\n  2. b\n\n    3. c\n")

    # A heading holds a single line, so multi-line content needs setext form.
    @test faithful("Foo *bar\nbaz*\n====\n")
    @test faithful("Foo\nBar\n---\n")

    # An ATX heading has nowhere to put a break, so one in a hand-built heading
    # closes up to a space. That loses the break, so it is deliberately not
    # faithful.
    heading = CommonMark.Node(
        CommonMark.Document,
        CommonMark.Node(
            CommonMark.Heading,
            3,
            "Foo",
            CommonMark.Node(CommonMark.SoftBreak),
            "Bar",
        ),
    )
    @test markdown(heading) == "### Foo Bar\n"
end
