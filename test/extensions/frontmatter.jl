@testset "Frontmatter" begin
    p = CommonMark.Parser()
    pushfirst!(p.block_starts, CommonMark.parse_front_matter)

    p.fenced_literals[";;;"] = JSON.Parser.parse
    p.fenced_literals["+++"] = TOML.parse
    p.fenced_literals["---"] = YAML.load

    test = function (text, expected)
        ast = CommonMark.parse(p, text)
        data = ast.first_child.t.data
        r = CommonMark.Renderer(CommonMark.HTML())
        html = read(CommonMark.render(r, ast), String)
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
    ast = CommonMark.parse(p, text)
    data = ast.first_child.t.data
    @test data["one"] == 1
    @test data["two"] == 2

    # Frontmatter must begin on the first line of the file. Otherwise it's a literal.
    text = "\n+++"
    ast = CommonMark.parse(p, text)
    r = CommonMark.Renderer(CommonMark.HTML())
    html = read(CommonMark.render(r, ast), String)
    @test html == "<p>+++</p>\n"
end
