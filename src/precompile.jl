using SnoopPrecompile

@precompile_setup begin
    # All non-default rules
    extension_rules = [
        AdmonitionRule,
        AttributeRule,
        AutoIdentifierRule,
        CitationRule,
        DollarMathRule,
        FootnoteRule,
        FrontMatterRule,
        MathRule,
        RawContentRule,
        TableRule,
        TypographyRule,
    ]
    dummyfile = joinpath(@__DIR__, "precompilation", "integration-test.md")
    dummystr = read(dummyfile, String)
    writers = [
        html, latex, term, markdown, notebook
    ]
    @precompile_all_calls begin
        parser = Parser()
        for rule in extension_rules
            enable!(parser, rule())
        end
        ast = parser(dummystr)
        for writer in writers
            writer(ast)
        end
    end
end
