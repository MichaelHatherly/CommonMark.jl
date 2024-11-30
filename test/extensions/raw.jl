@testset "Raw Content" begin
    p = Parser()
    enable!(p, RawContentRule())

    text = "`html`{=html}`latex`{=latex}`typst`{=typst}"
    ast = p(text)

    @test html(ast) == "<p>html</p>\n"
    @test latex(ast) == "latex\\par\n"
    @test term(ast) == " \e[90mhtml\e[39m\e[90mlatex\e[39m\e[90mtypst\e[39m\n"
    @test markdown(ast) == "html`latex`{=latex}`typst`{=typst}\n" # TODO: should we pass through a literal instead for html?

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

    @test html(ast) == "<div id=\"main\">\n <div class=\"article\">\n"
    @test latex(ast) == "\\begin{tikzpicture}\n...\n\\end{tikzpicture}\n"
    @test term(ast) ==
          " \e[90m<div id=\"main\">\e[39m\n \e[90m <div class=\"article\">\e[39m\n \n \e[90m\\begin{tikzpicture}\e[39m\n \e[90m...\e[39m\n \e[90m\\end{tikzpicture}\e[39m\n \n \e[90m#let name = \"Typst\"\e[39m\n"
    @test markdown(ast) ==
          "<div id=\"main\">\n <div class=\"article\">\n\n```{=latex}\n\\begin{tikzpicture}\n...\n\\end{tikzpicture}\n```\n\n```{=typst}\n#let name = \"Typst\"\n```\n"

    p = Parser()
    enable!(p, RawContentRule(text_inline = CommonMark.Text))

    text = "`**not bold**`{=text}"
    ast = p(text)

    @test html(ast) == "<p>**not bold**</p>\n"
    @test latex(ast) == "**not bold**\\par\n"
    @test term(ast) == " **not bold**\n"
    @test markdown(ast) == "**not bold**\n" # TODO: pass through raw content.
end
