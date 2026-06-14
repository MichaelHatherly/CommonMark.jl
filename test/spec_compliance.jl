@testitem "spec_compliance" tags = [:spec, :core] begin
    using CommonMark
    using Test
    using JSON

    # Do we pass the CommonMark spec -- version 0.31.2.
    for case in JSON.parsefile(joinpath(@__DIR__, "spec.json"))
        p = Parser()
        ast = p(case["markdown"])
        @test case["html"] == html(ast)
        # The following just make sure we don't throw on the other
        # rendering. Proper tests are found below.
        latex(ast)
        term(ast)
        typst(ast)
        markdown(ast)
        notebook(ast)
    end
end

@testitem "markdown round-trip" tags = [:spec, :markdown] begin
    using CommonMark
    using Test
    using JSON

    # The markdown writer must escape exactly enough that its output re-parses to
    # the same document: re-parsing the markdown renders identical HTML to the
    # original, and the output is canonical (idempotent). This guards the
    # context-aware escaping against under-escaping over the whole spec suite.
    for case in JSON.parsefile(joinpath(@__DIR__, "spec.json"))
        p = Parser()
        ast = p(case["markdown"])
        md = markdown(ast)
        @test html(p(md)) == case["html"]
        @test markdown(p(md)) == md
    end
end
