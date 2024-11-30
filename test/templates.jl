test_template_str(filename) = read(joinpath(@__DIR__, "templates", filename), String)

@testset "Templates" begin
    p = Parser()

    ast = p("*word*")
    dict = Dict("template-engine" => render)

    test = function (a, b)
        norm = s -> replace(s, "\r\n" => "\n")
        @test norm(a) == norm(b)
    end

    # Basic.

    test(html(ast, dict), test_template_str("basic.html"))
    test(latex(ast, dict), test_template_str("basic.tex"))

    # Ignore templates.
    test(markdown(ast, dict), "*word*\n")
    test(term(ast, dict), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, dict))["cells"][1]["source"]), "*word*\n")

    # Global Configuration.

    env = merge(
        dict,
        Dict(
            "date" => "DATE",
            "authors" => ["ONE", "TWO"],
            "title" => "TITLE",
            "subtitle" => "SUBTITLE",
            "abstract" => "ABSTRACT",
            "keywords" => ["1", "2"],
            "lang" => "fr",
            "html" => Dict(
                "css" => ["one.css", "two.css"],
                "js" => ["one.js", "two.js"],
                "header" => "<script></script>",
                "footer" => "<footer></footer>",
            ),
            "latex" =>
                Dict("documentclass" => "book", "preamble" => "\\usepackage{custom}"),
        ),
    )

    test(html(ast, env), test_template_str("env.html"))
    test(latex(ast, env), test_template_str("env.tex"))

    # Ignore templates.
    test(markdown(ast, env), "*word*\n")
    test(term(ast, env), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, env))["cells"][1]["source"]), "*word*\n")

    # Front Matter Configuration.

    p = enable!(Parser(), FrontMatterRule(toml = TOML.parse))
    text = """
           +++
           authors = ["THREE", "FOUR"]
           title = "NEW TITLE"
           abstract = "NEW ABSTRACT"
           keywords = ["3", "4"]
           +++

           *word*
           """
    ast = p(text)

    test(html(ast, dict), test_template_str("frontmatter.html"))
    test(latex(ast, dict), test_template_str("frontmatter.tex"))

    # Ignore templates.
    test(markdown(ast, dict), text)
    test(term(ast, dict), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, dict))["cells"][1]["source"]), text)

    # Front Matter and Global Configuration.

    test(html(ast, env), test_template_str("frontmatter-env.html"))
    test(latex(ast, env), test_template_str("frontmatter-env.tex"))
    test(markdown(ast, env), text)
    test(term(ast, env), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, env))["cells"][1]["source"]), text)

    # File and string templates.

    text = """
           +++
           [html.template]
           file = "templates/custom-template.html.mustache"
           [latex.template]
           file = "templates/custom-template.latex.mustache"
           +++

           *word*
           """
    ast = p(text)
    cd(@__DIR__) do
        test(html(ast, env), "<section>\n<p><em>word</em></p>\n\n</section>\n")
        test(
            latex(ast, env),
            "\\documentclass{memoir}\n\\begin{document}\n\\textit{word}\\par\n\n\\end{document}\n",
        )
    end

    config = """
             [html.template]
             string = "<body>\\n\${{body}}</body>"
             [latex.template]
             string = "\\\\begin{document}\\n\${{body}}\\\\end{document}"
             """
    env = merge(dict, TOML.parse(config))
    cd(@__DIR__) do
        test(html(ast, env), "<body>\n<p><em>word</em></p>\n</body>")
        test(latex(ast, env), "\\begin{document}\n\\textit{word}\\par\n\\end{document}")
    end
end
