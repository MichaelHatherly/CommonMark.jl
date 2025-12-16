@testitem "fenceddivs" tags = [:extensions, :fenceddivs] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(FencedDivRule())
    test_div = test_all_formats(pwd())

    # Basic div with bare word class
    @test html(p("::: warning\nContent\n:::")) ==
          "<div class=\"warning\">\n<p>Content</p>\n</div>\n"

    # Div with full attribute syntax
    @test html(p("::: {#myid .note}\nContent\n:::")) ==
          "<div class=\"note\" id=\"myid\">\n<p>Content</p>\n</div>\n"

    # Multiple classes
    @test html(p("::: {.note .important}\nContent\n:::")) ==
          "<div class=\"note important\">\n<p>Content</p>\n</div>\n"

    # Bare word with multiple classes
    @test html(p("::: warning important\nContent\n:::")) ==
          "<div class=\"warning important\">\n<p>Content</p>\n</div>\n"

    # Key-value attribute
    @test html(p("::: {.note data-info=\"test\"}\nContent\n:::")) ==
          "<div class=\"note\" data-info=\"test\">\n<p>Content</p>\n</div>\n"

    # Nested divs
    @test html(p("::: outer\nBefore\n::: inner\nNested\n:::\nAfter\n:::")) ==
          "<div class=\"outer\">\n<p>Before</p>\n<div class=\"inner\">\n<p>Nested</p>\n</div>\n<p>After</p>\n</div>\n"

    # Longer fence for nesting clarity
    @test html(p(":::: outer\nBefore\n::: inner\nNested\n:::\nAfter\n::::")) ==
          "<div class=\"outer\">\n<p>Before</p>\n<div class=\"inner\">\n<p>Nested</p>\n</div>\n<p>After</p>\n</div>\n"

    # Closing fence must match or exceed opening length
    @test html(p(":::: warning\nContent\n::::")) ==
          "<div class=\"warning\">\n<p>Content</p>\n</div>\n"

    # Multi-paragraph content
    @test html(p("::: note\nPara 1\n\nPara 2\n:::")) ==
          "<div class=\"note\">\n<p>Para 1</p>\n<p>Para 2</p>\n</div>\n"

    # Div with code block inside
    @test html(p("::: example\n```\ncode\n```\n:::")) ==
          "<div class=\"example\">\n<pre><code>code\n</code></pre>\n</div>\n"

    # Div with blockquote inside
    @test html(p("::: note\n> quoted\n:::")) ==
          "<div class=\"note\">\n<blockquote>\n<p>quoted</p>\n</blockquote>\n</div>\n"

    # Bare colons without attributes = not a div
    @test html(p(":::\nContent\n:::")) == "<p>:::\nContent\n:::</p>\n"

    # Not enough colons = not a div
    @test html(p(":: warning\nContent\n::")) == "<p>:: warning\nContent\n::</p>\n"

    # Terminal output includes class name
    @test occursin("warning", term(p("::: warning\nContent\n:::")))
    @test occursin("Content", term(p("::: warning\nContent\n:::")))

    # Markdown roundtrip - bare word
    @test markdown(p("::: warning\nContent\n:::")) == "::: warning\nContent\n:::\n"

    # Markdown roundtrip - full attributes
    @test markdown(p("::: {#myid .note}\nContent\n:::")) ==
          "::: {#myid .note}\nContent\n:::\n"

    # Markdown roundtrip - nested (paragraphs get blank line separation)
    @test markdown(p("::: outer\nBefore\n::: inner\nNested\n:::\nAfter\n:::")) ==
          "::: outer\nBefore\n\n::: inner\nNested\n:::\n\nAfter\n:::\n"

    # Reference tests
    test_div("basic_warning", p("::: warning\nThis is a warning.\n:::"), "fenceddivs")

    test_div(
        "with_id_class",
        p("::: {#important .note .highlight}\nStyled content.\n:::"),
        "fenceddivs",
    )

    test_div("nested", p("""
        ::: outer
        Outer content.

        ::: inner
        Inner content.
        :::

        More outer.
        :::
        """), "fenceddivs")

    test_div("with_code", p("""
        ::: example
        Here is some code:

        ```julia
        println("Hello")
        ```
        :::
        """), "fenceddivs")

    test_div(
        "multiclass",
        p("::: warning important urgent\nUrgent warning!\n:::"),
        "fenceddivs",
    )
end
