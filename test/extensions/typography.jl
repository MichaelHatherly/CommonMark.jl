@testitem "typography" tags = [:extensions, :typography] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_typography = test_all_formats(pwd())

    p = create_parser(TypographyRule())

    # Basic typography replacements
    text = "\"Double quotes\", 'single quotes', ellipses...., and-- dashes---"
    ast = p(text)
    test_typography("basic", ast, "typography")
end

@testitem "typography roundtrip" tags = [:extensions, :typography] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(TypographyRule())

    # A quote, dash, or ellipsis that survived the parse as literal text has to
    # survive the next one too, so the writer keeps it out of the rule's reach.
    @test Utilities.faithful(p, "&#34;x&#34;\n")
    @test Utilities.faithful(p, "&#39;x&#39;\n")
    @test Utilities.faithful(p, "a&#45;&#45;b\n")
    @test Utilities.faithful(p, "a&#46;&#46;&#46;b\n")
    @test Utilities.faithful(p, "[a](url &quot;tit&quot;)\n")

    # Text the rule has already transformed is written as it stands.
    @test markdown(p("\"x\" -- y ... z\n")) == "“x” – y … z\n"

    # Without the rule nothing claims those characters.
    @test markdown(Parser()("&#34;x&#34;\n")) == "\"x\"\n"

    # A rule with conversions switched off claims only the ones left on.
    q = create_parser(TypographyRule(double_quotes = false, dashes = false))
    @test markdown(q("&#34;x&#34;\n")) == "\"x\"\n"
    @test markdown(q("a&#45;&#45;b\n")) == "a--b\n"
    @test markdown(q("&#39;x&#39;\n")) == "\\'x\\'\n"
    @test markdown(q("a&#46;&#46;&#46;b\n")) == "a\\...b\n"
end
