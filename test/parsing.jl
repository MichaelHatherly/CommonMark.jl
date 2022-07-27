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
    @test CommonMark.is_same_rule(LinkRule(), LinkRule())
    @test CommonMark.is_same_rule(FootnoteRule(), FootnoteRule())
    @test !CommonMark.is_same_rule(FootnoteRule(), LinkRule())
    let fn = CommonMark.is_same_rule(LinkRule())
        @test fn(LinkRule())
        @test !fn(FootnoteRule())
    end
    let fnrule1 = FootnoteRule(), fnrule2 = FootnoteRule()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
        fnrule1.cache["foo"] = CommonMark.Node()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
        fnrule2.cache["bar"] = CommonMark.Node()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
    end

    are_rules_unique(p::Parser) = p.rules == unique(p.rules)
    let p = Parser()
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), TableRule())
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), [TableRule(), FootnoteRule()])
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    @test_throws ErrorException enable!(Parser(), LinkRule())
    @test_throws ErrorException enable!(Parser(), [LinkRule(), ImageRule()])
    @test_throws ErrorException enable!(Parser(), [LinkRule(), FootnoteRule()])
    let p = disable!(Parser(), LinkRule())
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test !CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), ImageRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test !CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test !CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), TableRule())
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test !CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [TableRule(), FootnoteRule()])
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test !CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), FootnoteRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(),  p.rules)
        @test !CommonMark.ruleoccursin(TableRule(),  p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(),  p.rules)
        @test are_rules_unique(p)
    end
end
