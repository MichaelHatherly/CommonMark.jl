@testitem "roundtrip" tags = [:roundtrip] setup = [Utilities] begin
    using CommonMark
    using Test

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

    for file in readdir(roundtrip_dir; join = true)
        endswith(file, ".md") || continue
        name = basename(file)

        @testset "$name" begin
            input = read(file, String)
            input = replace(input, "\r\n" => "\n")

            ast1 = p(input)
            output = markdown(ast1)
            ast2 = p(output)

            # Output should match input (file is canonical)
            @test output == input

            # AST shape should be preserved after roundtrip
            @test CommonMark.ast_equal(ast1, ast2)

            # No trailing whitespace
            @test !occursin(r" +\n", output)

            # No trailing whitespace at end of file (except single newline)
            @test !occursin(r" +$", output)
        end
    end
end
