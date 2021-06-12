@testset "Smart Links" begin
    abstract type SmartLinkExtension end
    function CM.html(link::CM.Link, f::CM.Fmt{E}, node::CM.Node, enter::Bool) where E<:SmartLinkExtension
        if enter
            # When entering the link node we change the destination of the
            # `link` and pass that to the base formatting implementation.
            name, _ = splitext(link.destination)
            destination = join([f.env["root"], "$name.html"], "/")
            title = link.title
            link = CommonMark.Link()
            link.destination = destination
            link.title = title
        end
        # Dispatch to the parent type of `E` which will use the base formatting
        # implementation to write the actual link.
        CM.html(link, CM.Fmt(f, supertype(E)), node, enter)
    end

    p = Parser()
    env = Dict("root" => "/root")

    ast = p("[link](url.md)")
    @test html(ast, SmartLinkExtension; env=env) == "<p><a href=\"/root/url.html\">link</a></p>\n"
    @test latex(ast, SmartLinkExtension; env=env) == "\\href{url.md}{link}\\par\n"
    @test term(ast, SmartLinkExtension; env=env) == " \e[34;4mlink\e[39;24m\n"
    @test markdown(ast, SmartLinkExtension; env=env) == "[link](url.md)\n"

    ast = p("![link](url.img)")
    @test html(ast, SmartLinkExtension; env=env) == "<p><img src=\"url.img\" alt=\"link\" /></p>\n"
    @test latex(ast, SmartLinkExtension; env=env) == "\\begin{figure}\n\\centering\n\\includegraphics[max width=\\linewidth]{url.img}\n\\caption{link}\n\\end{figure}\n\\par\n"
    @test term(ast, SmartLinkExtension; env=env) == " \e[32mlink\e[39m\n"
    @test markdown(ast, SmartLinkExtension; env=env) == "![link](url.img)\n"
end
