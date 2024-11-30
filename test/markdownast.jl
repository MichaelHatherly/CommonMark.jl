import MarkdownAST

@testset "MarkdownAST conversion: smoke test" begin
    # Basic test set that just runs the MarkdownAST conversion on a set of realistic
    # CommonMark trees that have been parsed from sample strings / Markdown files.
    # However, it does not test the "correctness" of the conversion, and just checks
    # that the conversion does not error.
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
        joinpath(SAMPLES_DIR, filename) for
        filename in filter(s -> endswith(s, ".md"), readdir(SAMPLES_DIR))
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

function convert_to_markdownast_and_compare(
    markdown::AbstractString,
    reference::MarkdownAST.Node,
)
    p = Parser()
    enable!(p, CommonMark.AdmonitionRule())
    enable!(p, CommonMark.FootnoteRule())
    enable!(p, CommonMark.TableRule())
    cmnodes = p(markdown)
    mdast = convert(MarkdownAST.Node, cmnodes)
    @test isa(mdast, MarkdownAST.Node)
    show(stdout, mdast)
    @test mdast == reference
    return
end

@testset "MarkdownAST conversions" begin
    # Testset for CommonMark.Admonition

    # CommonMark.Attributes
    # CommonMark.BlockQuote
    # CommonMark.Citation
    # CommonMark.CitationBracket
    # CommonMark.CodeBlock
    # CommonMark.DisplayMath
    # CommonMark.Document
    # CommonMark.FootnoteDefinition
    # CommonMark.FrontMatter
    @testset "CommonMark.Heading" begin
        convert_to_markdownast_and_compare(
            """
            Heading
            =======
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Heading(1) do
                    MarkdownAST.Text("Heading")
                end
            end
        )
        convert_to_markdownast_and_compare(
            """
            # Heading A
            ## Heading B
            ### Heading C
            #### Heading D
            ##### Heading E
            ###### Heading F
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Heading(1) do
                    MarkdownAST.Text("Heading A")
                end
                MarkdownAST.Heading(2) do
                    MarkdownAST.Text("Heading B")
                end
                MarkdownAST.Heading(3) do
                    MarkdownAST.Text("Heading C")
                end
                MarkdownAST.Heading(4) do
                    MarkdownAST.Text("Heading D")
                end
                MarkdownAST.Heading(5) do
                    MarkdownAST.Text("Heading E")
                end
                MarkdownAST.Heading(6) do
                    MarkdownAST.Text("Heading F")
                end
            end
        )
    end

    # CommonMark.HtmlBlock
    # CommonMark.Item
    # CommonMark.LaTeXBlock
    # CommonMark.List
    # CommonMark.Paragraph
    # CommonMark.ReferenceList
    # CommonMark.References
    # CommonMark.TableComponent
    # CommonMark.ThematicBreak
    # CommonMark.TypstBlock

    # CommonMark.Backslash
    # CommonMark.Code
    # CommonMark.Emph
    # CommonMark.FootnoteLink
    # CommonMark.HtmlInline
    # CommonMark.Image
    # CommonMark.JuliaExpression
    # CommonMark.JuliaValue
    # CommonMark.LaTeXInline
    # CommonMark.LineBreak
    # CommonMark.Link
    # CommonMark.Math
    # CommonMark.SoftBreak
    # CommonMark.Strong
    # CommonMark.TablePipe
    # CommonMark.Text
    # CommonMark.TypstInline
end
