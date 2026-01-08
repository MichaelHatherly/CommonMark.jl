@testitem "json_writer" tags = [:writers, :json] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests
    import JSON
    import pandoc_jll

    p = create_parser()

    # Helper: pretty-print JSON for reference comparison
    function pretty_json(text, parser = p)
        ast = parser(text)
        doc = JSON.parse(json(ast))
        sprint(io -> CommonMark._json(io, doc; indent = 2, sorted = true))
    end

    # Helper: test reference with pretty JSON
    function test_json(filename, text, parser = p)
        full_path = joinpath(pwd(), filename)
        @test_reference full_path ReferenceTests.Text(pretty_json(text, parser))
    end

    # Helper: roundtrip through pandoc binary
    pandoc_cmd = try
        pandoc_jll.is_available() ? pandoc_jll.pandoc() : Sys.which("pandoc")
    catch
        Sys.which("pandoc")
    end

    function roundtrip(text, to = "gfm", parser = p)
        ast = parser(text)
        output = json(ast)
        String(read(pipeline(`echo $output`, `$pandoc_cmd -f json -t $to`)))
    end

    # Core block types
    test_json("references/json/paragraph.json", "Hello world")
    test_json("references/json/h1.json", "# Heading 1")
    test_json("references/json/h2.json", "## Heading 2")
    test_json("references/json/h3.json", "### Heading 3")
    test_json("references/json/blockquote.json", "> quote")
    test_json("references/json/thematic_break.json", "***")
    test_json(
        "references/json/code_block.json",
        """
        ```julia
        println("hello")
        ```
        """,
    )
    test_json(
        "references/json/list_bullet.json",
        """
        - item 1
        - item 2
        """,
    )
    test_json(
        "references/json/list_ordered.json",
        """
        1. first
        2. second
        """,
    )
    test_json(
        "references/json/list_loose.json",
        """
        - item 1

        - item 2
        """,
    )
    test_json("references/json/html_block.json", "<div>html</div>")

    # Core inline types
    test_json("references/json/code.json", "`code`")
    test_json("references/json/emph.json", "*emphasis*")
    test_json("references/json/strong.json", "**strong**")
    test_json("references/json/link.json", "[link](http://example.com)")
    test_json("references/json/image.json", "![alt](http://example.com/img.png)")
    test_json("references/json/html_inline.json", "<em>inline</em>")
    test_json("references/json/linebreak.json", "line1\\\nline2")

    # Text tokenization
    test_json("references/json/text_spaces.json", "hello world foo")
    test_json(
        "references/json/text_softbreak.json",
        """
        line1
        line2
        """,
    )

    # Extensions
    @testset "tables" begin
        table_parser = create_parser(TableRule())
        test_json(
            "references/json/table.json",
            """
            | Left | Center | Right |
            |:-----|:------:|------:|
            | a    | b      | c     |
            """,
            table_parser,
        )
    end

    @testset "footnotes" begin
        fn_parser = create_parser(FootnoteRule())
        test_json(
            "references/json/footnote.json",
            """
            Text[^1]

            [^1]: Footnote content.
            """,
            fn_parser,
        )
    end

    @testset "math" begin
        math_parser = create_parser(MathRule())
        test_json("references/json/math_inline.json", "\$x^2\$", math_parser)
        test_json(
            "references/json/math_display.json",
            """
            \$\$
            E = mc^2
            \$\$
            """,
            math_parser,
        )
    end

    @testset "strikethrough" begin
        st_parser = create_parser(StrikethroughRule())
        test_json("references/json/strikethrough.json", "~~deleted~~", st_parser)
    end

    @testset "admonitions" begin
        adm_parser = create_parser(AdmonitionRule())
        test_json(
            "references/json/admonition.json",
            """
            !!! note "Title"
                Content here.
            """,
            adm_parser,
        )
    end

    @testset "frontmatter" begin
        fm_parser = create_parser(FrontMatterRule())
        test_json(
            "references/json/frontmatter.json",
            """
            ---
            title: My Document
            author: Test Author
            ---

            Content.
            """,
            fm_parser,
        )
    end

    @testset "tasklist" begin
        task_parser = create_parser(TaskListRule())
        test_json(
            "references/json/tasklist.json",
            """
            - [ ] Unchecked
            - [x] Checked
            """,
            task_parser,
        )
    end

    @testset "fenced_divs" begin
        div_parser = create_parser(FencedDivRule())
        test_json(
            "references/json/fenced_div.json",
            """
            ::: warning
            Content here.
            :::
            """,
            div_parser,
        )
    end

    @testset "github_alerts" begin
        alert_parser = create_parser(GitHubAlertRule())
        test_json(
            "references/json/github_alert.json",
            """
            > [!NOTE]
            > This is a note.
            """,
            alert_parser,
        )
    end

    @testset "subscript" begin
        sub_parser = create_parser(SubscriptRule())
        test_json("references/json/subscript.json", "H~2~O", sub_parser)
    end

    @testset "superscript" begin
        sup_parser = create_parser(SuperscriptRule())
        test_json("references/json/superscript.json", "x^2^", sup_parser)
    end

    @testset "citations" begin
        cite_parser = create_parser(CitationRule())
        test_json("references/json/citation.json", "See @smith2020.", cite_parser)
    end

    @testset "referencelinks" begin
        ref_parser = create_parser(ReferenceLinkRule())
        test_json(
            "references/json/referencelink.json",
            """
            [example][ex]

            [ex]: http://example.com
            """,
            ref_parser,
        )
    end

    @testset "raw" begin
        raw_parser = create_parser(RawContentRule())
        test_json(
            "references/json/raw_latex.json",
            """
            ```{=latex}
            \\textbf{bold}
            ```
            """,
            raw_parser,
        )
    end

    @testset "attributes" begin
        attr_parser = create_parser(AttributeRule())
        test_json(
            "references/json/attributes.json",
            """
            {#my-id .highlight .important}
            # Heading
            """,
            attr_parser,
        )
    end

    @testset "autoidentifiers" begin
        auto_parser = create_parser(AutoIdentifierRule())
        test_json("references/json/autoidentifier.json", "# My Heading Text", auto_parser)
    end

    # Roundtrip validation (requires pandoc binary)
    if pandoc_cmd !== nothing
        @testset "roundtrip" begin
            @test strip(roundtrip("# Hello")) == "# Hello"
            @test strip(roundtrip("**bold**")) == "**bold**"
            @test strip(roundtrip("*italic*")) == "*italic*"
            @test strip(roundtrip("`code`")) == "`code`"
            @test strip(roundtrip("[link](url)")) == "[link](url)"
            @test strip(roundtrip("- item")) == "- item"
            @test strip(roundtrip("1. item")) == "1.  item"
            @test strip(roundtrip("> quote")) == "> quote"
        end
    end
end
