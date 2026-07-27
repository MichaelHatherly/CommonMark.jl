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

@testitem "spec_roundtrip" tags = [:spec, :core, :roundtrip] setup = [Utilities] begin
    using CommonMark
    using Test
    using JSON

    cases = JSON.parsefile(joinpath(@__DIR__, "spec.json"))

    # Markdown output has to reparse as the document it came from. Compare HTML
    # because it is the spec-defined rendering of the AST. Extensions claim
    # syntax the core spec reads as text, so run the suite both ways. Rule state
    # can outlive a parse, so every case gets a fresh parser.
    parsers = ("core" => () -> Parser(), "extensions" => () -> create_parser(EXTENSIONS))
    for case in cases, (name, make_parser) in parsers
        @testset "example $(case["example"]) ($name)" begin
            p = make_parser()
            ast = p(case["markdown"])
            @test html(p(markdown(ast))) == html(ast)
        end
    end

    # Without extensions the spec's own expected HTML is the target.
    for case in cases
        @testset "example $(case["example"])" begin
            p = Parser()
            @test html(p(markdown(p(case["markdown"])))) == case["html"]
        end
    end
end
