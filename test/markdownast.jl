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

const MARKDOWNAST_DEFAULT_RULES = [
    CommonMark.AdmonitionRule(),
    CommonMark.FootnoteRule(),
    CommonMark.TableRule(),
]

function convert_to_markdownast(
    markdown::AbstractString;
    rules = MARKDOWNAST_DEFAULT_RULES,
)
    p = Parser()
    for rule in rules
        enable!(p, rule)
    end
    cmnodes = p(markdown)
    mdast = convert(MarkdownAST.Node, cmnodes)
    @test isa(mdast, MarkdownAST.Node)
    show(stdout, mdast)
    return mdast
end

function convert_to_markdownast_and_compare(
    markdown::AbstractString,
    reference::MarkdownAST.Node;
    rules = MARKDOWNAST_DEFAULT_RULES,
)
    mdast = convert_to_markdownast(markdown; rules)
    @test mdast == reference
    return
end

@testset "MarkdownAST conversions" begin
    # Testset for CommonMark.Admonition
    @testset "CommonMark.Admonition" begin
        convert_to_markdownast_and_compare(
            """
            !!! note "Note"
                This is a note.
            !!! warning
                This is a warning.
            !!! foobar
                This is a foobar.
            !!! info "Nested"
                !!! note
                    This is a nested note.
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Admonition("note", "Note") do
                    MarkdownAST.Paragraph() do
                        "This is a note."
                    end
                end
                MarkdownAST.Admonition("warning", "Warning") do
                    MarkdownAST.Paragraph() do
                        "This is a warning."
                    end
                end
                MarkdownAST.Admonition("foobar", "Foobar") do
                    MarkdownAST.Paragraph() do
                        "This is a foobar."
                    end
                end
                MarkdownAST.Admonition("info", "Nested") do
                    MarkdownAST.Admonition("note", "Note") do
                        MarkdownAST.Paragraph() do
                            "This is a nested note."
                        end
                    end
                end
            end
        )
    end

    @testset "CommonMark.BlockQuote" begin
        convert_to_markdownast_and_compare(
            """
            > Blockquote
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.BlockQuote() do
                    MarkdownAST.Paragraph() do
                        "Blockquote"
                    end
                end
            end
        )
    end

    # CommonMark.CodeBlock


    @testset "CommonMark.List" begin
        convert_to_markdownast_and_compare(
            """
            - Item 1
            - Item 2

            1. Foo
            2. Bar
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.List(:bullet, true) do
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Item 1"
                        end
                    end
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Item 2"
                        end
                    end
                end
                MarkdownAST.List(:ordered, true) do
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Foo"
                        end
                    end
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Bar"
                        end
                    end
                end
            end
        )
        convert_to_markdownast_and_compare(
            """
            - Foo

              Bar
            - Baz
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.List(:bullet, false) do
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Foo"
                        end
                        MarkdownAST.Paragraph() do
                            "Bar"
                        end
                    end
                    MarkdownAST.Item() do
                        MarkdownAST.Paragraph() do
                            "Baz"
                        end
                    end
                end
            end
        )
    end

    @testset "CommonMark.ThematicBreak" begin
        convert_to_markdownast_and_compare(
            """
            foo

            ---

            bar
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    "foo"
                end
                MarkdownAST.ThematicBreak()
                MarkdownAST.Paragraph() do
                    "bar"
                end
            end
        )
    end


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

    # Inline containers

    # CommonMark.Backslash

    @testset "CommonMark.Code" begin
        convert_to_markdownast_and_compare(
            "This is `inline code`",
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    MarkdownAST.Text("This is ")
                    MarkdownAST.Code("inline code")
                end
            end
        )
    end

    @testset "CommonMark.Emph" begin
        convert_to_markdownast_and_compare(
            "This is *emphasized*",
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    MarkdownAST.Text("This is ")
                    MarkdownAST.Emph() do
                        MarkdownAST.Text("emphasized")
                    end
                end
            end
        )
    end

    # CommonMark.FootnoteLink
    # CommonMark.HtmlInline

    @testset "CommonMark.Image" begin
        convert_to_markdownast_and_compare(
            """
            ![Alt text](image.jpg)
            """,
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    MarkdownAST.Image("image.jpg", "") do
                        "Alt text"
                    end
                end
            end
        )
    end

    # CommonMark.JuliaExpression
    # CommonMark.JuliaValue
    # CommonMark.LaTeXInline
    # CommonMark.LineBreak

    @testset "CommonMark.Link" begin
        convert_to_markdownast_and_compare(
            "[Link](https://example.com)",
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    MarkdownAST.Link("https://example.com", "") do
                        MarkdownAST.Text("Link")
                    end
                end
            end
        )
    end

    # CommonMark.Math
    # CommonMark.SoftBreak
    # CommonMark.Strong

    @testset "CommonMark.Strong" begin
        convert_to_markdownast_and_compare(
            "This is **strong**",
            MarkdownAST.@ast MarkdownAST.Document() do
                MarkdownAST.Paragraph() do
                    MarkdownAST.Text("This is ")
                    MarkdownAST.Strong() do
                        MarkdownAST.Text("strong")
                    end
                end
            end
        )
    end

    # CommonMark.TablePipe
    # CommonMark.Text
    # CommonMark.TypstInline
end

@testset "MarkdownAST conversions: unsupported" begin
    # The CommonMark nodes are currently unsupported by the MarkdownAST conversion
    # since MarkdownAST does not have a corresponding representation.
    # These should be just the nodes that are not necessary to represent neither
    # CommonMark nor the Julia Flavored Markdown.
    @testset "CommonMark.Attributes" begin
        @test_throws CommonMark.UnsupportedContainerError(CommonMark.Attributes) convert_to_markdownast(
            """
            # Heading {.class #id}
            """;
            rules = [CommonMark.AttributeRule()]
        )
    end

    @testset "CommonMark.{Citation,CitationBracket}" begin
        @test_throws CommonMark.UnsupportedContainerError(CommonMark.Citation) convert_to_markdownast(
            """
            @foo
            """;
            rules = [CommonMark.CitationRule()]
        )
        @test_throws CommonMark.UnsupportedContainerError(CommonMark.CitationBracket) convert_to_markdownast(
            """
            [@foo, @bar]
            """;
            rules = [CommonMark.CitationRule()]
        )
    end
end
