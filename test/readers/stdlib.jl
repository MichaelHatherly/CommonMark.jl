# Tests for Julia Markdown stdlib -> CommonMark.jl AST conversion.
# Only runs on Julia 1.9+ where package extensions work.

@testitem "Node from Markdown.MD" tags = [:readers, :stdlib] begin
    using CommonMark
    using Markdown
    using Test

    # Skip on Julia < 1.9 (package extensions not available)
    if VERSION < v"1.9"
        @test true  # placeholder so test passes
    else
        import CommonMark: Node, isnull, html

        @testset "basic blocks" begin
            @testset "heading" begin
                md = Markdown.parse("# Heading 1")
                ast = Node(md)
                @test ast.t isa CommonMark.Document
                @test ast.first_child.t isa CommonMark.Heading
                @test ast.first_child.t.level == 1
            end

            @testset "paragraph with inlines" begin
                md = Markdown.parse("Hello **bold** and *italic*")
                ast = Node(md)
                @test html(ast) ==
                      "<p>Hello <strong>bold</strong> and <em>italic</em></p>\n"
            end

            @testset "code block" begin
                md = Markdown.parse("```julia\nprintln(\"Hello\")\n```")
                ast = Node(md)
                @test occursin("language-julia", html(ast))
                @test occursin("println", html(ast))
            end

            @testset "blockquote" begin
                md = Markdown.parse("> Quoted text")
                ast = Node(md)
                @test occursin("<blockquote>", html(ast))
            end

            @testset "thematic break" begin
                md = Markdown.parse("---")
                ast = Node(md)
                @test occursin("<hr />", html(ast))
            end
        end

        @testset "lists" begin
            @testset "bullet list" begin
                md = Markdown.parse("- item 1\n- item 2")
                ast = Node(md)
                out = html(ast)
                @test occursin("<ul>", out)
                @test count("<li>", out) == 2
            end

            @testset "ordered list" begin
                md = Markdown.parse("1. first\n2. second")
                ast = Node(md)
                out = html(ast)
                @test occursin("<ol>", out)
                @test count("<li>", out) == 2
            end

            @testset "nested list" begin
                md = Markdown.parse("- outer\n  - inner")
                ast = Node(md)
                out = html(ast)
                @test count("<ul>", out) == 2
            end
        end

        @testset "inlines" begin
            @testset "inline code" begin
                md = Markdown.parse("Some `code` here")
                ast = Node(md)
                @test occursin("<code>code</code>", html(ast))
            end

            @testset "link" begin
                md = Markdown.parse("[text](https://example.com)")
                ast = Node(md)
                @test occursin("href=\"https://example.com\"", html(ast))
                @test occursin(">text</a>", html(ast))
            end

            @testset "image" begin
                md = Markdown.parse("![Alt text](image.png)")
                ast = Node(md)
                out = html(ast)
                @test occursin("src=\"image.png\"", out)
                @test occursin("alt=\"Alt text\"", out)
            end

            @testset "line break" begin
                md = Markdown.parse("line1\\\nline2")
                ast = Node(md)
                @test occursin("<br />", html(ast))
            end
        end

        @testset "extensions" begin
            @testset "table" begin
                md = Markdown.parse("""
                | A | B | C |
                |:--|:-:|--:|
                | 1 | 2 | 3 |
                """)
                ast = Node(md)
                out = html(ast)
                @test occursin("<table>", out)
                @test occursin("<thead>", out)
                @test occursin("<tbody>", out)
                @test occursin("align=\"l\"", out)
                @test occursin("align=\"c\"", out)
                @test occursin("align=\"r\"", out)
            end

            @testset "admonition" begin
                md = Markdown.parse("""
                !!! note "Title"
                    Content here
                """)
                ast = Node(md)
                out = html(ast)
                @test occursin("admonition note", out)
                @test occursin("Title", out)
            end

            @testset "math" begin
                md = Markdown.parse("Inline ``x^2`` math")
                ast = Node(md)
                @test occursin("math", html(ast))
                @test occursin("x^2", html(ast))
            end

            @testset "footnotes" begin
                md = Markdown.parse("""
                Text[^1].

                [^1]: Footnote content.
                """)
                ast = Node(md)
                out = html(ast)
                @test occursin("footnote", out)
                @test occursin("footnote-1", out)
            end
        end

        @testset "metadata" begin
            md = Markdown.MD([Markdown.Paragraph(["Hello"])])
            md.meta[:title] = "Test Title"
            md.meta[:author] = "Test Author"
            ast = Node(md)
            @test ast.meta["title"] == "Test Title"
            @test ast.meta["author"] == "Test Author"
        end

        @testset "complex document" begin
            md = Markdown.parse("""
            # Document Title

            Some introductory text with **bold** and *italic*.

            ## Section 1

            - Item one
            - Item two with `code`
            - Item three with [link](https://example.com)

            > A blockquote

            ```julia
            println("Hello")
            ```

            ---

            Final paragraph.
            """)
            ast = Node(md)
            out = html(ast)

            @test occursin("<h1>", out)
            @test occursin("<h2>", out)
            @test occursin("<strong>", out)
            @test occursin("<em>", out)
            @test occursin("<ul>", out)
            @test occursin("<code>", out)
            @test occursin("<blockquote>", out)
            @test occursin("<pre>", out)
            @test occursin("<hr />", out)
        end

        @testset "unknown types" begin
            # Custom Markdown element should warn but not error
            struct CustomElement end
            md = Markdown.MD([CustomElement()])

            ast = @test_logs (:warn, r"Unknown Markdown block type") Node(md)
            @test ast.t isa CommonMark.Document
            @test isnull(ast.first_child)
        end
    end
end
