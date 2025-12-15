@testitem "superscript" tags = [:extensions, :superscript] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(SuperscriptRule())

    # Basic superscript
    @test html(p("^word^")) == "<p><sup>word</sup></p>\n"
    @test html(p("^multiple words^")) == "<p><sup>multiple words</sup></p>\n"

    # Nested with emphasis
    @test html(p("^**bold**^")) == "<p><sup><strong>bold</strong></sup></p>\n"
    @test html(p("^*italic*^")) == "<p><sup><em>italic</em></sup></p>\n"
    @test html(p("*^italic superscript^*")) ==
          "<p><em><sup>italic superscript</sup></em></p>\n"

    # Unclosed superscript
    @test html(p("^unclosed")) == "<p>^unclosed</p>\n"

    # Adjacent superscripts
    @test html(p("^first^^second^")) == "<p><sup>first</sup><sup>second</sup></p>\n"

    # Whitespace handling - caret with space after opening
    @test html(p("^ spaced ^")) == "<p>^ spaced ^</p>\n"

    # In code span - not superscripted
    @test html(p("`^code^`")) == "<p><code>^code^</code></p>\n"

    # Escaped
    @test html(p("\\^escaped\\^")) == "<p>^escaped^</p>\n"

    # Multiple in paragraph
    @test html(p("^first^ and ^second^")) ==
          "<p><sup>first</sup> and <sup>second</sup></p>\n"

    # Combined with subscript
    p2 = create_parser([SubscriptRule(), SuperscriptRule()])
    @test html(p2("~sub~ and ^super^")) == "<p><sub>sub</sub> and <sup>super</sup></p>\n"
    @test html(p2("H~2~O and x^2^")) == "<p>H<sub>2</sub>O and x<sup>2</sup></p>\n"

    # Permissive flanking allows punctuation after opener
    @test html(p("10^-3^")) == "<p>10<sup>-3</sup></p>\n"
    @test html(p("OH^-^")) == "<p>OH<sup>-</sup></p>\n"
    @test html(p("Ca^2+^")) == "<p>Ca<sup>2+</sup></p>\n"

    # Terminal rendering uses Unicode superscript characters
    @test term(p("x^2^")) == " x²\n"
    @test term(p("10^9^")) == " 10⁹\n"
    @test term(p("E=mc^2^")) == " E=mc²\n"
    # Lowercase letters (all have Unicode superscript)
    @test term(p("x^n^")) == " xⁿ\n"
    @test term(p("e^x^")) == " eˣ\n"
    # Uppercase letters
    @test term(p("^ABC^")) == " ᴬᴮꟲ\n"
    # Combined sub and super
    @test term(p2("H~2~O x^2^")) == " H₂O x²\n"
    # Permissive flanking with Unicode
    @test term(p("10^-3^")) == " 10⁻³\n"
    @test term(p("L^-1^")) == " L⁻¹\n"
end
