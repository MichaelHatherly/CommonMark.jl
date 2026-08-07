@testitem "footnotes" tags = [:extensions, :footnotes] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(FootnoteRule())
    test_footnote = test_all_formats(pwd())

    # Links
    test_footnote("link_only", p("text[^1]"), "footnotes")

    # Definitions
    test_footnote("definition_only", p("[^1]: text"), "footnotes")

    # Link with definition
    test_footnote(
        "link_with_definition",
        p("text[^1].\n\n[^1]: text"),
        "footnotes",
        formats = [:latex, :typst, :markdown],
    )

    # Footnote with attributes
    p_with_attrs = create_parser([FootnoteRule(), AttributeRule()])
    test_footnote(
        "link_with_id",
        p_with_attrs("text[^1]{#id}"),
        "footnotes",
        formats = [:html],
    )

    # Definition with attributes
    test_footnote(
        "definition_with_attrs",
        p_with_attrs(
            """
            {key="value"}
            [^1]: text
            """
        ),
        "footnotes",
        formats = [:html],
    )

    # Full footnote with attributes
    test_footnote(
        "full_with_attrs",
        p_with_attrs(
            """
            text[^1]{#id}.

            {key="value"}
            [^1]: text
            """
        ),
        "footnotes",
        formats = [:html, :latex, :typst],
    )

    # Definition with blank line and spaces
    test_footnote("definition_blank_spaces", p("[^1]:\n\n    text"), "footnotes")

    # Definition with blank line and tab
    test_footnote("definition_blank_tab", p("[^1]:\n\n\ttext"), "footnotes")
end

@testitem "footnote definitions do not outlive their document" tags =
    [:extensions, :footnotes] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(FootnoteRule())

    # The definition reaches the link that references it, and the rendering
    # happens before the next document is parsed.
    first = p("x[^1]\n\n[^1]: note\n")
    @test occursin("note", latex(first))

    # A reused parser starts each document with the definitions it was given,
    # so a reference the second document never defines stays unresolved.
    second = p("y[^1]\n")
    @test !occursin("note", latex(second))
end
