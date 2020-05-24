using CommonMark, Test, JSON, Pkg.TOML, YAML

@testset "CommonMark" begin
    # Do we pass the CommonMark spec -- version 0.29.0.
    @testset "Spec" begin
        for case in JSON.Parser.parsefile(joinpath(@__DIR__, "spec.json"))
            p = CommonMark.Parser()
            h = CommonMark.Writer(CommonMark.HTML())
            ast = p(case["markdown"])
            html = h(ast, String)
            @test case["html"] == html
            # The following just make sure we don't throw on the other
            # rendering. Proper tests are found below.
            t = CommonMark.Writer(CommonMark.Term(), IOBuffer())
            t(ast)
            l = CommonMark.Writer(CommonMark.LaTeX())
            l(ast)
        end
    end

    include("writers.jl")
    include("extensions.jl")

    # Basics: just make sure the parsing and rendering doesn't throw or hang.
    @testset "Samples" begin
        for (root, dirs, files) in walkdir(joinpath(@__DIR__, "samples"))
            for file in files
                if endswith(file, ".md")
                    name = joinpath(root, file)
                    html = replace(read(splitext(name)[1] * ".html", String), "\r\n" => "\n")

                    p = CommonMark.Parser()
                    h = CommonMark.Writer(CommonMark.HTML())
                    ast = p(read(name, String))
                    out = h(ast, String)

                    @testset "$file" begin
                        @test out == html

                        # TODO: just renders, no checks.
                        t = CommonMark.Writer(CommonMark.Term(), IOBuffer())
                        t(ast)
                        l = CommonMark.Writer(CommonMark.LaTeX())
                        l(ast)
                    end
                end
            end
        end
    end
end
