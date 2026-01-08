@testitem "delimiter interactions" tags = [:extensions, :interactions] setup = [Utilities] begin
    using CommonMark
    using Test

    # Parser with all delimiter-based extensions
    p = create_parser([StrikethroughRule(), SubscriptRule(), SuperscriptRule(), MarkRule()])

    # ==========================================
    # Strikethrough containing subscript (the bug case)
    # ==========================================
    @test html(p("~~H~3~O~~")) == "<p><del>H<sub>3</sub>O</del></p>\n"
    @test html(p("~~a~b~c~~")) == "<p><del>a<sub>b</sub>c</del></p>\n"
    # Multiple subscripts need proper spacing to avoid ambiguity
    @test html(p("~~x ~1~ ~2~ y~~")) == "<p><del>x <sub>1</sub> <sub>2</sub> y</del></p>\n"

    # ==========================================
    # Strikethrough containing superscript
    # ==========================================
    @test html(p("~~E=mc^2^~~")) == "<p><del>E=mc<sup>2</sup></del></p>\n"
    @test html(p("~~x^n^+y^m^~~")) == "<p><del>x<sup>n</sup>+y<sup>m</sup></del></p>\n"

    # ==========================================
    # Mixed sub/super inside strikethrough
    # ==========================================
    @test html(p("~~H~2~O^+^~~")) == "<p><del>H<sub>2</sub>O<sup>+</sup></del></p>\n"

    # ==========================================
    # Subscript/superscript with emphasis
    # ==========================================
    @test html(p("~*italic sub*~")) == "<p><sub><em>italic sub</em></sub></p>\n"
    @test html(p("^**bold super**^")) == "<p><sup><strong>bold super</strong></sup></p>\n"
    @test html(p("*~sub in italic~*")) == "<p><em><sub>sub in italic</sub></em></p>\n"
    @test html(p("**^super in bold^**")) ==
          "<p><strong><sup>super in bold</sup></strong></p>\n"

    # ==========================================
    # Three-level nesting
    # ==========================================
    @test html(p("~~*~nested~*~~")) == "<p><del><em><sub>nested</sub></em></del></p>\n"
    @test html(p("*~~^deep^~~*")) == "<p><em><del><sup>deep</sup></del></em></p>\n"

    # ==========================================
    # Adjacent different delimiter types
    # ==========================================
    # Adjacent subscripts need explicit closing/opening
    @test html(p("~sub~~strike~")) == "<p><sub>sub~~strike</sub></p>\n"
    @test html(p("~sub~ ~strike~")) == "<p><sub>sub</sub> <sub>strike</sub></p>\n"
    @test html(p("~~strike~~^super^")) == "<p><del>strike</del><sup>super</sup></p>\n"
    @test html(p("^super^~sub~")) == "<p><sup>super</sup><sub>sub</sub></p>\n"

    # ==========================================
    # Delimiter counts must match exactly for extensions
    # ==========================================
    # Single ~ shouldn't close ~~
    @test html(p("~~open~close")) == "<p>~~open~close</p>\n"
    # Double ~ shouldn't close single ~
    @test html(p("~open~~close")) == "<p>~open~~close</p>\n"

    # ==========================================
    # Standard emphasis still allows partial matching
    # ==========================================
    @test html(p("***bold italic***")) == "<p><em><strong>bold italic</strong></em></p>\n"
    @test html(p("**_bold italic_**")) == "<p><strong><em>bold italic</em></strong></p>\n"

    # ==========================================
    # Mark containing other delimiters
    # ==========================================
    @test html(p("==H~2~O==")) == "<p><mark>H<sub>2</sub>O</mark></p>\n"
    @test html(p("==x^2^==")) == "<p><mark>x<sup>2</sup></mark></p>\n"
    @test html(p("==~~struck~~==")) == "<p><mark><del>struck</del></mark></p>\n"

    # ==========================================
    # Mark inside other delimiters
    # ==========================================
    @test html(p("~~==marked==~~")) == "<p><del><mark>marked</mark></del></p>\n"
    @test html(p("*==italic mark==*")) == "<p><em><mark>italic mark</mark></em></p>\n"

    # ==========================================
    # Adjacent marks with other delimiters
    # ==========================================
    @test html(p("==mark==~~strike~~")) == "<p><mark>mark</mark><del>strike</del></p>\n"
end
