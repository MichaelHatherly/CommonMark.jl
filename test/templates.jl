@testset "Templates" begin
    struct MustacheTemplate <: TemplateExtension end

    function template(env, fmt)
        # Template load order:
        #
        # - <fmt>.template.string
        # - <fmt>.template.file
        # - TEMPLATES["<fmt>"]
        #
        config = get(() -> Dict{String, Any}(), env, fmt)
        tmp = get(() -> Dict{String, Any}(), config, "template")
        get(tmp, "string") do
            TEMPLATES = Dict(
                "html" => "templates/html.mustache",
                "latex" => "templates/latex.mustache",
            )
            haskey(tmp, "file") ? read(tmp["file"], String) :
            haskey(TEMPLATES, fmt) ? read(TEMPLATES[fmt], String) : ""
        end
    end

    CM.renderer(f::Fmt{MustacheTemplate, CM.T"html"}, env) =
        Mustache.render(f.io, template(env, "html"), env; tags = ("\${", "}"))

    CM.renderer(f::Fmt{MustacheTemplate, CM.T"latex"}, env) =
        Mustache.render(f.io, template(env, "latex"), env; tags = ("\${", "}"))

    p = Parser()

    ast = p("*word*")
    dict = Dict()

    test = function (a, b)
        norm = s -> replace(s, "\r\n" => "\n")
        @test norm(a) == norm(b)
    end

    # Basic.

    test(html(ast, MustacheTemplate; env=dict), read("templates/basic.html", String))
    test(latex(ast, MustacheTemplate; env=dict), read("templates/basic.tex", String))

    # Ignore templates.
    test(markdown(ast, MustacheTemplate; env=dict), "*word*\n")
    test(term(ast, MustacheTemplate; env=dict), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, MustacheTemplate; env=dict))["cells"][1]["source"]), "*word*\n")

    # Global Configuration.

    env = merge(dict, Dict(
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
        "latex" => Dict(
            "documentclass" => "book",
            "preamble" => "\\usepackage{custom}",
        )
    ))

    test(html(ast, MustacheTemplate; env=env), read("templates/env.html", String))
    test(latex(ast, MustacheTemplate; env=env), read("templates/env.tex", String))

    # Ignore templates.
    test(markdown(ast, MustacheTemplate; env=env), "*word*\n")
    test(term(ast, MustacheTemplate; env=env), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, MustacheTemplate; env=env))["cells"][1]["source"]), "*word*\n")

    # Front Matter Configuration.

    p = enable!(Parser(), FrontMatterRule(toml=TOML.parse))
    text =
    """
    +++
    authors = ["THREE", "FOUR"]
    title = "NEW TITLE"
    abstract = "NEW ABSTRACT"
    keywords = ["3", "4"]
    +++

    *word*
    """
    ast = p(text)

    test(html(ast, MustacheTemplate; env=env), read("templates/frontmatter.html", String))
    test(latex(ast, MustacheTemplate; env=env), read("templates/frontmatter.tex", String))

    # Ignore templates.
    test(markdown(ast, MustacheTemplate; env=dict), text)
    test(term(ast, MustacheTemplate; env=dict), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, MustacheTemplate; env=dict))["cells"][1]["source"]), text)

    # Front Matter and Global Configuration.

    test(html(ast, MustacheTemplate; env=env), read("templates/frontmatter-env.html", String))
    test(latex(ast, MustacheTemplate; env=env), read("templates/frontmatter-env.tex", String))

    # Ignore templates.
    test(markdown(ast, MustacheTemplate; env=env), text)
    test(term(ast, MustacheTemplate; env=env), " \e[3mword\e[23m\n")
    test(join(JSON.parse(notebook(ast, MustacheTemplate; env=env))["cells"][1]["source"]), text)

    # File and string templates.

    text =
    """
    +++
    [html.template]
    file = "templates/custom-template.html.mustache"
    [latex.template]
    file = "templates/custom-template.latex.mustache"
    +++

    *word*
    """
    ast = p(text)
    test(html(ast, MustacheTemplate; env=env), "<section>\n<p><em>word</em></p>\n\n</section>\n")
    test(latex(ast, MustacheTemplate; env=env), "\\documentclass{memoir}\n\\begin{document}\n\\textit{word}\\par\n\n\\end{document}\n")

    config =
    """
    [html.template]
    string = "<body>\\n\${{body}}</body>"
    [latex.template]
    string = "\\\\begin{document}\\n\${{body}}\\\\end{document}"
    """
    env = merge(dict, TOML.parse(config))

    test(html(ast, MustacheTemplate; env=env), "<body>\n<p><em>word</em></p>\n</body>")
    test(latex(ast, MustacheTemplate; env=env), "\\begin{document}\n\\textit{word}\\par\n\\end{document}")
end
