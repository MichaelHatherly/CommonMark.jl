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
    writers = [
        html, latex, term, markdown, notebook
    ]
    @precompile_all_calls begin
        parser = Parser()
        for rule in extension_rules
            enable!(parser, rule())
        end
        ast = parser("Hello *world*")
        for writer in writers
            writer(ast)
        end
    end
end
