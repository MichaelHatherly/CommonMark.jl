@testitem "citations" tags = [:extensions, :citations] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    using JSON

    p = create_parser(CitationRule())
    bib = JSON.parsefile(joinpath(pwd(), "citations.json"))
    test_citations = test_all_formats(pwd())

    function test(bib, ast, base_name)
        env = Dict{String,Any}("references" => bib)
        test_citations(base_name, ast, "citations", env = env)
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
    p = create_parser([CitationRule(), AttributeRule()])

    text = """
           {#refs}
           # The reference list.
           """
    test(bib, p(text), "reference_list")
end
