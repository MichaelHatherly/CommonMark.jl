using PrecompileTools

@setup_workload begin
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
    writers = [html, latex, term, markdown, notebook]
    @compile_workload begin
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
