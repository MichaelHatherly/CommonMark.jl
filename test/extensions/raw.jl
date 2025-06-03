@testitem "raw_content" tags = [:extensions, :raw] begin
    using CommonMark
    using Test
    using ReferenceTests

    # Helper function for tests that can use references
    function test_raw(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/raw/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    p = Parser()
    enable!(p, RawContentRule())

    # Inline raw content
    text = "`html`{=html}`latex`{=latex}`typst`{=typst}"
    ast = p(text)
    test_raw("inline_raw", ast)

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
    test_raw("block_raw", ast)

    # Raw content with text inline
    p = Parser()
    enable!(p, RawContentRule(text_inline = CommonMark.Text))

    text = "`**not bold**`{=text}"
    ast = p(text)
    test_raw("text_inline_raw", ast)
end
