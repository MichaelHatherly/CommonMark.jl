@testset "Sourcepos" begin
    macro_ast_multiline = @__LINE__() + 2,
    cm"""
    # Header

    > quote
    """
    out = html(macro_ast_multiline[2]; sourcepos = true)
    @test occursin("data-sourcepos=\"$(macro_ast_multiline[1])", out)

    macro_ast_singleline = @__LINE__(), cm"Some *text*"
    out = html(macro_ast_singleline[2]; sourcepos = true)
    @test occursin("data-sourcepos=\"$(macro_ast_singleline[1])", out)

    function sourcepos(file)
        function (pos)
            "data-custom-sourcepos" => string(file, ":", pos[1][1])
        end
    end

    out = html(macro_ast_multiline[2]; sourcepos = sourcepos(@__FILE__))
    @test occursin(
        "data-custom-sourcepos=\"$(@__FILE__()):$(macro_ast_multiline[1])\"",
        out,
    )

    out = html(macro_ast_singleline[2]; sourcepos = sourcepos(@__FILE__))
    @test occursin(
        "data-custom-sourcepos=\"$(@__FILE__()):$(macro_ast_singleline[1])\"",
        out,
    )

    filepath = joinpath(@__DIR__, "integration.md")
    file_ast = open(Parser(), filepath)

    out = html(file_ast; sourcepos = true)
    @test occursin("data-sourcepos=\"1", out)

    out = html(file_ast; sourcepos = sourcepos(filepath))
    @test occursin("data-custom-sourcepos=\"$(filepath):1\"", out)
end
