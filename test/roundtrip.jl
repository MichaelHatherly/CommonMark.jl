@testitem "roundtrip" tags = [:roundtrip] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    roundtrip_dir = joinpath(@__DIR__, "roundtrip")

    # Test with all extensions enabled
    extensions = [
        AdmonitionRule(),
        AttributeRule(),
        AutoIdentifierRule(),
        CitationRule(),
        DollarMathRule(),
        FencedDivRule(),
        FootnoteRule(),
        FrontMatterRule(),
        GitHubAlertRule(),
        MathRule(),
        RawContentRule(),
        ReferenceLinkRule(),
        StrikethroughRule(),
        SubscriptRule(),
        SuperscriptRule(),
        TableRule(),
        TaskListRule(),
        TypographyRule(),
    ]
    p = create_parser(extensions)

    input_file = joinpath(roundtrip_dir, "input.md")
    output_file = joinpath(roundtrip_dir, "output.md")
    ast_file = joinpath(roundtrip_dir, "ast.txt")

    input = read(input_file, String)
    input = replace(input, "\r\n" => "\n")

    ast_input = p(input)
    actual_output = markdown(ast_input)

    # Reference test against expected canonical output
    @test_reference output_file actual_output

    # Reference test AST structure
    @test_reference ast_file sprint(CommonMark.ast_dump, ast_input)

    # Output is stable (already canonical)
    @test markdown(p(actual_output)) == actual_output

    # No trailing whitespace except hard breaks (exactly two spaces)
    for (i, line) in enumerate(split(actual_output, '\n'))
        trailing = length(line) - length(rstrip(line))
        if trailing > 0
            @test trailing == 2 # only two-space hard breaks allowed
        end
    end
end
