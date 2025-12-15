@testitem "strikethrough" tags = [:extensions, :strikethrough] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(StrikethroughRule())

    # Basic strikethrough
    @test html(p("~~word~~")) == "<p><del>word</del></p>\n"
    @test html(p("~~multiple words~~")) == "<p><del>multiple words</del></p>\n"

    # Strikethrough with punctuation
    @test html(p("~~word!~~")) == "<p><del>word!</del></p>\n"

    # Nested with emphasis
    @test html(p("~~**bold**~~")) == "<p><del><strong>bold</strong></del></p>\n"
    @test html(p("~~*italic*~~")) == "<p><del><em>italic</em></del></p>\n"
    @test html(p("*~~italic strikethrough~~*")) ==
          "<p><em><del>italic strikethrough</del></em></p>\n"
    @test html(p("**~~bold strikethrough~~**")) ==
          "<p><strong><del>bold strikethrough</del></strong></p>\n"

    # Single tilde - not strikethrough
    @test html(p("~word~")) == "<p>~word~</p>\n"

    # Unclosed strikethrough
    @test html(p("~~unclosed")) == "<p>~~unclosed</p>\n"

    # Four tildes is a fenced code block, not strikethrough
    # @test html(p("~~~~")) - this starts a code block

    # Adjacent strikethroughs
    @test html(p("~~first~~~~second~~")) == "<p><del>first</del><del>second</del></p>\n"

    # Whitespace handling - tildes with space after opening
    @test html(p("~~ spaced ~~")) == "<p>~~ spaced ~~</p>\n"

    # In code span - not struck
    @test html(p("`~~code~~`")) == "<p><code>~~code~~</code></p>\n"

    # Escaped
    @test html(p("\\~~escaped\\~~")) == "<p>~~escaped~~</p>\n"

    # Multiple in paragraph
    @test html(p("~~first~~ and ~~second~~")) ==
          "<p><del>first</del> and <del>second</del></p>\n"

    # Three tildes at start of line is a fenced code block, not inline strikethrough
    # Test inline three tildes with surrounding text instead
    @test html(p("a~~~b~~~c")) == "<p>a~<del>b</del>~c</p>\n"
end
