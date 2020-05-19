using CommonMark, Test, JSON

@testset "CommonMark" begin
    # Do we pass the CommonMark spec -- version 0.29.0.
    @testset "Spec" begin
        for case in JSON.Parser.parsefile(joinpath(@__DIR__, "spec.json"))
            p = CommonMark.Parser()
            h = CommonMark.Renderer(CommonMark.HTML())
            ast = CommonMark.parse(p, case["markdown"])
            html = read(CommonMark.render(h, ast), String)
            @test case["html"] == html
            # The following just make sure we don't throw on the other
            # rendering. Proper tests are found below.
            t = CommonMark.Renderer(CommonMark.Term(), IOBuffer())
            CommonMark.render(t, ast)
            l = CommonMark.Renderer(CommonMark.LaTeX())
            CommonMark.render(l, ast)
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
                    html = read(splitext(name)[1] * ".html", String)

                    p = CommonMark.Parser()
                    h = CommonMark.Renderer(CommonMark.HTML())
                    ast = CommonMark.parse(p, read(name, String))
                    out = read(CommonMark.render(h, ast), String)

                    @testset "$file" begin
                        @test out == html

                        # TODO: just renders, no checks.
                        t = CommonMark.Renderer(CommonMark.Term(), IOBuffer())
                        CommonMark.render(t, ast)
                        l = CommonMark.Renderer(CommonMark.LaTeX())
                        CommonMark.render(l, ast)
                    end
                end
            end
        end
    end
end
