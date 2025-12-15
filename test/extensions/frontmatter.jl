@testitem "frontmatter" tags = [:extensions, :frontmatter] setup = [Utilities] begin
    using CommonMark
    using Test
    using JSON
    using Pkg.TOML
    using YAML

    p = Parser()
    enable!(p, FrontMatterRule(json = JSON.parse, toml = TOML.parse, yaml = YAML.load))

    test_single = test_single_format(pwd(), p)

    # Test function for checking frontmatter data
    test_frontmatter_data = function (text)
        ast = p(text)
        data = frontmatter(ast)
        @test length(data) == 1
        @test data["field"] == "data"
        return ast
    end

    # JSON
    json_text = """
    ;;;
    {"field": "data"}
    ;;;
    ;;;
    """
    test_frontmatter_data(json_text)
    test_single("references/frontmatter/json.html.txt", json_text, html)

    # TOML
    toml_text = """
    +++
    field = "data"
    +++
    +++
    """
    test_frontmatter_data(toml_text)
    test_single("references/frontmatter/toml.html.txt", toml_text, html)

    # YAML
    yaml_text = """
    ---
    field: data
    ---
    ---
    """
    test_frontmatter_data(yaml_text)
    test_single("references/frontmatter/yaml.html.txt", yaml_text, html)

    # Unclosed frontmatter. Runs on until EOF.
    text = """
           +++
           one = 1
           two = 2
           """
    ast = p(text)
    data = frontmatter(ast)
    @test data["one"] == 1
    @test data["two"] == 2

    # Frontmatter must begin on the first line of the file. Otherwise it's a literal.
    text = "\n+++"
    test_single("references/frontmatter/not_first_line.html.txt", text, html)

    text = """
           ---
           field: data
           ---
           """
    ast = p(text)
    @test markdown(ast) == "---\nfield: data\n---\n"
    @test markdown(p(markdown(ast))) == markdown(ast)
end
