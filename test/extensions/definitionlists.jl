@testitem "definitionlists" tags = [:extensions, :definitionlists] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(DefinitionListRule())
    test_dl = test_all_formats(pwd())

    # Basic tight definition
    test_dl("tight_single", p("Term\n:   Definition"), "definitionlists")

    # Multiple definitions per term
    test_dl(
        "tight_multi_def",
        p("Term\n:   Definition 1\n:   Definition 2"),
        "definitionlists",
    )

    # Multiple terms
    test_dl(
        "tight_multi_term",
        p("Term 1\n:   Definition 1\n\nTerm 2\n:   Definition 2"),
        "definitionlists",
    )

    # Loose definition (blank line between term and :)
    test_dl("loose_single", p("Term\n\n:   Definition"), "definitionlists")

    # Inline formatting in terms
    test_dl("term_inline", p("*Emphasized* term\n:   Definition"), "definitionlists")

    # Block content in definitions (multi-paragraph)
    test_dl(
        "block_content",
        p("Term\n:   Paragraph 1\n\n    Paragraph 2"),
        "definitionlists",
    )

    # Nested list in definition
    test_dl(
        "nested_list",
        p("Term\n:   Definition\n\n    - item 1\n    - item 2"),
        "definitionlists",
    )

    # Definition list in blockquote
    test_dl("in_blockquote", p("> Term\n> :   Definition"), "definitionlists")

    # Adjacent definition lists merge
    @testset "adjacent lists merge" begin
        ast = p("Term 1\n:   Def 1\n\nTerm 2\n:   Def 2")
        # Should be a single DefinitionList containing both terms
        child = ast.first_child
        @test child.t isa CommonMark.DefinitionList
        # Count children: should have 2 terms + 2 descriptions = 4
        count = 0
        c = child.first_child
        while !CommonMark.isnull(c)
            count += 1
            c = c.nxt
        end
        @test count == 4
    end

    # Roundtrip test
    @testset "markdown roundtrip" begin
        input = "Term\n:   Definition\n"
        ast = p(input)
        md_out = markdown(ast)
        ast2 = p(md_out)
        @test html(ast) == html(ast2)
    end

    # Edge: definition marker without preceding term
    @testset "no preceding term" begin
        ast = p(":   orphan definition")
        # Should not create a definition list
        @test html(ast) == "<p>:   orphan definition</p>\n"
    end

    # Tight vs loose HTML check
    @testset "tight suppresses p tags" begin
        out = html(p("Term\n:   Definition"))
        @test occursin("<dl>", out)
        @test occursin("<dt>", out)
        @test occursin("<dd>", out)
        @test !occursin("<p>", out)
    end

    @testset "loose wraps in p tags" begin
        out = html(p("Term\n\n:   Definition"))
        @test occursin("<dl>", out)
        @test occursin("<p>Definition</p>", out)
    end

    # JSON output
    @testset "json output" begin
        j = json(p("Term\n:   Definition"))
        @test occursin("DefinitionList", j)
    end
end
