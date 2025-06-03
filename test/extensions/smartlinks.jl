@testitem "smart_links" tags = [:extensions, :smartlinks] begin
    using CommonMark
    using Test
    using ReferenceTests

    # Helper function for tests that can use references
    function test_smartlink(base_name, ast, env)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/smartlinks/$(base_name).$(ext)"
            output = func(ast, env)
            @test_reference filename Text(output)
        end
    end

    function handler(::MIME"text/html", obj::CommonMark.Link, node::CommonMark.Node, env)
        name, _ = splitext(obj.destination)
        obj = deepcopy(obj)
        obj.destination = join([env["root"], "$name.html"], "/")
        return obj
    end
    handler(mime, obj, node, env) = obj

    p = Parser()
    env = Dict("root" => "/root", "smartlink-engine" => handler)

    # Smart link transformation
    ast = p("[link](url.md)")
    test_smartlink("link", ast, env)

    # Image (not transformed by smartlink)
    ast = p("![link](url.img)")
    test_smartlink("image", ast, env)
end
