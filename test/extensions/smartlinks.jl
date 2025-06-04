@testitem "smart_links" tags = [:extensions, :smartlinks] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_smartlink = test_all_formats(pwd())

    function handler(::MIME"text/html", obj::CommonMark.Link, node::CommonMark.Node, env)
        name, _ = splitext(obj.destination)
        obj = deepcopy(obj)
        obj.destination = join([env["root"], "$name.html"], "/")
        return obj
    end
    handler(mime, obj, node, env) = obj

    p = create_parser()
    env = Dict("root" => "/root", "smartlink-engine" => handler)

    # Smart link transformation
    ast = p("[link](url.md)")
    test_smartlink("link", ast, "smartlinks", env = env)

    # Image (not transformed by smartlink)
    ast = p("![link](url.img)")
    test_smartlink("image", ast, "smartlinks", env = env)
end
