@testitem "github_alerts" tags = [:extensions, :github_alerts] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(GitHubAlertRule())
    test_alert = test_all_formats(pwd())

    # Basic NOTE alert
    @test html(p("> [!NOTE]\n> Content here")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>Content here</p>\n</div>\n"

    # All 5 alert types
    @test html(p("> [!TIP]\n> Tip content")) ==
          "<div class=\"github-alert tip\"><p class=\"github-alert-title\">Tip</p>\n<p>Tip content</p>\n</div>\n"

    @test html(p("> [!IMPORTANT]\n> Important content")) ==
          "<div class=\"github-alert important\"><p class=\"github-alert-title\">Important</p>\n<p>Important content</p>\n</div>\n"

    @test html(p("> [!WARNING]\n> Warning content")) ==
          "<div class=\"github-alert warning\"><p class=\"github-alert-title\">Warning</p>\n<p>Warning content</p>\n</div>\n"

    @test html(p("> [!CAUTION]\n> Caution content")) ==
          "<div class=\"github-alert caution\"><p class=\"github-alert-title\">Caution</p>\n<p>Caution content</p>\n</div>\n"

    # Case insensitivity
    @test html(p("> [!note]\n> lowercase")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>lowercase</p>\n</div>\n"

    @test html(p("> [!Note]\n> mixed case")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>mixed case</p>\n</div>\n"

    # Multi-line content
    @test html(p("> [!NOTE]\n> Line 1\n> Line 2")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>Line 1\nLine 2</p>\n</div>\n"

    # Content with inline formatting
    @test html(p("> [!NOTE]\n> **bold** and *italic*")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p><strong>bold</strong> and <em>italic</em></p>\n</div>\n"

    # Regular blockquote unchanged
    p_no_ext = create_parser()
    @test html(p_no_ext("> [!NOTE]\n> Content")) ==
          "<blockquote>\n<p>[!NOTE]\nContent</p>\n</blockquote>\n"

    # Non-matching blockquote (not an alert type) unchanged
    @test html(p("> [!UNKNOWN]\n> Content")) ==
          "<blockquote>\n<p>[!UNKNOWN]\nContent</p>\n</blockquote>\n"

    # Regular blockquote unchanged
    @test html(p("> Regular quote")) ==
          "<blockquote>\n<p>Regular quote</p>\n</blockquote>\n"

    # Content on same line as marker
    @test html(p("> [!NOTE] Same line content")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>Same line content</p>\n</div>\n"

    # Alert with code block inside
    @test html(p("> [!NOTE]\n> ```\n> code\n> ```")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<pre><code>code\n</code></pre>\n</div>\n"

    # Alert with link
    @test html(p("> [!NOTE]\n> [link](url)")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p><a href=\"url\">link</a></p>\n</div>\n"

    # Terminal rendering
    @test occursin("Note", term(p("> [!NOTE]\n> Content")))
    @test occursin("Content", term(p("> [!NOTE]\n> Content")))

    # Markdown roundtrip preserves GitHub syntax
    @test markdown(p("> [!NOTE]\n> Content here")) == "> [!NOTE]\n> Content here\n"
    @test markdown(p("> [!WARNING]\n> Be careful")) == "> [!WARNING]\n> Be careful\n"

    # Multiple paragraphs in alert
    @test html(p("> [!NOTE]\n> Para 1\n>\n> Para 2")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>Para 1</p>\n<p>Para 2</p>\n</div>\n"

    # Blank line immediately after marker (marker-only first paragraph gets unlinked)
    @test html(p("> [!TIP]\n>\n> Content here")) ==
          "<div class=\"github-alert tip\"><p class=\"github-alert-title\">Tip</p>\n<p>Content here</p>\n</div>\n"
    @test markdown(p("> [!TIP]\n>\n> Content here")) == "> [!TIP]\n> Content here\n"

    # No interference with link references
    # [!NOTE] should not conflict with link reference syntax [text]: url
    p_linkref = create_parser(ReferenceLinkRule())
    @test html(p_linkref("> Regular [link][ref]\n\n[ref]: url")) ==
          "<blockquote>\n<p>Regular <a href=\"url\">link</a></p>\n</blockquote>\n"

    # Alert with link reference should work
    p_both = create_parser([GitHubAlertRule(), ReferenceLinkRule()])
    @test html(p_both("> [!NOTE]\n> See [link][ref]\n\n[ref]: url")) ==
          "<div class=\"github-alert note\"><p class=\"github-alert-title\">Note</p>\n<p>See <a href=\"url\">link</a></p>\n</div>\n"

    # Reference tests for all formats
    test_alert("note_basic", p("> [!NOTE]\n> Basic note content."), "github_alerts")

    test_alert("note_multiline", p("""
        > [!NOTE]
        > Line one.
        > Line two.
        > Line three.
        """), "github_alerts")

    test_alert("note_multipara", p("""
        > [!NOTE]
        > First paragraph.
        >
        > Second paragraph.
        """), "github_alerts")

    test_alert("warning_formatted", p("""
        > [!WARNING]
        > This has **bold**, *italic*, and `code`.
        """), "github_alerts")

    test_alert(
        "tip_with_link",
        p("> [!TIP]\n> See [documentation](https://example.com)."),
        "github_alerts",
    )

    # Blank line after marker - tests unlink during iteration fix
    test_alert("tip_blank_after_marker", p("""
        > [!TIP]
        >
        > Here is some **bold** and *italic* content.
        >
        > And a second paragraph with a [link](https://example.com).
        """), "github_alerts")
end
