@testitem "multiple_extensions" tags = [:integration] begin
    using CommonMark
    using Test
    using ReferenceTests
    using YAML

    # Helper function for tests that can use references
    function test_integration(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/integration/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    extensions = [
        AdmonitionRule(),
        AttributeRule(),
        AutoIdentifierRule(),
        CitationRule(),
        FootnoteRule(),
        FrontMatterRule(yaml = YAML.load),
        MathRule(),
        RawContentRule(),
        TableRule(),
        TypographyRule(),
    ]
    p = enable!(Parser(), extensions)
    ast = open(p, joinpath(@__DIR__, "integration.md"))

    # Test all output formats
    test_integration("multiple_extensions", ast)

    # Also keep the specific markdown output test for backward compatibility
    @test markdown(ast) ==
          replace(read(joinpath(@__DIR__, "integration_output.md"), String), "\r" => "")
end
