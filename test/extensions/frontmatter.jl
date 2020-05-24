@testset "Frontmatter" begin
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.FrontMatterRule(json=JSON.Parser.parse, toml=TOML.parse, yaml=YAML.load))

    test = function (text, expected)
        ast = p(text)
        data = ast.first_child.t.data
        r = CommonMark.Renderer(CommonMark.HTML())
        html = r(ast, String)
        @test length(data) == 1
        @test data["field"] == "data"
        @test html == expected
    end

    # JSON
    test(
        """
        ;;;
        {"field": "data"}
        ;;;
        ;;;
        """,
        "<p>;;;</p>\n"
    )

    # TOML
    test(
        """
        +++
        field = "data"
        +++
        +++
        """,
        "<p>+++</p>\n"
    )

    # YAML
    test(
        """
        ---
        field: data
        ---
        ---
        """,
        "<hr />\n"
    )

    # Unclosed frontmatter. Runs on until EOF.
    text =
    """
    +++
    one = 1
    two = 2
    """
    ast = p(text)
    data = ast.first_child.t.data
    @test data["one"] == 1
    @test data["two"] == 2

    # Frontmatter must begin on the first line of the file. Otherwise it's a literal.
    text = "\n+++"
    ast = p(text)
    r = CommonMark.Renderer(CommonMark.HTML())
    html = r(ast, String)
    @test html == "<p>+++</p>\n"
end
