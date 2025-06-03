@testitem "unicode_handling" tags = [:unicode] begin
    using CommonMark
    using Test
    using ReferenceTests

    # Helper function for tests that can use references
    function test_unicode(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/unicodes/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    p = Parser()
    enable!(p, AdmonitionRule())

    # Unicode in admonition title
    text = "!!! note \"Ju 的文字\"\n    Ju\n"
    ast = p(text)
    test_unicode("admonition_unicode_title", ast)
end
