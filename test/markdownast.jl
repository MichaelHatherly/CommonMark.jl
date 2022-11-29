import MarkdownAST

@testset "MarkdownAST conversion" begin
    cmnodes = cm"""
    # Heading

    hello *world*

    ```julia
    foo
    ```

    [foo **bar** baz](url "asdsd")

    ![foo **bar** baz](url "asdsd") ![foo **bar** baz](url "asdsd")

    !!! info "Info"

        > asdasd

    ## Footnotes

    Reference[^1].

    [^1]: foonote

    ## Table

    | 1 | 10 | 100 |
    | - | --:|:---:|
    | x | y  | z   |

    ## Interpolation

    $(1+2+3)
    """
    @test convert(MarkdownAST.Node, cmnodes) isa MarkdownAST.Node

    SAMPLES_DIR = joinpath(@__DIR__, "samples", "cmark")
    mdsamples = [
        joinpath(SAMPLES_DIR, filename)
        for filename in filter(endswith(".md"), readdir(SAMPLES_DIR))
    ]
    p = Parser()
    enable!(p, CommonMark.AdmonitionRule())
    enable!(p, CommonMark.FootnoteRule())
    enable!(p, CommonMark.TableRule())
    for samplefile in mdsamples
        cmnodes = p(read(samplefile, String))
        @test convert(MarkdownAST.Node, cmnodes) isa MarkdownAST.Node
    end
end
