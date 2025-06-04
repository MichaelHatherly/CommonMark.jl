@testitem "sample_files" tags = [:core] begin
    using CommonMark
    using Test

    for (root, dirs, files) in walkdir(joinpath(@__DIR__, "samples"))
        for file in files
            if endswith(file, ".md")
                name = joinpath(root, file)
                expected =
                    replace(read(splitext(name)[1] * ".html", String), "\r\n" => "\n")

                p = Parser()
                ast = p(read(name, String))

                @testset "$file" begin
                    @test html(ast) == expected
                    # TODO: just renders, no checks.
                    latex(ast)
                    term(ast)
                end
            end
        end
    end
end
