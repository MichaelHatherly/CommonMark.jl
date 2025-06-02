@testset "Admonitions" begin
    using ReferenceTests

    p = Parser()
    enable!(p, AdmonitionRule())

    # Helper function to test all output formats
    function test_admonition(
        base_name,
        text,
        parser = p;
        formats = [:html, :latex, :term, :markdown, :typst],
    )
        exts = Dict(
            :html => "html.txt",
            :latex => "tex",
            :term => "txt",
            :markdown => "md",
            :typst => "typ",
        )
        funcs = Dict(
            :html => html,
            :latex => latex,
            :term => term,
            :markdown => markdown,
            :typst => typst,
        )
        ast = parser(text)
        for format in formats
            ext = exts[format]
            func = funcs[format]
            filename = "references/admonitions/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    # Basic warning admonition
    test_admonition(
        "warning_basic",
        """
        !!! warning

            text
        """,
    )

    # Warning with tab-indented content
    test_admonition(
        "warning_tab_indent",
        """
        !!! warning

        \ttext
        """,
    )

    # Info admonition with custom title
    test_admonition(
        "info_custom_title",
        """
        !!! info "Custom Title"

            text
        """,
    )

    # Warning with attributes (id)
    p_with_attrs = enable!(Parser(), [AdmonitionRule(), AttributeRule()])
    test_admonition(
        "warning_with_id",
        """
        {#id}
        !!! warning

            text
        """,
        p_with_attrs;
        formats = [:html, :latex],
    )
end
