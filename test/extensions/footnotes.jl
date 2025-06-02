@testset "Footnotes" begin
    using ReferenceTests

    p = Parser()
    enable!(p, FootnoteRule())

    # Helper function to test all output formats
    function test_footnote(base_name, text, parser=p; formats=[:html, :latex, :typst, :term, :markdown])
        ast = parser(text)
        format_exts = [
            (:html, html, "html.txt"),
            (:latex, latex, "tex"),
            (:typst, typst, "typ"),
            (:term, term, "txt"),
            (:markdown, markdown, "md")
        ]
        for (format, func, ext) in format_exts
            if format in formats
                filename = "references/footnotes/$(base_name).$(ext)"
                output = func(ast)
                @test_reference filename Text(output)
            end
        end
    end

    # Links
    test_footnote("link_only", "text[^1]")

    # Definitions
    test_footnote("definition_only", "[^1]: text")

    # Link with definition
    test_footnote("link_with_definition", "text[^1].\n\n[^1]: text", formats=[:latex, :typst, :markdown])

    # Footnote with attributes
    p_with_attrs = enable!(Parser(), [FootnoteRule(), AttributeRule()])
    test_footnote("link_with_id", "text[^1]{#id}", p_with_attrs, formats=[:html])

    # Definition with attributes
    test_footnote("definition_with_attrs", """
           {key="value"}
           [^1]: text
           """, p_with_attrs, formats=[:html])

    # Full footnote with attributes
    test_footnote("full_with_attrs", """
           text[^1]{#id}.

           {key="value"}
           [^1]: text
           """, p_with_attrs, formats=[:html, :latex, :typst])

    # Definition with blank line and spaces
    test_footnote("definition_blank_spaces", "[^1]:\n\n    text")

    # Definition with blank line and tab
    test_footnote("definition_blank_tab", "[^1]:\n\n\ttext")
end
