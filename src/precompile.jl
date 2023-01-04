using SnoopPrecompile

@precompile_all_calls begin
    parser = Parser()
    # Enable all non-default (i.e. extension) rules
    for rule in [
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
        enable!(parser, rule())
    end
    ast = parser("Hello *world*")
    for writer in [html, latex, term, markdown, notebook]
        writer(ast)
    end
end
