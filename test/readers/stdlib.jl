# Tests for Julia Markdown stdlib -> CommonMark.jl AST conversion.

@testitem "Node from Markdown.MD" tags = [:readers, :stdlib] begin
    import CommonMark
    import Markdown
    using Test

    @testset "basic blocks" begin
        @testset "heading" begin
            md = Markdown.parse("# Heading 1")
            ast = CommonMark.Node(md)
            @test ast.t isa CommonMark.Document
            @test ast.first_child.t isa CommonMark.Heading
            @test ast.first_child.t.level == 1
        end

        @testset "paragraph with inlines" begin
            md = Markdown.parse("Hello **bold** and *italic*")
            ast = CommonMark.Node(md)
            @test CommonMark.html(ast) ==
                  "<p>Hello <strong>bold</strong> and <em>italic</em></p>\n"
        end

        @testset "code block" begin
            md = Markdown.parse("```julia\nprintln(\"Hello\")\n```")
            ast = CommonMark.Node(md)
            @test occursin("language-julia", CommonMark.html(ast))
            @test occursin("println", CommonMark.html(ast))
        end

        @testset "code block with backticks" begin
            # Code containing ``` needs fence_length > 3 for valid markdown output
            md = Markdown.MD([Markdown.Code("md", "```\ninner\n```")])
            ast = CommonMark.Node(md)
            @test ast.first_child.t.fence_length == 4
            # Markdown output should use 4 backticks
            mdout = CommonMark.markdown(ast)
            @test startswith(mdout, "````")
        end

        @testset "blockquote" begin
            md = Markdown.parse("> Quoted text")
            ast = CommonMark.Node(md)
            @test occursin("<blockquote>", CommonMark.html(ast))
        end

        @testset "thematic break" begin
            md = Markdown.parse("---")
            ast = CommonMark.Node(md)
            @test occursin("<hr />", CommonMark.html(ast))
        end
    end

    @testset "lists" begin
        @testset "bullet list" begin
            md = Markdown.parse("- item 1\n- item 2")
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test occursin("<ul>", out)
            @test count("<li>", out) == 2
        end

        @testset "ordered list" begin
            md = Markdown.parse("1. first\n2. second")
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test occursin("<ol>", out)
            @test count("<li>", out) == 2
        end

        @testset "nested list" begin
            md = Markdown.parse("- outer\n  - inner")
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test count("<ul>", out) == 2
        end
    end

    @testset "inlines" begin
        @testset "inline code" begin
            md = Markdown.parse("Some `code` here")
            ast = CommonMark.Node(md)
            @test occursin("<code>code</code>", CommonMark.html(ast))
        end

        @testset "link" begin
            md = Markdown.parse("[text](https://example.com)")
            ast = CommonMark.Node(md)
            @test occursin("href=\"https://example.com\"", CommonMark.html(ast))
            @test occursin(">text</a>", CommonMark.html(ast))
        end

        @testset "image" begin
            md = Markdown.parse("![Alt text](image.png)")
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test occursin("src=\"image.png\"", out)
            @test occursin("alt=\"Alt text\"", out)
        end

        @testset "line break" begin
            md = Markdown.parse("line1\\\nline2")
            ast = CommonMark.Node(md)
            @test occursin("<br />", CommonMark.html(ast))
        end
    end

    @testset "extensions" begin
        @testset "table" begin
            md = Markdown.parse("""
            | A | B | C |
            |:--|:-:|--:|
            | 1 | 2 | 3 |
            """)
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
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
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test occursin("admonition note", out)
            @test occursin("Title", out)
        end

        @testset "math" begin
            md = Markdown.parse("Inline ``x^2`` math")
            ast = CommonMark.Node(md)
            @test occursin("math", CommonMark.html(ast))
            @test occursin("x^2", CommonMark.html(ast))
        end

        @testset "footnotes" begin
            md = Markdown.parse("""
            Text[^1].

            [^1]: Footnote content.
            """)
            ast = CommonMark.Node(md)
            out = CommonMark.html(ast)
            @test occursin("footnote", out)
            @test occursin("footnote-1", out)
        end
    end

    @testset "metadata" begin
        md = Markdown.MD([Markdown.Paragraph(["Hello"])])
        md.meta[:title] = "Test Title"
        md.meta[:author] = "Test Author"
        ast = CommonMark.Node(md)
        @test ast.meta["title"] == "Test Title"
        @test ast.meta["author"] == "Test Author"
    end

    @testset "nested MD" begin
        # Nested MD with multiple blocks
        inner = Markdown.MD([
            Markdown.Paragraph(["Inner para 1"]),
            Markdown.Paragraph(["Inner para 2"]),
        ])
        inner.meta[:inner_key] = "inner_value"
        inner.meta[:shared] = "inner_shared"

        outer = Markdown.MD([Markdown.Paragraph(["Outer para"]), inner])
        outer.meta[:outer_key] = "outer_value"
        outer.meta[:shared] = "outer_shared"

        ast = CommonMark.Node(outer)
        out = CommonMark.html(ast)

        # All paragraphs should be flattened
        @test occursin("Outer para", out)
        @test occursin("Inner para 1", out)
        @test occursin("Inner para 2", out)

        # Metadata merged, outer takes precedence for :shared
        @test ast.meta["outer_key"] == "outer_value"
        @test ast.meta["inner_key"] == "inner_value"
        @test ast.meta["shared"] == "outer_shared"
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
        ast = CommonMark.Node(md)
        out = CommonMark.html(ast)

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

        ast = @test_logs (:warn, r"Unknown Markdown block type") CommonMark.Node(md)
        @test ast.t isa CommonMark.Document
        @test CommonMark.isnull(ast.first_child)
    end
end
