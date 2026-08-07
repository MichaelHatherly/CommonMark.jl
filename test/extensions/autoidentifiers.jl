@testitem "auto_identifiers" tags = [:extensions, :autoidentifiers] begin
    using CommonMark
    using Test
    slugs = Dict(
        # Examples from pandoc documentation:
        "Heading identifiers in HTML" => "heading-identifiers-in-html",
        "Maître d'hôtel" => "maître-dhôtel",
        "*Dogs*?--in *my* house?" => "dogs--in-my-house",
        "[HTML], [S5], or [RTF]?" => "html-s5-or-rtf",
        "3. Applications" => "applications",
        "33" => "section",
        # Whitespace around and inside a heading is a separator, not content.
        "  Padded  " => "padded",
        "Tab\tseparated" => "tab-separated",
    )
    for (k, v) in slugs
        @test CommonMark.slugify(k) == v
    end

    rule = AutoIdentifierRule()
    p = enable!(Parser(), rule)

    text = "# Heading."
    ast = p(text)
    @test ast.first_child.meta["id"] == "heading"
    @test rule.refs[ast]["heading"] == 1

    rule = AutoIdentifierRule()
    p = enable!(Parser(), rule)

    text = "# Heading.\n# heading!"
    ast = p(text)
    @test ast.first_child.meta["id"] == "heading"
    @test ast.first_child.nxt.meta["id"] == "heading-1"
    @test rule.refs[ast]["heading"] == 2

    rule = AutoIdentifierRule()
    p = enable!(Parser(), [rule, AttributeRule()])

    text = "{#refs}\n# Heading.\n# heading!"
    ast = p(text)
    @test ast.first_child.nxt.meta["id"] == "refs"
    @test ast.first_child.nxt.nxt.meta["id"] == "heading"
    @test rule.refs[ast]["heading"] == 1

    rule = AutoIdentifierRule()
    p = enable!(Parser(), rule)

    text = "> # Heading."
    ast = p(text)
    @test ast.first_child.first_child.meta["id"] == "heading"
    @test rule.refs[ast]["heading"] == 1
end

@testitem "auto_identifiers follow the heading text" tags = [:extensions, :autoidentifiers] setup =
    [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(AutoIdentifierRule())

    # The id spells the text the heading renders, not the source that spelled it.
    @test occursin("id=\"a-b\"", html(p("# a\tb\n")))
    @test occursin("id=\"ab\"", html(p("# a&amp;b\n")))

    # A heading written back out therefore keeps the id it started with.
    @test Utilities.faithful(p, "# a\tb\n")
    @test Utilities.faithful(p, "# a&amp;b\n")
end
