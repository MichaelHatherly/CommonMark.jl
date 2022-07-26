@testset "Parsing" begin
    # AST metadata via keywords.
    p = Parser()
    ast = p(""; empty=true)
    @test ast.meta["empty"] == true

    # Parsing file contents.
    readme = joinpath(@__DIR__, "../README.md")
    ast = open(p, readme)
    @test ast.meta["source"] == readme
    @test ast.first_child.t isa CommonMark.Heading

    # Parsing contents of a buffer.
    buffer = IOBuffer("# heading")
    ast = p(buffer)
    @test ast.first_child.t isa CommonMark.Heading
    @test markdown(ast) == "# heading\n"

    # Disabling parser rules.
    p = disable!(Parser(), CommonMark.AtxHeadingRule())
    ast = p("# *not a header*")
    @test ast.first_child.t isa CommonMark.Paragraph
    @test ast.first_child.first_child.nxt.t isa CommonMark.Emph
    @test markdown(ast) == "# *not a header*\n"

    # Make sure that enable! or disable! do not create duplicate rules
    # https://github.com/MichaelHatherly/CommonMark.jl/issues/45
    are_rules_unique(p::Parser) = p.rules == unique(p.rules)
    let p = Parser()
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), TableRule())
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∈ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), [TableRule(), FootnoteRule()])
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∈ p.rules
        @test FootnoteRule() ∈ p.rules
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), LinkRule())
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), [LinkRule(), ImageRule()])
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), [LinkRule(), FootnoteRule()])
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∈ p.rules
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), LinkRule())
        @test LinkRule() ∉ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), ImageRule()])
        @test LinkRule() ∉ p.rules
        @test ImageRule() ∉ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), TableRule())
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [TableRule(), FootnoteRule()])
        @test LinkRule() ∈ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), FootnoteRule()])
        @test LinkRule() ∉ p.rules
        @test ImageRule() ∈ p.rules
        @test TableRule() ∉ p.rules
        @test FootnoteRule() ∉ p.rules
        @test are_rules_unique(p)
    end
end
