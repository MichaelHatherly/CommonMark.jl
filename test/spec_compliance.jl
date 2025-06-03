@testitem "spec_compliance" tags = [:spec, :core] begin
    using CommonMark
    using Test
    using JSON

    # Do we pass the CommonMark spec -- version 0.29.0.
    for case in JSON.Parser.parsefile(joinpath(@__DIR__, "spec.json"))
        p = Parser()
        ast = p(case["markdown"])
        @test case["html"] == html(ast)
        # The following just make sure we don't throw on the other
        # rendering. Proper tests are found below.
        latex(ast)
        term(ast)
    end
end
