@testitem "subscript" tags = [:extensions, :subscript] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(SubscriptRule())

    # Basic subscript
    @test html(p("~word~")) == "<p><sub>word</sub></p>\n"
    @test html(p("~multiple words~")) == "<p><sub>multiple words</sub></p>\n"

    # Nested with emphasis
    @test html(p("~**bold**~")) == "<p><sub><strong>bold</strong></sub></p>\n"
    @test html(p("~*italic*~")) == "<p><sub><em>italic</em></sub></p>\n"
    @test html(p("*~italic subscript~*")) == "<p><em><sub>italic subscript</sub></em></p>\n"

    # Unclosed subscript
    @test html(p("~unclosed")) == "<p>~unclosed</p>\n"

    # Adjacent subscripts
    @test html(p("~first~~second~")) == "<p><sub>first</sub><sub>second</sub></p>\n"

    # Whitespace handling - tilde with space after opening
    @test html(p("~ spaced ~")) == "<p>~ spaced ~</p>\n"

    # In code span - not subscripted
    @test html(p("`~code~`")) == "<p><code>~code~</code></p>\n"

    # Escaped
    @test html(p("\\~escaped\\~")) == "<p>~escaped~</p>\n"

    # Multiple in paragraph
    @test html(p("~first~ and ~second~")) ==
          "<p><sub>first</sub> and <sub>second</sub></p>\n"

    # Combined with strikethrough (if both enabled)
    p2 = create_parser([SubscriptRule(), StrikethroughRule()])
    @test html(p2("~sub~ and ~~strike~~")) ==
          "<p><sub>sub</sub> and <del>strike</del></p>\n"
    @test html(p2("~~struck ~sub~ text~~")) ==
          "<p><del>struck <sub>sub</sub> text</del></p>\n"

    # Permissive flanking allows punctuation after opener
    @test html(p("x~-1~")) == "<p>x<sub>-1</sub></p>\n"
    @test html(p("a~+b~")) == "<p>a<sub>+b</sub></p>\n"

    # Terminal rendering uses Unicode subscript characters
    @test term(p("H~2~O")) == " H₂O\n"
    @test term(p("CO~2~")) == " CO₂\n"
    @test term(p("x~0~ + x~1~")) == " x₀ + x₁\n"
    # Letters with Unicode subscript equivalents
    @test term(p("a~n~")) == " aₙ\n"
    # Letters without Unicode equivalents fall back to original
    @test term(p("~abc~")) == " ₐbc\n"
end
