@testitem "tasklist" tags = [:extensions, :tasklist] setup = [Utilities] begin
    using CommonMark
    using Test

    p = create_parser(TaskListRule())

    # Basic unchecked task
    @test html(p("- [ ] unchecked")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> unchecked</li>\n</ul>\n"

    # Basic checked task
    @test html(p("- [x] checked")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled checked> checked</li>\n</ul>\n"

    # Uppercase X also works
    @test html(p("- [X] also checked")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled checked> also checked</li>\n</ul>\n"

    # Multiple tasks
    @test html(p("- [ ] first\n- [x] second\n- [ ] third")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> first</li>\n<li><input type=\"checkbox\" disabled checked> second</li>\n<li><input type=\"checkbox\" disabled> third</li>\n</ul>\n"

    # Mixed with regular items (no checkbox pattern)
    @test html(p("- regular item\n- [ ] task item")) ==
          "<ul>\n<li>regular item</li>\n<li><input type=\"checkbox\" disabled> task item</li>\n</ul>\n"

    # Ordered list with tasks
    @test html(p("1. [ ] first task\n2. [x] second task")) ==
          "<ol>\n<li><input type=\"checkbox\" disabled> first task</li>\n<li><input type=\"checkbox\" disabled checked> second task</li>\n</ol>\n"

    # Without extension, checkbox pattern is literal text
    p_no_ext = create_parser()
    @test html(p_no_ext("- [ ] task")) == "<ul>\n<li>[ ] task</li>\n</ul>\n"

    # Task with inline formatting
    @test html(p("- [ ] **bold** task")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> <strong>bold</strong> task</li>\n</ul>\n"

    # No space after checkbox is also valid
    @test html(p("- [ ]no space")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> no space</li>\n</ul>\n"

    # Terminal rendering
    @test term(p("- [ ] unchecked")) == "  ☐ unchecked\n"
    @test term(p("- [x] checked")) == "  ☑ checked\n"

    # Markdown roundtrip preserves checkbox
    @test markdown(p("- [ ] unchecked\n- [x] checked")) ==
          "- [ ] unchecked\n- [x] checked\n"

    # Edge cases

    # Empty brackets (no space) is not a task
    @test html(p("- [] text")) == "<ul>\n<li>[] text</li>\n</ul>\n"

    # Empty task (nothing after checkbox)
    @test html(p("- [ ]")) == "<ul>\n<li><input type=\"checkbox\" disabled> </li>\n</ul>\n"

    # Nested list with task
    @test html(p("- parent\n  - [ ] child task")) ==
          "<ul>\n<li>parent\n<ul>\n<li><input type=\"checkbox\" disabled> child task</li>\n</ul>\n</li>\n</ul>\n"

    # Different bullet characters
    @test html(p("+ [ ] plus")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> plus</li>\n</ul>\n"
    @test html(p("* [ ] star")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> star</li>\n</ul>\n"

    # Task in blockquote
    @test html(p("> - [ ] quoted task")) ==
          "<blockquote>\n<ul>\n<li><input type=\"checkbox\" disabled> quoted task</li>\n</ul>\n</blockquote>\n"

    # Task with link
    @test html(p("- [ ] [link](url)")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> <a href=\"url\">link</a></li>\n</ul>\n"

    # Task with code
    @test html(p("- [ ] `code`")) ==
          "<ul>\n<li><input type=\"checkbox\" disabled> <code>code</code></li>\n</ul>\n"
end
