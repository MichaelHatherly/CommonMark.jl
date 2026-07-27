@testitem "parser_functionality" tags = [:core] begin
    using CommonMark
    using Test
    # AST metadata via keywords.
    p = Parser()
    ast = p(""; empty = true)
    @test ast.meta["empty"] == true

    # Parsing file contents.
    readme = joinpath(@__DIR__, "../README.md")
    ast = open(p, readme)
    @test ast.meta["source"] == readme
    @test ast.first_child.t isa CommonMark.Heading

    # Parsing contents of a buffer.
    buffer = IOBuffer("# heading")
    ast = p(buffer)
    @test ast.first_child.t isa CommonMark.Heading
    @test markdown(ast) == "# heading\n"

    # Disabling parser rules.
    p = disable!(Parser(), CommonMark.AtxHeadingRule())
    ast = p("# *not a header*")
    @test ast.first_child.t isa CommonMark.Paragraph
    @test ast.first_child.first_child.nxt.t isa CommonMark.Emph
    # Written for a parser with the rule enabled, which is the safe assumption.
    @test markdown(ast) == "\\# *not a header*\n"

    # Make sure that enable! or disable! do not create duplicate rules
    # https://github.com/MichaelHatherly/CommonMark.jl/issues/45
    @test CommonMark.is_same_rule(LinkRule(), LinkRule())
    @test CommonMark.is_same_rule(FootnoteRule(), FootnoteRule())
    @test !CommonMark.is_same_rule(FootnoteRule(), LinkRule())
    let fn = CommonMark.is_same_rule(LinkRule())
        @test fn(LinkRule())
        @test !fn(FootnoteRule())
    end
    let fnrule1 = FootnoteRule(), fnrule2 = FootnoteRule()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
        fnrule1.cache["foo"] = CommonMark.Node()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
        fnrule2.cache["bar"] = CommonMark.Node()
        @test CommonMark.is_same_rule(fnrule1, fnrule2)
    end

    are_rules_unique(p::Parser) = p.rules == unique(p.rules)
    let p = Parser()
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), TableRule())
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = enable!(Parser(), [TableRule(), FootnoteRule()])
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test CommonMark.ruleoccursin(TableRule(), p.rules)
        @test CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    @test_throws ErrorException enable!(Parser(), LinkRule())
    @test_throws ErrorException enable!(Parser(), [LinkRule(), ImageRule()])
    @test_throws ErrorException enable!(Parser(), [LinkRule(), FootnoteRule()])
    let p = disable!(Parser(), LinkRule())
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), ImageRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test !CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), TableRule())
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [TableRule(), FootnoteRule()])
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = disable!(Parser(), [LinkRule(), FootnoteRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test !CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    # Parser constructor with enable/disable keywords
    let p = Parser(enable = [TableRule()])
        @test CommonMark.ruleoccursin(TableRule(), p.rules)
        @test CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = Parser(enable = [TableRule(), FootnoteRule()])
        @test CommonMark.ruleoccursin(TableRule(), p.rules)
        @test CommonMark.ruleoccursin(FootnoteRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = Parser(disable = [LinkRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = Parser(disable = [LinkRule(), ImageRule()])
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test !CommonMark.ruleoccursin(ImageRule(), p.rules)
        @test are_rules_unique(p)
    end
    let p = Parser(enable = [TableRule()], disable = [LinkRule()])
        @test CommonMark.ruleoccursin(TableRule(), p.rules)
        @test !CommonMark.ruleoccursin(LinkRule(), p.rules)
        @test are_rules_unique(p)
    end
    # Functional test: disabled rule doesn't parse
    let p = Parser(disable = [AtxHeadingRule()])
        ast = p("# not a header")
        @test ast.first_child.t isa CommonMark.Paragraph
    end
end

@testitem "a paragraph of definitions leaves no empty block" tags = [:core] begin
    using CommonMark
    using Test
    p = Parser()

    # A setext underline has no heading text to underline when the paragraph
    # above it held nothing but definitions, so the line is read on its own and
    # the emptied paragraph goes away.
    @test html(p("[foo]: /url\n---\n")) == "<hr />\n"
    @test markdown(p("[foo]: /url\n---\n")) == "* * *\n"

    # `===` spells no other block, so it stays as the paragraph's text.
    @test html(p("[foo]: /url\n===\n")) == "<p>===</p>\n"

    # Control: a definition followed by a blank line already left nothing.
    @test html(p("[foo]: /url\n\ntext\n")) == "<p>text</p>\n"
end

@testitem "claimed syntax reads rules from any collection" tags = [:core] begin
    using CommonMark
    using Test

    # `enable!` takes a tuple as readily as a vector, so both spell the same
    # set of claims.
    rules = (TypographyRule(), SubscriptRule(), TableRule())
    @test CommonMark.claimed_syntax(rules) == CommonMark.claimed_syntax(collect(rules))
    @test "~" in CommonMark.claimed_syntax(rules)
    @test "|" in CommonMark.claimed_syntax(rules)
end

@testitem "claimed syntax is a vector of strings" tags = [:core] begin
    using CommonMark
    using Test

    # Every rule spells its claims the same way, so gathering them over a
    # parser's rules infers a concrete type.
    @test @inferred(CommonMark.claimed_syntax(DollarMathRule())) == ["\$"]
    @test @inferred(CommonMark.claimed_syntax(TypographyRule(dashes = false))) ==
        ["\"", "'", "..."]

    # A rule that claims nothing beyond the core spec still answers with a
    # vector.
    @test @inferred(CommonMark.claimed_syntax(FootnoteRule())) == String[]
end

@testitem "reference definition discards invalid title" tags = [:core] begin
    using CommonMark
    using Test
    p = Parser()

    # A title followed by other text on the line is invalid; the definition is
    # still valid using the URL alone, and the title must be discarded.
    ast = p("[foo]: /url\n\"title\" extra\n\n[foo]\n")
    @test occursin("<a href=\"/url\">foo</a>", html(ast))
    @test !occursin("title=", html(ast))

    # Control: a clean title on its own line is kept.
    ast = p("[foo]: /url\n\"title\"\n\n[foo]\n")
    @test occursin("<a href=\"/url\" title=\"title\">foo</a>", html(ast))
end

@testitem "link destination rejects unbalanced parens" tags = [:core] begin
    using CommonMark
    using Test
    p = Parser()

    # An unparenthesised destination with an unbalanced '(' is not a valid link.
    ast = p("[a](b(c )\n")
    @test !occursin("<a href", html(ast))
    @test occursin("[a](b(c )", html(ast))

    # Control: balanced parens still form a link.
    ast = p("[a](b(c) )\n")
    @test occursin("<a href=\"b(c)\">a</a>", html(ast))
end

@testitem "link label length boundary" tags = [:core] begin
    using CommonMark
    using Test
    p = Parser()

    # The spec allows up to 999 characters inside the brackets.
    label999 = repeat("a", 999)
    ast = p("[$label999]\n\n[$label999]: /url\n")
    @test occursin("<a href=\"/url\">", html(ast))

    # 1000 characters exceeds the limit and must not resolve.
    label1000 = repeat("a", 1000)
    ast = p("[$label1000]\n\n[$label1000]: /url\n")
    @test !occursin("<a href", html(ast))
end

@testitem "numeric entity validity" tags = [:core] begin
    using CommonMark
    using Test
    p = Parser()
    decode(s) = p(s).first_child.first_child.literal

    # Surrogate and out-of-range codepoints must decode to U+FFFD.
    @test decode("&#xD800;") == "�"
    @test decode("&#1114112;") == "�"

    # Control: valid codepoints decode normally.
    @test decode("&#65;") == "A"
    @test decode("&#x10FFFF;") == "\U10FFFF"
end

@testitem "inline_handler_preconditions" tags = [:core] begin
    using CommonMark
    using Test

    # Dispatch-entry handlers rely on a non-local guarantee: the inline parser
    # peeks the trigger char before calling the handler. The handler must fail
    # fast if that precondition is violated, not silently consume the wrong char.
    inline_at = function (s)
        p = CommonMark.InlineParser()
        p.buf = s
        p.pos = 1
        p.len = ncodeunits(s)
        return p
    end
    block = CommonMark.Node(CommonMark.Document())

    @test_throws ErrorException CommonMark.parse_backslash(inline_at("x"), block)
    @test_throws ErrorException CommonMark.parse_newline(inline_at("x"), block)
    @test_throws ErrorException CommonMark.parse_open_bracket(inline_at("x"), block)
end

@testitem "line end whitespace is read from the source" tags = [:core] begin
    using CommonMark
    using Test

    p = Parser()

    # Whitespace written before a line end is dropped, and a pair of spaces
    # there is a hard break instead. Both are decided from the source text.
    @test html(p("foo \nbar")) == "<p>foo\nbar</p>\n"
    @test html(p("foo \t\nbar")) == "<p>foo\nbar</p>\n"
    @test html(p("foo\t \nbar")) == "<p>foo\nbar</p>\n"
    @test html(p("foo  \nbar")) == "<p>foo<br />\nbar</p>\n"

    # An entity decodes to content, so its whitespace is neither dropped nor
    # read as a hard break.
    @test html(p("foo&#32;\nbar")) == "<p>foo \nbar</p>\n"
    @test html(p("foo&#32;&#32;\nbar")) == "<p>foo  \nbar</p>\n"
    @test html(p("foo &#32;\nbar")) == "<p>foo  \nbar</p>\n"
    @test html(p("foo&#32; \nbar")) == "<p>foo \nbar</p>\n"
end
