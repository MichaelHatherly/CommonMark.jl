@testitem "smart_links" tags = [:extensions, :smartlinks] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_smartlink = test_all_formats(pwd())

    # Transform function using new API - dispatches on Link container type
    # Only transform on entering - the writer will use the modified destination
    # Children are visited via the original AST structure
    function transform(
        ::MIME"text/html",
        link::CommonMark.Link,
        node::CommonMark.Node,
        entering,
        writer,
    )
        if entering
            name, _ = splitext(link.destination)
            dest = join([get(writer.env, "root", ""), "$name.html"], "/")
            new_node = CommonMark.Node(CommonMark.Link; dest = dest, title = link.title)
            (new_node, entering)
        else
            (node, entering)
        end
    end
    transform(mime, ::CommonMark.AbstractContainer, node, entering, writer) =
        (node, entering)

    p = create_parser()
    env = Dict{String,Any}("root" => "/root")

    # Smart link transformation
    ast = p("[link](url.md)")
    test_smartlink("link", ast, "smartlinks", env = env, transform = transform)

    # Image (not transformed by transform)
    ast = p("![link](url.img)")
    test_smartlink("image", ast, "smartlinks", env = env, transform = transform)
end
