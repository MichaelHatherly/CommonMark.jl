@testitem "shortcodes" tags = [:extensions, :shortcodes] setup = [Utilities] begin
    using CommonMark
    using Test

    # --- Parsing ---

    @testset "inline passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("Text {{< name arg >}} more.")
        @test html(ast) == "<p>Text {{< name arg >}} more.</p>\n"
    end

    @testset "block promotion" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< pagebreak >}}")
        @test ast.first_child.t isa CommonMark.ShortcodeBlock
        @test ast.first_child.t.name == "pagebreak"
        @test ast.first_child.t.args == String[]
        @test ast.first_child.t.kwargs == Pair{String,String}[]
    end

    @testset "block with surrounding whitespace" begin
        p = create_parser(ShortcodeRule())
        ast = p("  {{< video url >}}  ")
        @test ast.first_child.t isa CommonMark.ShortcodeBlock
        @test ast.first_child.t.name == "video"
        @test ast.first_child.t.args == ["url"]
    end

    @testset "multiple inline" begin
        p = create_parser(ShortcodeRule())
        ast = p("A {{< ref page >}} and {{< icon star >}}.")
        out = html(ast)
        @test occursin("{{< ref page >}}", out)
        @test occursin("{{< icon star >}}", out)
        @test startswith(out, "<p>")
    end

    @testset "no args" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< pagebreak >}}")
        @test ast.first_child.t.name == "pagebreak"
        @test ast.first_child.t.args == String[]
        @test ast.first_child.t.kwargs == Pair{String,String}[]
    end

    @testset "with args" begin
        p = create_parser(ShortcodeRule())
        ast = p("x {{< video src=\"url\" width=100 >}} y")
        node = ast.first_child  # Paragraph
        # Find the Shortcode inline
        child = node.first_child
        sc = nothing
        while !CommonMark.isnull(child)
            if child.t isa CommonMark.Shortcode
                sc = child.t
                break
            end
            child = child.nxt
        end
        @test sc !== nothing
        @test sc.name == "video"
        @test sc.args == String[]
        @test sc.kwargs == ["src" => "url", "width" => "100"]
    end

    @testset "custom delimiters" begin
        p = create_parser(ShortcodeRule(open = "{%", close = "%}"))
        ast = p("{% include header %}")
        @test ast.first_child.t isa CommonMark.ShortcodeBlock
        @test ast.first_child.t.name == "include"
        @test ast.first_child.t.args == ["header"]
    end

    @testset "unclosed shortcode" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< unclosed")
        out = html(ast)
        # Should be treated as literal text, HTML-escaped
        @test occursin("&lt;", out)
        @test !occursin("Shortcode", string(ast.first_child.t))
    end

    @testset "empty name" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< >}}")
        out = html(ast)
        # No match - name is required
        @test !occursin("Shortcode", string(typeof(ast.first_child.t)))
    end

    @testset "shortcode in middle of line not promoted" begin
        p = create_parser(ShortcodeRule())
        ast = p("before {{< name >}} after")
        @test ast.first_child.t isa CommonMark.Paragraph
    end

    # --- Argument parsing ---

    @testset "positional args" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< ref page anchor >}}")
        sc = ast.first_child.t
        @test sc.args == ["page", "anchor"]
        @test sc.kwargs == Pair{String,String}[]
    end

    @testset "named args" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< video src=url autoplay=true >}}")
        sc = ast.first_child.t
        @test sc.args == String[]
        @test sc.kwargs == ["src" => "url", "autoplay" => "true"]
    end

    @testset "quoted positional" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< ref \"my page\" >}}")
        @test ast.first_child.t.args == ["my page"]
    end

    @testset "single-quoted positional" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< ref 'my page' >}}")
        @test ast.first_child.t.args == ["my page"]
    end

    @testset "named arg with quoted value" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< video src=\"my url\" >}}")
        @test ast.first_child.t.kwargs == ["src" => "my url"]
    end

    @testset "mixed positional and named" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< video \"my file.mp4\" width=100 >}}")
        sc = ast.first_child.t
        @test sc.args == ["my file.mp4"]
        @test sc.kwargs == ["width" => "100"]
    end

    @testset "equals in quoted value" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< param key=\"a=b\" >}}")
        @test ast.first_child.t.kwargs == ["key" => "a=b"]
    end

    @testset "escaped quotes" begin
        p = create_parser(ShortcodeRule())
        ast = p("x {{< sc \"say \\\"hello\\\"\" >}} y")
        node = ast.first_child
        child = node.first_child
        sc = nothing
        while !CommonMark.isnull(child)
            if child.t isa CommonMark.Shortcode
                sc = child.t
                break
            end
            child = child.nxt
        end
        @test sc !== nothing
        @test sc.args == ["say \"hello\""]
    end

    # --- Handlers ---

    @testset "parse-time handler inline" begin
        handlers = Dict{String,Function}(
            "greeting" => (name, args, kwargs, ctx) -> CommonMark.text("expanded"),
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        ast = p("Hello {{< greeting >}} world.")
        out = html(ast)
        @test occursin("expanded", out)
        @test !occursin("{{<", out)
    end

    @testset "handler with context" begin
        seen_source = Ref("")
        handlers = Dict{String,Function}(
            "check" => (name, args, kwargs, ctx) -> begin
                seen_source[] = ctx.source
                CommonMark.text("ok")
            end,
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        ast = p("{{< check >}}"; source = "test.md")
        @test seen_source[] == "test.md"
    end

    @testset "handler for block shortcode" begin
        handlers = Dict{String,Function}(
            "replaced" =>
                (name, args, kwargs, ctx) -> CommonMark.Node(
                    CommonMark.Paragraph,
                    CommonMark.text("replaced content"),
                ),
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        ast = p("{{< replaced >}}")
        out = html(ast)
        @test occursin("replaced content", out)
        @test !occursin("{{<", out)
    end

    @testset "unknown shortcode with handlers" begin
        handlers = Dict{String,Function}(
            "known" => (name, args, kwargs, ctx) -> CommonMark.text("yes"),
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        # Unknown shortcode stays as-is
        ast = p("{{< unknown arg >}}")
        @test ast.first_child.t isa CommonMark.ShortcodeBlock
        @test ast.first_child.t.name == "unknown"
    end

    @testset "handler returning container with children" begin
        handlers = Dict{String,Function}(
            "multi" =>
                (name, args, kwargs, ctx) -> begin
                    CommonMark.Node(
                        CommonMark.Paragraph,
                        CommonMark.text("child1 "),
                        CommonMark.text("child2"),
                    )
                end,
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        ast = p("{{< multi >}}")
        out = html(ast)
        @test occursin("child1", out)
        @test occursin("child2", out)
    end

    @testset "handler receiving kwargs" begin
        handlers = Dict{String,Function}(
            "link" =>
                (name, args, kwargs, ctx) -> begin
                    href = last(first(p for p in kwargs if first(p) == "href"))
                    CommonMark.text(href)
                end,
        )
        p = create_parser(ShortcodeRule(handlers = handlers))
        ast = p("{{< link href=\"https://example.com\" >}}")
        @test occursin("https://example.com", html(ast))
    end

    # --- Writers ---

    @testset "HTML passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("Text {{< sc arg >}} end.")
        @test html(ast) == "<p>Text {{< sc arg >}} end.</p>\n"
    end

    @testset "HTML block passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("{{< pagebreak >}}")
        out = html(ast)
        @test occursin("{{< pagebreak >}}", out)
    end

    @testset "LaTeX passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("Text {{< sc arg >}} end.")
        @test occursin("{{< sc arg >}}", latex(ast))
    end

    @testset "Typst passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("Text {{< sc arg >}} end.")
        @test occursin("{{< sc arg >}}", typst(ast))
    end

    @testset "Terminal passthrough" begin
        p = create_parser(ShortcodeRule())
        ast = p("Text {{< sc arg >}} end.")
        @test occursin("{{< sc arg >}}", term(ast))
    end

    @testset "Markdown roundtrip" begin
        p = create_parser(ShortcodeRule())
        for input in [
            "Text {{< sc arg >}} end.",
            "{{< pagebreak >}}",
            "A {{< ref page >}} and {{< icon star >}}.",
            "x {{< video src=\"url\" width=100 >}} y",
        ]
            ast = p(input)
            md1 = markdown(ast)
            md2 = markdown(p(md1))
            @test md1 == md2
        end
    end

    @testset "JSON output" begin
        p = create_parser(ShortcodeRule())
        # Inline
        ast = p("Text {{< sc arg >}} end.")
        j = json(ast)
        @test occursin("RawInline", j)
        @test occursin("shortcode", j)
        # Block
        ast = p("{{< pagebreak >}}")
        j = json(ast)
        @test occursin("RawBlock", j)
        @test occursin("shortcode", j)
    end

    @testset "write-time transform" begin
        function my_transform(
            ::MIME"text/html",
            sc::CommonMark.Shortcode,
            node,
            entering,
            writer,
        )
            if sc.name == "hr"
                n = CommonMark.Node(CommonMark.HtmlInline())
                n.literal = "<hr>"
                (n, entering)
            else
                (node, entering)
            end
        end
        my_transform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = create_parser(ShortcodeRule())
        ast = p("before {{< hr >}} after")
        out = html(ast; transform = my_transform)
        @test occursin("<hr>", out)
        @test !occursin("{{<", out)
    end

    # --- Integration ---

    @testset "with other extensions" begin
        p = create_parser([ShortcodeRule(), MathRule(), TableRule()])
        ast = p("Some ``math`` and {{< sc >}} text.")
        out = html(ast)
        @test occursin("math", out)
        @test occursin("{{< sc >}}", out)
    end

    @testset "trigger char conflict" begin
        p = create_parser([ShortcodeRule(), AttributeRule(), RawContentRule()])
        # Shortcode should parse
        ast = p("Text {{< sc >}} end.")
        @test occursin("{{< sc >}}", html(ast))
        # Attribute should still work on inline elements
        ast = p("*text*{.highlight}")
        @test occursin("highlight", html(ast))
        # Raw content should still work
        ast = p("`html`{=html}")
        @test html(ast) == "<p>html</p>\n"
    end
end
