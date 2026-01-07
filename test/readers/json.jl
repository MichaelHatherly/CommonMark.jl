@testitem "Node from dict" tags = [:readers, :json] setup = [Utilities] begin
    using CommonMark
    using Test
    import JSON

    p = create_parser()
    enable!(p, MathRule())
    enable!(p, StrikethroughRule())
    enable!(p, SubscriptRule())
    enable!(p, SuperscriptRule())
    enable!(p, TableRule())
    enable!(p, FencedDivRule())
    enable!(p, RawContentRule())

    # Roundtrip test: json(ast) == json(Node(JSON.parse(json(ast))))
    function json_roundtrips(text, parser = p)
        ast1 = parser(text)
        json1 = JSON.parse(json(ast1))
        ast2 = CommonMark.Node(json1)
        json2 = JSON.parse(json(ast2))
        return json1 == json2
    end

    @testset "roundtrip - basic blocks" begin
        @test json_roundtrips("Hello world")
        @test json_roundtrips("Hello\n\nWorld")
        @test json_roundtrips("# Heading 1")
        @test json_roundtrips("# H1\n\n## H2\n\n### H3")
        @test json_roundtrips("```julia\ncode()\n```")
        @test json_roundtrips("```\nplain code\n```")
        @test json_roundtrips("> quoted text")
        @test json_roundtrips("> outer\n>\n> > inner")
        @test json_roundtrips("---")
    end

    @testset "roundtrip - inlines" begin
        @test json_roundtrips("*emphasis*")
        @test json_roundtrips("**strong**")
        @test json_roundtrips("`code`")
        @test json_roundtrips("[link](https://example.com)")
        @test json_roundtrips("[link](https://example.com \"title\")")
        @test json_roundtrips("![alt](image.png)")
        @test json_roundtrips("line one  \nline two")
        @test json_roundtrips("Hello **bold** and *italic* `code` world")
        @test json_roundtrips("***bold and italic***")
    end

    @testset "roundtrip - lists" begin
        @test json_roundtrips("- item 1\n- item 2\n- item 3")
        @test json_roundtrips("1. first\n2. second\n3. third")

        # Ordered list preserves start
        ast1 = p("5. item five\n6. item six")
        json1 = JSON.parse(json(ast1))
        ast2 = CommonMark.Node(json1)
        @test ast2.first_child.t.list_data.start == 5

        @test json_roundtrips("- outer\n  - inner\n- outer again")
    end

    @testset "roundtrip - extensions" begin
        @test json_roundtrips("~~deleted~~")
        @test json_roundtrips("H~2~O")
        @test json_roundtrips("x^2^")
        @test json_roundtrips("Inline ``x^2``")
        @test json_roundtrips("```math\nx^2\n```")
    end

    @testset "roundtrip - tables" begin
        table_parser = create_parser(TableRule())

        table_md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        @test json_roundtrips(table_md, table_parser)

        table_md2 = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L    | C      | R     |
        """
        @test json_roundtrips(table_md2, table_parser)
    end

    @testset "metadata conversion" begin
        data = Dict(
            "pandoc-api-version" => [1, 23, 1],
            "meta" => Dict(
                "title" => Dict("t" => "MetaString", "c" => "Test Title"),
                "count" => Dict("t" => "MetaBool", "c" => true),
                "items" => Dict(
                    "t" => "MetaList",
                    "c" => [
                        Dict("t" => "MetaString", "c" => "a"),
                        Dict("t" => "MetaString", "c" => "b"),
                    ],
                ),
                "nested" => Dict(
                    "t" => "MetaMap",
                    "c" => Dict("key" => Dict("t" => "MetaString", "c" => "value")),
                ),
            ),
            "blocks" => [],
        )

        ast = CommonMark.Node(data)
        @test ast.meta["title"] == "Test Title"
        @test ast.meta["count"] == true
        @test ast.meta["items"] == ["a", "b"]
        @test ast.meta["nested"]["key"] == "value"
    end

    @testset "unknown types" begin
        # Unknown block type should warn but not error
        data = Dict(
            "pandoc-api-version" => [1, 23, 1],
            "meta" => Dict(),
            "blocks" => [Dict("t" => "UnknownBlock", "c" => [])],
        )
        ast = @test_logs (:warn, r"Unknown block type") CommonMark.Node(data)
        @test ast.t isa CommonMark.Document
        @test CommonMark.isnull(ast.first_child)

        # Unknown inline type should warn but not error
        data = Dict(
            "pandoc-api-version" => [1, 23, 1],
            "meta" => Dict(),
            "blocks" => [
                Dict(
                    "t" => "Para",
                    "c" => [
                        Dict("t" => "Str", "c" => "hello"),
                        Dict("t" => "UnknownInline", "c" => []),
                    ],
                ),
            ],
        )
        ast = @test_logs (:warn, r"Unknown inline type") CommonMark.Node(data)
        @test !CommonMark.isnull(ast.first_child)
    end

    @testset "complex document" begin
        doc_md = """
        # Main Title

        Some introductory text with **bold** and *italic*.

        ## Section 1

        - Item one
        - Item two with `code`
        - Item three with [link](https://example.com)

        > A blockquote with multiple
        > lines of text.

        ```julia
        function hello()
            println("Hello!")
        end
        ```

        1. First numbered
        2. Second numbered

        ---

        Final paragraph.
        """

        @test json_roundtrips(doc_md)
    end

    @testset "json(Dict, ast)" begin
        ast = p("# Hello\n\nWorld")
        d = json(Dict, ast)

        @test d isa Dict
        @test haskey(d, "pandoc-api-version")
        @test haskey(d, "meta")
        @test haskey(d, "blocks")
        @test length(d["blocks"]) == 2

        # Roundtrip without JSON string serialization
        ast2 = CommonMark.Node(d)
        d2 = json(Dict, ast2)
        @test d == d2
    end
end
