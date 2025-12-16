using PrecompileTools

@setup_workload begin
    # All non-default rules
    extension_rules = [
        AdmonitionRule,
        AttributeRule,
        AutoIdentifierRule,
        CitationRule,
        DollarMathRule,
        FencedDivRule,
        FootnoteRule,
        FrontMatterRule,
        GitHubAlertRule,
        MathRule,
        RawContentRule,
        ReferenceLinkRule,
        StrikethroughRule,
        SubscriptRule,
        SuperscriptRule,
        TableRule,
        TaskListRule,
        TypographyRule,
    ]
    writers = [html, latex, term, markdown, notebook, typst]
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
