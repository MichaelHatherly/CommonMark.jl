@testitem "admonitions" tags = [:extensions, :admonitions] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    p = create_parser(AdmonitionRule())
    test_admonition = test_all_formats(pwd())

    # Basic warning admonition
    test_admonition("warning_basic", p("""
                                     !!! warning

                                         text
                                     """), "admonitions")

    # Warning with tab-indented content
    test_admonition("warning_tab_indent", p("""
                                          !!! warning

                                          \ttext
                                          """), "admonitions")

    # Info admonition with custom title
    test_admonition("info_custom_title", p("""
                                         !!! info "Custom Title"

                                             text
                                         """), "admonitions")

    # Warning with attributes (id)
    p_with_attrs = create_parser([AdmonitionRule(), AttributeRule()])
    test_admonition(
        "warning_with_id",
        p_with_attrs("""
        {#id}
        !!! warning

            text
        """),
        "admonitions",
        formats = [:html, :latex],
    )
end
