@testitem "raw_content" tags = [:extensions, :raw] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_raw = test_all_formats(pwd())

    p = create_parser(RawContentRule())

    # Inline raw content
    text = "`html`{=html}`latex`{=latex}`typst`{=typst}"
    ast = p(text)
    test_raw("inline_raw", ast, "raw")

    # Block raw content
    text = """
    ```{=html}
    <div id="main">
     <div class="article">
    ```
    ```{=latex}
    \\begin{tikzpicture}
    ...
    \\end{tikzpicture}
    ```
    ```{=typst}
    #let name = "Typst"
    ```
    """
    ast = p(text)
    test_raw("block_raw", ast, "raw")

    # Raw content with text inline
    p = create_parser(RawContentRule(text_inline = CommonMark.Text))

    text = "`**not bold**`{=text}"
    ast = p(text)
    test_raw("text_inline_raw", ast, "raw")
end

@testitem "raw_content roundtrip" tags = [:extensions, :raw] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(RawContentRule())

    # A format tag the parse left as text after a code span keeps its meaning on
    # a reparse.
    @test Utilities.faithful(p, "`x`&#123;=html&#125;\n")
    @test markdown(p("`x`&#123;=html&#125;\n")) == "`x`\\{=html}\n"
end
