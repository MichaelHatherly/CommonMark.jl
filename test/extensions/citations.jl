@testitem "citations" tags = [:extensions, :citations] begin
    using CommonMark
    using Test
    using ReferenceTests
    using JSON

    p = enable!(Parser(), CitationRule())
    bib = JSON.parsefile(joinpath(@__DIR__, "citations.json"))

    test = function (bib, ast, base_name)
        env = Dict{String,Any}("references" => bib)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/citations/$(base_name).$(ext)"
            output = func(ast, env)
            @test_reference filename Text(output)
        end
    end

    # Unbracketed citations.

    # Missing bibliography data.
    test(bib, p("@unknown"), "unbracketed_unknown")

    # Single author.
    test(bib, p("@innes2018"), "unbracketed_single")

    # Two authors.
    test(bib, p("@lubin2015"), "unbracketed_two")

    # Many authors.
    test(bib, p("@bezanson2017"), "unbracketed_many")

    # Bracketed citations.

    # Missing bibliography data.
    test(bib, p("[@unknown]"), "bracketed_unknown")

    # Single author.
    test(bib, p("[@innes2018]"), "bracketed_single")

    # Two authors.
    test(bib, p("[@lubin2015]"), "bracketed_two")

    # Many authors.
    test(bib, p("[@bezanson2017]"), "bracketed_many")

    # Reference lists.
    p = enable!(Parser(), [CitationRule(), AttributeRule()])

    text = """
           {#refs}
           # The reference list.
           """
    test(bib, p(text), "reference_list")
end
