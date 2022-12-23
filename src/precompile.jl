using SnoopPrecompile

@precompile_all_calls begin
    parser = Parser()
    enable!(parser, FootnoteRule())
    ast = parser("Hello *world*")
    for writer in [html, latex, term, markdown, notebook]
        writer(ast)
    end
end
