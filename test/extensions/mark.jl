@testitem "mark" tags = [:extensions, :mark] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(MarkRule())

    # Basic mark
    @test html(p("==word==")) == "<p><mark>word</mark></p>\n"
    @test html(p("==multiple words==")) == "<p><mark>multiple words</mark></p>\n"

    # Mark with punctuation
    @test html(p("==word!==")) == "<p><mark>word!</mark></p>\n"

    # Nested with emphasis
    @test html(p("==**bold**==")) == "<p><mark><strong>bold</strong></mark></p>\n"
    @test html(p("==*italic*==")) == "<p><mark><em>italic</em></mark></p>\n"
    @test html(p("*==italic marked==*")) == "<p><em><mark>italic marked</mark></em></p>\n"
    @test html(p("**==bold marked==**")) ==
          "<p><strong><mark>bold marked</mark></strong></p>\n"

    # Single equals - not mark (common in assignments, comparisons)
    @test html(p("a = b")) == "<p>a = b</p>\n"
    @test html(p("x = y = z")) == "<p>x = y = z</p>\n"

    # Unclosed mark
    @test html(p("==unclosed")) == "<p>==unclosed</p>\n"

    # Empty mark (four equals)
    @test html(p("====")) == "<p>====</p>\n"

    # Adjacent marks
    @test html(p("==first====second==")) == "<p><mark>first</mark><mark>second</mark></p>\n"

    # Whitespace handling - equals with space after opening
    @test html(p("== spaced ==")) == "<p>== spaced ==</p>\n"

    # In code span - not marked
    @test html(p("`==code==`")) == "<p><code>==code==</code></p>\n"

    # Escaped
    @test html(p("\\==escaped\\==")) == "<p>==escaped==</p>\n"

    # Multiple in paragraph
    @test html(p("==first== and ==second==")) ==
          "<p><mark>first</mark> and <mark>second</mark></p>\n"

    # Three equals - middle one should be part of content
    @test html(p("a===b===c")) == "<p>a=<mark>b</mark>=c</p>\n"

    # Combined with other inline extensions
    p2 = create_parser([MarkRule(), StrikethroughRule()])
    @test html(p2("==mark== and ~~strike~~")) ==
          "<p><mark>mark</mark> and <del>strike</del></p>\n"
    @test html(p2("~~struck ==marked== text~~")) ==
          "<p><del>struck <mark>marked</mark> text</del></p>\n"

    # LaTeX output
    @test latex(p("==highlighted==")) == "\\hl{highlighted}\\par\n"

    # Typst output
    @test typst(p("==highlighted==")) == "#highlight[highlighted]\n"

    # Markdown roundtrip
    @test markdown(p("==highlighted==")) == "==highlighted==\n"
end
