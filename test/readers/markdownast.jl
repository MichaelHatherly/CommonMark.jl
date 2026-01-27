# Tests for bidirectional CommonMark.jl <-> MarkdownAST.jl AST conversion.

@testitem "CommonMark <-> MarkdownAST conversion" tags = [:readers, :markdownast] begin
    import CommonMark
    import MarkdownAST
    using Test

    @testset "CommonMark -> MarkdownAST" begin
        @testset "basic blocks" begin
            @testset "document and paragraph" begin
                cm = CommonMark.Parser()("Hello world")
                mast = MarkdownAST.Node(cm)
                @test mast.element isa MarkdownAST.Document
                @test first(mast.children).element isa MarkdownAST.Paragraph
            end

            @testset "heading" begin
                cm = CommonMark.Parser()("# Heading 1\n\n## Heading 2")
                mast = MarkdownAST.Node(cm)
                children = collect(mast.children)
                @test children[1].element isa MarkdownAST.Heading
                @test children[1].element.level == 1
                @test children[2].element isa MarkdownAST.Heading
                @test children[2].element.level == 2
            end

            @testset "code block" begin
                cm = CommonMark.Parser()("```julia\nprintln(\"Hello\")\n```")
                mast = MarkdownAST.Node(cm)
                cb = first(mast.children)
                @test cb.element isa MarkdownAST.CodeBlock
                @test cb.element.info == "julia"
                @test occursin("println", cb.element.code)
            end

            @testset "blockquote" begin
                cm = CommonMark.Parser()("> Quoted text")
                mast = MarkdownAST.Node(cm)
                @test first(mast.children).element isa MarkdownAST.BlockQuote
            end

            @testset "thematic break" begin
                cm = CommonMark.Parser()("---")
                mast = MarkdownAST.Node(cm)
                @test first(mast.children).element isa MarkdownAST.ThematicBreak
            end

            @testset "html block" begin
                cm = CommonMark.Parser()("<div>\ntest\n</div>")
                mast = MarkdownAST.Node(cm)
                hb = first(mast.children)
                @test hb.element isa MarkdownAST.HTMLBlock
                @test occursin("<div>", hb.element.html)
            end
        end

        @testset "lists" begin
            @testset "bullet list" begin
                cm = CommonMark.Parser()("- item 1\n- item 2")
                mast = MarkdownAST.Node(cm)
                list = first(mast.children)
                @test list.element isa MarkdownAST.List
                @test list.element.type == :bullet
                @test length(collect(list.children)) == 2
            end

            @testset "ordered list" begin
                cm = CommonMark.Parser()("1. first\n2. second")
                mast = MarkdownAST.Node(cm)
                list = first(mast.children)
                @test list.element isa MarkdownAST.List
                @test list.element.type == :ordered
            end

            @testset "tight vs loose" begin
                tight = CommonMark.Parser()("- a\n- b")
                tight_mast = MarkdownAST.Node(tight)
                @test first(tight_mast.children).element.tight == true

                loose = CommonMark.Parser()("- a\n\n- b")
                loose_mast = MarkdownAST.Node(loose)
                @test first(loose_mast.children).element.tight == false
            end
        end

        @testset "inlines" begin
            @testset "text" begin
                cm = CommonMark.Parser()("Hello world")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                text = first(para.children)
                @test text.element isa MarkdownAST.Text
                @test text.element.text == "Hello world"
            end

            @testset "emphasis and strong" begin
                cm = CommonMark.Parser()("*em* and **strong**")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                children = collect(para.children)
                @test any(n -> n.element isa MarkdownAST.Emph, children)
                @test any(n -> n.element isa MarkdownAST.Strong, children)
            end

            @testset "inline code" begin
                cm = CommonMark.Parser()("Some `code` here")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                code = filter(n -> n.element isa MarkdownAST.Code, collect(para.children))
                @test length(code) == 1
                @test first(code).element.code == "code"
            end

            @testset "link" begin
                cm = CommonMark.Parser()("[text](https://example.com)")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                link = first(para.children)
                @test link.element isa MarkdownAST.Link
                @test link.element.destination == "https://example.com"
            end

            @testset "image" begin
                cm = CommonMark.Parser()("![Alt](image.png)")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                img = first(para.children)
                @test img.element isa MarkdownAST.Image
                @test img.element.destination == "image.png"
            end

            @testset "soft and hard breaks" begin
                cm = CommonMark.Parser()("line1\nline2")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                @test any(n -> n.element isa MarkdownAST.SoftBreak, para.children)

                cm2 = CommonMark.Parser()("line1  \nline2")
                mast2 = MarkdownAST.Node(cm2)
                para2 = first(mast2.children)
                @test any(n -> n.element isa MarkdownAST.LineBreak, para2.children)
            end

            @testset "html inline" begin
                cm = CommonMark.Parser()("text <span>html</span> more")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                @test any(n -> n.element isa MarkdownAST.HTMLInline, para.children)
            end
        end

        @testset "extensions" begin
            @testset "table" begin
                p = CommonMark.enable!(CommonMark.Parser(), CommonMark.TableRule())
                cm = p("""
                | A | B |
                |:--|--:|
                | 1 | 2 |
                """)
                mast = MarkdownAST.Node(cm)
                table = first(mast.children)
                @test table.element isa MarkdownAST.Table
                @test table.element.spec == [:left, :right]
            end

            @testset "admonition" begin
                p = CommonMark.enable!(CommonMark.Parser(), CommonMark.AdmonitionRule())
                cm = p("""
                !!! note "Title"
                    Content
                """)
                mast = MarkdownAST.Node(cm)
                adm = first(mast.children)
                @test adm.element isa MarkdownAST.Admonition
                @test adm.element.category == "note"
                @test adm.element.title == "Title"
            end

            @testset "math" begin
                p = CommonMark.enable!(CommonMark.Parser(), CommonMark.MathRule())
                cm = p("Inline ``x^2`` math")
                mast = MarkdownAST.Node(cm)
                para = first(mast.children)
                math = filter(
                    n -> n.element isa MarkdownAST.InlineMath,
                    collect(para.children),
                )
                @test length(math) == 1
                @test first(math).element.math == "x^2"
            end

            @testset "display math" begin
                p = CommonMark.enable!(CommonMark.Parser(), CommonMark.MathRule())
                cm = p("```math\nx^2\n```")
                mast = MarkdownAST.Node(cm)
                dm = first(mast.children)
                @test dm.element isa MarkdownAST.DisplayMath
            end

            @testset "footnotes" begin
                p = CommonMark.enable!(CommonMark.Parser(), CommonMark.FootnoteRule())
                cm = p("""
                Text[^1].

                [^1]: Footnote content.
                """)
                mast = MarkdownAST.Node(cm)
                children = collect(mast.children)
                @test any(n -> n.element isa MarkdownAST.FootnoteDefinition, children)
                para = filter(n -> n.element isa MarkdownAST.Paragraph, children)
                @test any(n -> n.element isa MarkdownAST.FootnoteLink, first(para).children)
            end
        end

        @testset "unsupported types warn" begin
            p = CommonMark.enable!(CommonMark.Parser(), CommonMark.StrikethroughRule())
            cm = p("~~strikethrough~~")
            mast = @test_logs (:warn, r"Unsupported CommonMark type") MarkdownAST.Node(cm)
            @test mast.element isa MarkdownAST.Document
        end
    end

    @testset "MarkdownAST -> CommonMark" begin
        @testset "basic blocks" begin
            @testset "document and paragraph" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        "Hello world"
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.t isa CommonMark.Document
                @test cm.first_child.t isa CommonMark.Paragraph
                @test occursin("Hello world", CommonMark.html(cm))
            end

            @testset "heading" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Heading(2) do
                        "Title"
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.Heading
                @test cm.first_child.t.level == 2
            end

            @testset "code block" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.CodeBlock("julia", "println()")
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.CodeBlock
                @test cm.first_child.t.info == "julia"
                @test occursin("println", cm.first_child.literal)
            end

            @testset "blockquote" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.BlockQuote() do
                        MarkdownAST.Paragraph() do
                            "Quoted"
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.BlockQuote
            end

            @testset "thematic break" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.ThematicBreak()
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.ThematicBreak
            end
        end

        @testset "lists" begin
            @testset "bullet list" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.List(:bullet, true) do
                        MarkdownAST.Item() do
                            MarkdownAST.Paragraph() do
                                "item 1"
                            end
                        end
                        MarkdownAST.Item() do
                            MarkdownAST.Paragraph() do
                                "item 2"
                            end
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.List
                @test cm.first_child.t.list_data.type == :bullet
            end

            @testset "ordered list" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.List(:ordered, true) do
                        MarkdownAST.Item() do
                            MarkdownAST.Paragraph() do
                                "first"
                            end
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t.list_data.type == :ordered
            end
        end

        @testset "inlines" begin
            @testset "emphasis and strong" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        MarkdownAST.Emph() do
                            "em"
                        end
                        " and "
                        MarkdownAST.Strong() do
                            "strong"
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                html = CommonMark.html(cm)
                @test occursin("<em>em</em>", html)
                @test occursin("<strong>strong</strong>", html)
            end

            @testset "inline code" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        MarkdownAST.Code("code")
                    end
                end
                cm = CommonMark.Node(mast)
                @test occursin("<code>code</code>", CommonMark.html(cm))
            end

            @testset "link" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        MarkdownAST.Link("https://example.com", "") do
                            "text"
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                html = CommonMark.html(cm)
                @test occursin("href=\"https://example.com\"", html)
                @test occursin(">text</a>", html)
            end

            @testset "image" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        MarkdownAST.Image("img.png", "title") do
                            "alt"
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                html = CommonMark.html(cm)
                @test occursin("src=\"img.png\"", html)
            end
        end

        @testset "extensions" begin
            @testset "table" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Table([:left, :right]) do
                        MarkdownAST.TableHeader() do
                            MarkdownAST.TableRow() do
                                MarkdownAST.TableCell(:left, true, 1) do
                                    "A"
                                end
                                MarkdownAST.TableCell(:right, true, 2) do
                                    "B"
                                end
                            end
                        end
                        MarkdownAST.TableBody() do
                            MarkdownAST.TableRow() do
                                MarkdownAST.TableCell(:left, false, 1) do
                                    "1"
                                end
                                MarkdownAST.TableCell(:right, false, 2) do
                                    "2"
                                end
                            end
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                html = CommonMark.html(cm)
                @test occursin("<table>", html)
                @test occursin("<thead>", html)
                @test occursin("<tbody>", html)
            end

            @testset "admonition" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Admonition("note", "Title") do
                        MarkdownAST.Paragraph() do
                            "Content"
                        end
                    end
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.Admonition
                @test cm.first_child.t.category == "note"
            end

            @testset "math" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.Paragraph() do
                        MarkdownAST.InlineMath("x^2")
                    end
                end
                cm = CommonMark.Node(mast)
                para = cm.first_child
                @test para.first_child.t isa CommonMark.Math
                @test para.first_child.literal == "x^2"
            end

            @testset "display math" begin
                mast = MarkdownAST.@ast MarkdownAST.Document() do
                    MarkdownAST.DisplayMath("x^2")
                end
                cm = CommonMark.Node(mast)
                @test cm.first_child.t isa CommonMark.DisplayMath
                @test cm.first_child.literal == "x^2"
            end
        end
    end

    @testset "round-trip" begin
        @testset "CM -> MAST -> CM" begin
            original =
                CommonMark.Parser()("# Hello\n\nA paragraph with **bold** and *italic*.\n")
            mast = MarkdownAST.Node(original)
            roundtrip = CommonMark.Node(mast)

            # Compare HTML output
            @test CommonMark.html(original) == CommonMark.html(roundtrip)
        end

        @testset "complex document round-trip" begin
            p = CommonMark.enable!(CommonMark.Parser(), CommonMark.TableRule())
            original = p("""
            # Title

            Some text with **bold**.

            - item 1
            - item 2

            | A | B |
            |---|---|
            | 1 | 2 |

            > Quote

            ```julia
            code()
            ```
            """)
            mast = MarkdownAST.Node(original)
            roundtrip = CommonMark.Node(mast)

            @test CommonMark.html(original) == CommonMark.html(roundtrip)
        end
    end
end
