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
