# Tests for Julia stdlib Markdown compatibility.
# Each test references a JuliaLang/julia issue that CommonMark.jl handles correctly.

@testitem "stdlib_compat" tags = [:stdlib_compat] setup = [Utilities] begin
    using CommonMark
    using Test

    @testset "parsing" begin
        p = Parser()

        @testset "#59967 indented code blocks with multiple blank lines" begin
            md = """
            - item

              ```julia
              line1


              line2
              ```
            """
            ast = p(md)
            @test occursin("line1\n\n\nline2", html(ast))
        end

        @testset "#58514 multi-paragraph nested list items" begin
            md = """
            * Outer

                * Inner paragraph 1

                  Inner paragraph 2
            """
            ast = p(md)
            out = html(ast)
            # Second paragraph should be inside the inner list item
            @test occursin(
                "<li>\n<p>Inner paragraph 1</p>\n<p>Inner paragraph 2</p>\n</li>",
                out,
            )
        end

        @testset "#30198 line continuation in lists" begin
            md = "- Long text\nwrapped line"
            ast = p(md)
            out = html(ast)
            @test occursin("<li>", out)
            @test occursin("wrapped line</li>", out)
            @test !occursin("<p>wrapped", out)  # not a separate paragraph
        end

        @testset "#22076 list marker and whitespace handling" begin
            # Different markers should create separate lists
            md1 = "* foo\n+ bar"
            ast1 = p(md1)
            out1 = html(ast1)
            @test count("<ul>", out1) == 2

            # Trailing spaces on blank line shouldn't break list
            md2 = "* item1\n  \n* item2"
            ast2 = p(md2)
            out2 = html(ast2)
            @test count("<ul>", out2) == 1
            @test count("<li>", out2) == 2
        end

        @testset "#29344 CRLF line endings" begin
            md_lf = "* a\n\n  * b\n"
            md_crlf = "* a\r\n\r\n  * b\r\n"
            @test html(p(md_lf)) == html(p(md_crlf))
        end

        @testset "#19844 link reference definitions" begin
            md = "[link] and [inline](http://example.com)\n\n[link]: http://example.com"
            ast = p(md)
            out = html(ast)
            @test count("href=\"http://example.com\"", out) == 2
        end

        @testset "#17837 raw HTML and comments" begin
            md = "<!-- comment -->"
            ast = p(md)
            @test html(ast) == "<!-- comment -->\n"
        end

        @testset "#16004 trailing spaces and list after paragraph" begin
            # Two trailing spaces create line break
            md1 = "line1  \nline2"
            @test occursin("<br />", html(p(md1)))

            # List after paragraph
            md2 = "text\n* item"
            out2 = html(p(md2))
            @test occursin("<p>text</p>", out2)
            @test occursin("<li>item</li>", out2)
        end

        @testset "#39913 escape characters" begin
            @test occursin("&lt;", html(p("\\<")))
            @test occursin("&gt;", html(p("\\>")))
            @test occursin("|", html(p("\\|")))
        end

        @testset "#38189 table with empty first cell" begin
            pt = enable!(Parser(), TableRule())
            md = "|   | 1 | 2 |\n|:-:|:--|--:|\n| 3 | 4 | 5 |"
            out = html(pt(md))
            @test occursin("<table>", out)
            @test occursin("<th align=\"center\"></th>", out)
        end

        @testset "#16003 nested lists structure" begin
            md = "* A\n  * B\n  * C\n* D"
            ast = p(md)
            out = html(ast)
            # Should have nested structure, not flat
            @test occursin("<ul>\n<li>A\n<ul>", out)
        end

        @testset "#52697 list with LaTeX formula" begin
            pm = enable!(Parser(), DollarMathRule())
            md = "+ \$\\frac{1}{2}\$, \$\\frac{2}{3}\$"
            out = html(pm(md))
            # Should be single list item, not split
            @test count("<li>", out) == 1
        end
    end

    @testset "interpolation" begin
        @testset "#43001 underscore and asterisk in interpolation" begin
            x_ = "value"
            ast1 = cm"test_$(x_)"
            @test occursin("value", html(ast1))

            x, y = 2, 3
            ast2 = cm"result*$(x*y)"
            @test occursin("6", html(ast2))
        end

        @testset "#36946 parentheses don't trigger LaTeX" begin
            ast = cm"$(1) ($(2))"
            out = html(ast)
            @test occursin("1", out)
            @test occursin("2", out)
            @test !occursin("\\(", out)  # no LaTeX
        end

        @testset "#55943 parenthesized interpolation" begin
            x, y = 1, 2
            ast = cm"x = $x, y = ($y)"
            out = html(ast)
            @test occursin(">1<", out)
            @test occursin(">2<", out)
        end

        @testset "#38229 no newline after leading interpolation" begin
            var = 10.0
            ast = cm"$(var) text here"
            out = html(ast)
            # Should be single paragraph
            @test count("<p>", out) == 1
        end

        @testset "#53362 interpolation in admonitions" begin
            v = "Hello"
            ast = cm"""
            !!! note
                $v world
            """
            out = html(ast)
            @test occursin("Hello", out)
            @test occursin("admonition", out)
        end

        @testset "#37336 bold with interpolation" begin
            planet = "Earth"
            ast = cm"$planet **$planet**"
            out = html(ast)
            @test occursin("<strong>", out)
            @test count("Earth", out) == 2
        end

        @testset "#25992 complex expressions" begin
            x = [1, 2, 3]
            ast = cm"sum = $(sum(x)), len = $(length(x))"
            out = html(ast)
            @test occursin("6", out)
            @test occursin("3", out)
        end
    end

    @testset "extensions" begin
        @testset "#34898 strikethrough" begin
            ps = enable!(Parser(), StrikethroughRule())
            @test html(ps("~~deleted~~")) == "<p><del>deleted</del></p>\n"
        end

        @testset "#37334 multiline dollar math" begin
            pm = enable!(Parser(), DollarMathRule())
            md = "\$\$\nx = 5\n\$\$"
            out = html(pm(md))
            @test occursin("display-math", out)
            @test occursin("x = 5", out)
        end

        @testset "#37335 admonition with tabs" begin
            pa = enable!(Parser(), AdmonitionRule())
            md = "!!! note\n\tContent here"
            out = html(pa(md))
            @test occursin("admonition", out)
            @test occursin("Content here", out)
        end

        @testset "#33625 admonition with capitals" begin
            pa = enable!(Parser(), AdmonitionRule())
            @test occursin("admonition Note", html(pa("!!! Note\n    x")))
            @test occursin("admonition NOTE", html(pa("!!! NOTE\n    x")))
            @test occursin("admonition WeIrD", html(pa("!!! WeIrD\n    x")))
        end

        @testset "#51577 GitHub alerts" begin
            pg = enable!(Parser(), GitHubAlertRule())
            md = "> [!NOTE]\n> This is a note"
            out = html(pg(md))
            @test occursin("github-alert", out)
            @test occursin("note", out)
        end
    end

    @testset "display" begin
        p = Parser()

        @testset "#18615 nested list bullets" begin
            md = "* A\n  * B"
            out = term(p(md))
            @test occursin("●", out)
            @test occursin("○", out)
        end

        @testset "#19914 code block visual indicator" begin
            md = "```\ncode\n```"
            out = term(p(md))
            @test occursin("│", out)
        end
    end

    @testset "api" begin
        p = Parser()

        @testset "#35917 markdown roundtrip" begin
            md = "# Heading\n\n**bold** text\n"
            ast = p(md)
            @test html(p(markdown(ast))) == html(ast)
        end

        @testset "#33438 link node consistency" begin
            ast1 = p("[text](url)")
            ast2 = p("[text][ref]\n\n[ref]: url")

            # Both should have Link nodes with Text children
            function get_link_structure(ast)
                for (node, entering) in ast
                    if entering && node.t isa CommonMark.Link
                        child = node.first_child
                        return (
                            typeof(node.t),
                            child !== nothing ? typeof(child.t) : nothing,
                        )
                    end
                end
                return nothing
            end

            @test get_link_structure(ast1) == get_link_structure(ast2)
        end

        @testset "#25015 document iteration" begin
            ast = p("# H\n\nPara")
            types = [typeof(node.t) for (node, entering) in ast if entering]
            @test CommonMark.Document in types
            @test CommonMark.Heading in types
            @test CommonMark.Paragraph in types
        end

        @testset "#46619 HTML tags preserved" begin
            md = "<details>\n<summary>Title</summary>\n\nContent\n\n</details>"
            out = html(p(md))
            @test occursin("<details>", out)
            @test occursin("<summary>", out)
            @test occursin("</details>", out)
        end
    end
end
