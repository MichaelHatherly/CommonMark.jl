@testitem "multiple_extensions" tags = [:integration] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    using YAML

    test_integration = test_all_formats(pwd())

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
    p = create_parser(extensions)
    ast = open(p, joinpath(@__DIR__, "integration.md"))

    # Test all output formats
    test_integration("multiple_extensions", ast, "integration")

    # Also keep the specific markdown output test for backward compatibility
    @test markdown(ast) ==
          replace(read(joinpath(@__DIR__, "integration_output.md"), String), "\r" => "")
end
