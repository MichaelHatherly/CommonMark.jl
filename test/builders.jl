@testitem "node_builders_core" tags = [:core] begin
    using CommonMark
    using Test

    # Test core block builders
    @testset "Document" begin
        doc = CommonMark.Node(
            CommonMark.Document,
            CommonMark.Node(
                CommonMark.Paragraph,
                "Hello ",
                CommonMark.Node(CommonMark.Strong, "world"),
                "!",
            ),
        )
        @test doc.t isa CommonMark.Document
        @test doc.first_child.t isa CommonMark.Paragraph
        @test html(doc) == "<p>Hello <strong>world</strong>!</p>\n"
    end

    @testset "Paragraph" begin
        p = CommonMark.Node(CommonMark.Paragraph, "Hello")
        @test p.t isa CommonMark.Paragraph
        @test p.first_child.t isa CommonMark.Text
        @test p.first_child.literal == "Hello"
    end

    @testset "Heading" begin
        h = CommonMark.Node(CommonMark.Heading, 1, "Title")
        @test h.t isa CommonMark.Heading
        @test h.t.level == 1
        @test h.first_child.literal == "Title"

        h2 = CommonMark.Node(
            CommonMark.Heading,
            3,
            CommonMark.Node(CommonMark.Emph, "italic title"),
        )
        @test h2.t.level == 3
        @test h2.first_child.t isa CommonMark.Emph
    end

    @testset "BlockQuote" begin
        bq = CommonMark.Node(
            CommonMark.BlockQuote,
            CommonMark.Node(CommonMark.Paragraph, "quoted text"),
        )
        @test bq.t isa CommonMark.BlockQuote
        @test bq.first_child.t isa CommonMark.Paragraph
    end

    @testset "List and Item" begin
        list = CommonMark.Node(
            CommonMark.List,
            CommonMark.Node(
                CommonMark.Item,
                CommonMark.Node(CommonMark.Paragraph, "First"),
            ),
            CommonMark.Node(
                CommonMark.Item,
                CommonMark.Node(CommonMark.Paragraph, "Second"),
            ),
        )
        @test list.t isa CommonMark.List
        @test list.t.list_data.type == :bullet
        @test list.first_child.t isa CommonMark.Item
        @test list.first_child.nxt.t isa CommonMark.Item

        ordered = CommonMark.Node(
            CommonMark.List,
            CommonMark.Node(CommonMark.Item, CommonMark.Node(CommonMark.Paragraph, "One")),
            CommonMark.Node(CommonMark.Item, CommonMark.Node(CommonMark.Paragraph, "Two"));
            ordered = true,
            start = 5,
        )
        @test ordered.t.list_data.type == :ordered
        @test ordered.t.list_data.start == 5
    end

    @testset "CodeBlock" begin
        cb = CommonMark.Node(CommonMark.CodeBlock, "println(\"hello\")")
        @test cb.t isa CommonMark.CodeBlock
        @test cb.literal == "println(\"hello\")"

        cb_lang = CommonMark.Node(CommonMark.CodeBlock, "x = 1"; info = "julia")
        @test cb_lang.t.info == "julia"
    end

    @testset "ThematicBreak" begin
        tb = CommonMark.Node(CommonMark.ThematicBreak)
        @test tb.t isa CommonMark.ThematicBreak
    end

    @testset "HtmlBlock" begin
        hb = CommonMark.Node(CommonMark.HtmlBlock, "<div>content</div>")
        @test hb.t isa CommonMark.HtmlBlock
        @test hb.literal == "<div>content</div>"
    end

    # Test core inline builders
    @testset "Emph and Strong" begin
        em = CommonMark.Node(CommonMark.Emph, "italic")
        @test em.t isa CommonMark.Emph
        @test em.first_child.literal == "italic"

        strong = CommonMark.Node(CommonMark.Strong, "bold")
        @test strong.t isa CommonMark.Strong

        nested = CommonMark.Node(
            CommonMark.Strong,
            "bold and ",
            CommonMark.Node(CommonMark.Emph, "italic"),
        )
        @test nested.first_child.t isa CommonMark.Text
        @test nested.first_child.nxt.t isa CommonMark.Emph
    end

    @testset "Code" begin
        c = CommonMark.Node(CommonMark.Code, "inline code")
        @test c.t isa CommonMark.Code
        @test c.literal == "inline code"
    end

    @testset "Link" begin
        link = CommonMark.Node(CommonMark.Link, "click here"; dest = "https://example.com")
        @test link.t isa CommonMark.Link
        @test link.t.destination == "https://example.com"
        @test link.first_child.literal == "click here"

        link_title =
            CommonMark.Node(CommonMark.Link, "text"; dest = "url", title = "hover text")
        @test link_title.t.title == "hover text"
    end

    @testset "Image" begin
        img = CommonMark.Node(CommonMark.Image; dest = "image.png", alt = "alt text")
        @test img.t isa CommonMark.Image
        @test img.t.destination == "image.png"
        @test img.literal == "alt text"
    end

    @testset "SoftBreak and LineBreak" begin
        sb = CommonMark.Node(CommonMark.SoftBreak)
        @test sb.t isa CommonMark.SoftBreak

        lb = CommonMark.Node(CommonMark.LineBreak)
        @test lb.t isa CommonMark.LineBreak
    end

    # Test tree manipulation functions work
    @testset "Tree manipulation functions" begin
        parent = CommonMark.Node(CommonMark.Paragraph)
        child1 = CommonMark.text("first")
        child2 = CommonMark.text("second")

        CommonMark.append_child(parent, child1)
        @test parent.first_child === child1

        CommonMark.prepend_child(parent, child2)
        @test parent.first_child === child2

        @test !CommonMark.isnull(parent.first_child)
        @test CommonMark.isnull(parent.parent)

        CommonMark.unlink(child2)
        @test parent.first_child === child1
    end
end

@testitem "node_builders_extensions" tags = [:extensions] begin
    using CommonMark
    using Test

    @testset "Math" begin
        m = CommonMark.Node(CommonMark.Math, "E = mc^2")
        @test m.t isa CommonMark.Math
        @test m.literal == "E = mc^2"
    end

    @testset "DisplayMath" begin
        dm = CommonMark.Node(CommonMark.DisplayMath, "\\int_0^1 x dx")
        @test dm.t isa CommonMark.DisplayMath
        @test dm.literal == "\\int_0^1 x dx"
    end

    @testset "Strikethrough" begin
        s = CommonMark.Node(CommonMark.Strikethrough, "deleted")
        @test s.t isa CommonMark.Strikethrough
        @test s.first_child.literal == "deleted"
    end

    @testset "Subscript" begin
        sub = CommonMark.Node(CommonMark.Subscript, "2")
        @test sub.t isa CommonMark.Subscript
    end

    @testset "Superscript" begin
        sup = CommonMark.Node(CommonMark.Superscript, "2")
        @test sup.t isa CommonMark.Superscript
    end

    @testset "Admonition" begin
        adm = CommonMark.Node(
            CommonMark.Admonition,
            "note",
            "Note Title",
            CommonMark.Node(CommonMark.Paragraph, "Admonition content"),
        )
        @test adm.t isa CommonMark.Admonition
        @test adm.t.category == "note"
        @test adm.t.title == "Note Title"
    end

    @testset "FencedDiv" begin
        div = CommonMark.Node(
            CommonMark.FencedDiv,
            CommonMark.Node(CommonMark.Paragraph, "content");
            class = "warning",
        )
        @test div.t isa CommonMark.FencedDiv
        @test div.meta["class"] == ["warning"]

        div_id = CommonMark.Node(
            CommonMark.FencedDiv,
            CommonMark.Node(CommonMark.Paragraph, "text");
            class = ["a", "b"],
            id = "myid",
        )
        @test div_id.meta["id"] == "myid"
        @test div_id.meta["class"] == ["a", "b"]
    end

    @testset "FootnoteDefinition" begin
        fn = CommonMark.Node(
            CommonMark.FootnoteDefinition,
            "1",
            CommonMark.Node(CommonMark.Paragraph, "footnote text"),
        )
        @test fn.t isa CommonMark.FootnoteDefinition
        @test fn.t.id == "1"
    end

    @testset "Table components" begin
        cell = CommonMark.Node(
            CommonMark.TableCell,
            "data";
            align = :right,
            header = true,
            column = 2,
        )
        @test cell.t isa CommonMark.TableCell
        @test cell.t.align == :right
        @test cell.t.header == true
        @test cell.t.column == 2

        row = CommonMark.Node(
            CommonMark.TableRow,
            CommonMark.Node(CommonMark.TableCell, "A"),
            CommonMark.Node(CommonMark.TableCell, "B"),
        )
        @test row.t isa CommonMark.TableRow

        header = CommonMark.Node(CommonMark.TableHeader, row)
        @test header.t isa CommonMark.TableHeader

        body = CommonMark.Node(
            CommonMark.TableBody,
            CommonMark.Node(
                CommonMark.TableRow,
                CommonMark.Node(CommonMark.TableCell, "1"),
                CommonMark.Node(CommonMark.TableCell, "2"),
            ),
        )
        @test body.t isa CommonMark.TableBody
    end

    @testset "Raw content" begin
        latex_inline = CommonMark.Node(CommonMark.LaTeXInline, "\\textbf{bold}")
        @test latex_inline.t isa CommonMark.LaTeXInline
        @test latex_inline.literal == "\\textbf{bold}"

        latex_block =
            CommonMark.Node(CommonMark.LaTeXBlock, "\\begin{equation}x\\end{equation}")
        @test latex_block.t isa CommonMark.LaTeXBlock

        typst_inline = CommonMark.Node(CommonMark.TypstInline, "#strong[bold]")
        @test typst_inline.t isa CommonMark.TypstInline

        typst_block = CommonMark.Node(CommonMark.TypstBlock, "#figure[]")
        @test typst_block.t isa CommonMark.TypstBlock
    end

    @testset "HtmlInline" begin
        hi = CommonMark.Node(CommonMark.HtmlInline, "<span class=\"hl\">")
        @test hi.t isa CommonMark.HtmlInline
        @test hi.literal == "<span class=\"hl\">"
    end

    @testset "GitHubAlert" begin
        alert = CommonMark.Node(
            CommonMark.GitHubAlert,
            "warning",
            CommonMark.Node(CommonMark.Paragraph, "Be careful!"),
        )
        @test alert.t isa CommonMark.GitHubAlert
        @test alert.t.category == "warning"
        @test alert.t.title == "Warning"

        # Custom title
        alert2 = CommonMark.Node(
            CommonMark.GitHubAlert,
            "note",
            CommonMark.Node(CommonMark.Paragraph, "Info");
            title = "Custom Title",
        )
        @test alert2.t.title == "Custom Title"
    end

    @testset "TaskItem" begin
        task = CommonMark.Node(
            CommonMark.TaskItem,
            CommonMark.Node(CommonMark.Paragraph, "Do this"),
        )
        @test task.t isa CommonMark.TaskItem
        @test task.t.checked == false

        checked = CommonMark.Node(
            CommonMark.TaskItem,
            CommonMark.Node(CommonMark.Paragraph, "Done");
            checked = true,
        )
        @test checked.t.checked == true

        # TaskItem in List gets list_data propagated
        tasklist = CommonMark.Node(
            CommonMark.List,
            CommonMark.Node(
                CommonMark.TaskItem,
                CommonMark.Node(CommonMark.Paragraph, "Task 1"),
            ),
            CommonMark.Node(
                CommonMark.TaskItem,
                CommonMark.Node(CommonMark.Paragraph, "Task 2");
                checked = true,
            );
            ordered = true,
        )
        @test tasklist.first_child.t.list_data.type == :ordered
        @test tasklist.first_child.nxt.t.list_data.type == :ordered
    end

    @testset "FootnoteLink" begin
        # FootnoteLink with Document healing
        doc = CommonMark.Node(
            CommonMark.Document,
            CommonMark.Node(
                CommonMark.Paragraph,
                "See note",
                CommonMark.Node(CommonMark.FootnoteLink, "1"),
                ".",
            ),
            CommonMark.Node(
                CommonMark.FootnoteDefinition,
                "1",
                CommonMark.Node(CommonMark.Paragraph, "Footnote content."),
            ),
        )
        # Find the FootnoteLink
        link = doc.first_child.first_child.nxt
        @test link.t isa CommonMark.FootnoteLink
        @test link.t.id == "1"
        # Check that healing worked - rule cache should have the definition
        @test haskey(link.t.rule.cache, "1")
        @test link.t.rule.cache["1"].t isa CommonMark.FootnoteDefinition
    end

    @testset "Citation" begin
        cite = CommonMark.Node(CommonMark.Citation, "smith2020")
        @test cite.t isa CommonMark.Citation
        @test cite.t.id == "smith2020"
        @test cite.t.brackets == false
        @test cite.literal == "@smith2020"

        bracketed = CommonMark.Node(CommonMark.Citation, "jones2021"; brackets = true)
        @test bracketed.t.brackets == true
    end
end

@testitem "node_builders_html_output" tags = [:core] begin
    using CommonMark
    using Test

    # Test building complete documents and rendering
    @testset "Complete document rendering" begin
        doc = CommonMark.Node(
            CommonMark.Document,
            CommonMark.Node(CommonMark.Heading, 1, "Hello World"),
            CommonMark.Node(
                CommonMark.Paragraph,
                "Welcome to ",
                CommonMark.Node(CommonMark.Strong, "CommonMark"),
                "!",
            ),
            CommonMark.Node(
                CommonMark.List,
                CommonMark.Node(
                    CommonMark.Item,
                    CommonMark.Node(CommonMark.Paragraph, "First item"),
                ),
                CommonMark.Node(
                    CommonMark.Item,
                    CommonMark.Node(CommonMark.Paragraph, "Second item"),
                ),
            ),
        )

        result = html(doc)
        @test occursin("<h1>Hello World</h1>", result)
        @test occursin("<strong>CommonMark</strong>", result)
        @test occursin("<ul>", result)
        @test occursin("<li>", result)
    end

    @testset "Links in paragraphs" begin
        p = CommonMark.Node(
            CommonMark.Paragraph,
            "Click ",
            CommonMark.Node(
                CommonMark.Link,
                CommonMark.Node(CommonMark.Strong, "here");
                dest = "https://example.com",
            ),
            " to continue.",
        )
        doc = CommonMark.Node(CommonMark.Document, p)
        result = html(doc)
        @test occursin("<a href=\"https://example.com\"><strong>here</strong></a>", result)
    end

    @testset "Code blocks" begin
        doc = CommonMark.Node(
            CommonMark.Document,
            CommonMark.Node(
                CommonMark.CodeBlock,
                "function foo()\n    return 42\nend";
                info = "julia",
            ),
        )
        result = html(doc)
        @test occursin("<pre><code class=\"language-julia\">", result)
    end
end
