@testitem "transform" tags = [:core, :transform] begin
    using CommonMark
    using Test

    @testset "default transform (pass-through)" begin
        p = Parser()
        ast = p("# Hello\n\n[link](url.md)")

        # Without transform, output is unchanged
        result = html(ast)
        @test occursin("<h1>Hello</h1>", result)
        @test occursin("<a href=\"url.md\">link</a>", result)
    end

    @testset "link transformation" begin
        # Transform that modifies link destinations for HTML only
        function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
            if entering
                new_link = CommonMark.Link()
                name, _ = splitext(link.destination)
                new_link.destination = "/transformed/$name.html"
                new_link.title = link.title
                (CommonMark.Node(new_link, node.sourcepos), entering)
            else
                (node, entering)
            end
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("[click here](page.md)")

        # HTML gets transformed
        result = html(ast; transform = xform)
        @test occursin("href=\"/transformed/page.html\"", result)
        @test occursin(">click here</a>", result)

        # Markdown is not transformed (different MIME)
        result = markdown(ast; transform = xform)
        @test occursin("](page.md)", result)
    end

    @testset "image transformation" begin
        function xform(::MIME"text/html", img::CommonMark.Image, node, entering, writer)
            if entering
                new_img = CommonMark.Image()
                new_img.destination = "/cdn/" * img.destination
                new_img.title = img.title
                (CommonMark.Node(new_img, node.sourcepos), entering)
            else
                (node, entering)
            end
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("![alt](image.png)")

        result = html(ast; transform = xform)
        @test occursin("src=\"/cdn/image.png\"", result)
    end

    @testset "codeblock transformation (syntax highlighting)" begin
        # Transform CodeBlock to HtmlBlock with "highlighted" content
        function xform(::MIME"text/html", ::CommonMark.CodeBlock, node, entering, writer)
            new_node = CommonMark.Node(CommonMark.HtmlBlock())
            lang = node.t.info === nothing ? "" : node.t.info
            new_node.literal = "<pre class=\"highlighted\"><code class=\"$lang\">$(node.literal)</code></pre>\n"
            (new_node, entering)
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("```julia\nx = 1\n```")

        result = html(ast; transform = xform)
        @test occursin("<pre class=\"highlighted\">", result)
        @test occursin("class=\"julia\"", result)
        @test occursin("x = 1", result)
    end

    @testset "document transformation (wrapping)" begin
        # Transform Document to add wrapper on enter/exit
        function xform(mime, ::CommonMark.Document, node, entering, writer)
            if entering
                CommonMark.literal(writer, "<wrapper>\n")
            else
                CommonMark.literal(writer, "</wrapper>\n")
            end
            (node, entering)
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("Hello")

        result = html(ast; transform = xform)
        @test startswith(result, "<wrapper>\n")
        @test endswith(result, "</wrapper>\n")
        @test occursin("<p>Hello</p>", result)
    end

    @testset "document transformation with env interpolation" begin
        # Realistic template-like transform using env values
        function xform(::MIME"text/html", ::CommonMark.Document, node, entering, writer)
            if entering
                title = get(writer.env, "title", "Untitled")
                author = get(writer.env, "author", "")
                CommonMark.literal(
                    writer,
                    """<!DOCTYPE html>
<html>
<head>
<title>$title</title>
<meta name="author" content="$author">
</head>
<body>
""",
                )
            else
                CommonMark.literal(
                    writer,
                    """</body>
</html>
""",
                )
            end
            (node, entering)
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("# Welcome\n\nContent here.")
        env = Dict{String,Any}("title" => "My Document", "author" => "Jane Doe")

        result = html(ast, env; transform = xform)
        @test occursin("<title>My Document</title>", result)
        @test occursin("content=\"Jane Doe\"", result)
        @test occursin("<h1>Welcome</h1>", result)
        @test occursin("<p>Content here.</p>", result)
        @test startswith(result, "<!DOCTYPE html>")
        @test endswith(result, "</html>\n")
    end

    @testset "mime-specific transforms" begin
        # Different behavior for different output formats
        function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
            if entering
                new_link = CommonMark.Link()
                new_link.destination = link.destination * "?format=html"
                new_link.title = link.title
                (CommonMark.Node(new_link, node.sourcepos), entering)
            else
                (node, entering)
            end
        end
        function xform(::MIME"text/latex", link::CommonMark.Link, node, entering, writer)
            if entering
                new_link = CommonMark.Link()
                new_link.destination = link.destination * "?format=latex"
                new_link.title = link.title
                (CommonMark.Node(new_link, node.sourcepos), entering)
            else
                (node, entering)
            end
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("[link](url)")

        @test occursin("url?format=html", html(ast; transform = xform))
        @test occursin("url?format=latex", latex(ast; transform = xform))
    end

    @testset "transform with writer env access" begin
        # Transform that reads from writer.env
        function xform(::MIME"text/html", link::CommonMark.Link, node, entering, writer)
            if entering
                base = get(writer.env, "base_url", "")
                new_link = CommonMark.Link()
                new_link.destination = base * link.destination
                new_link.title = link.title
                (CommonMark.Node(new_link, node.sourcepos), entering)
            else
                (node, entering)
            end
        end
        xform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
            (node, entering)

        p = Parser()
        ast = p("[link](page)")
        env = Dict{String,Any}("base_url" => "https://example.com/")

        result = html(ast, env; transform = xform)
        @test occursin("href=\"https://example.com/page\"", result)
    end
end
