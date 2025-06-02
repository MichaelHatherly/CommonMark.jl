@testset "Typography" begin
    using ReferenceTests

    # Helper function for tests that can use references
    function test_typography(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/typography/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    p = Parser()
    enable!(p, TypographyRule())

    # Basic typography replacements
    text = "\"Double quotes\", 'single quotes', ellipses...., and-- dashes---"
    ast = p(text)
    test_typography("basic", ast)
end
