@testset "Tables" begin
    using ReferenceTests

    # Helper function for tests that can use references
    function test_table(base_name, ast)
        formats = [
            (html, "html.txt"),
            (latex, "tex"),
            (markdown, "md"),
            (term, "txt"),
            (typst, "typ"),
        ]
        for (func, ext) in formats
            filename = "references/tables/$(base_name).$(ext)"
            output = func(ast)
            @test_reference filename Text(output)
        end
    end

    p = Parser()
    enable!(p, TableRule())

    # Basic table
    text = """
           | 1 | 10 | 100 |
           | - | --:|:---:|
           | x | y  | z   |
           """
    ast = p(text)
    test_table("basic", ast)

    # Roundtrip test
    @test markdown(p(markdown(ast))) ==
          "| 1 | 10 | 100 |\n|:- | --:|:---:|\n| x | y  | z   |\n"

    # Mis-aligned table pipes
    text = """
           |1|10|100|
           | - | --:|:---:|
           |x|y|z|
           """
    ast = p(text)
    test_table("misaligned", ast)

    # Table with attributes
    p = enable!(Parser(), [TableRule(), AttributeRule()])

    text = """
           {#id}
           | 1 | 10 | 100 |
           | - | --:|:---:|
           | x | y  | z   |
           """
    ast = p(text)
    test_table("with_id", ast)

    # Internal pipes
    text = """
           |1|10|`|`|
           | -:| - |:-:|
           |*|*|![|](url)|
           |1|2|3|4|
           """
    ast = p(text)
    test_table("internal_pipes", ast)

    # Empty columns
    text = """
           |||
           |-|-|
           |||
           """
    ast = p(text)
    test_table("empty_columns", ast)

    # Table with header
    text = """
           # Header

           | table |
           | ----- |
           | content |
           """
    ast = p(text)
    test_table("with_header", ast)

    # Messy tables
    text = """
           # Messy tables

           | table
           | :-: |
           | *|*
           """
    ast = p(text)
    test_table("messy", ast)

    # Tables with lots of whitespace
    text = """
           # whitespace (#38)

           | 1         | 2         | 3       |       4 |
           |   :--:    |   :--     |   ---   |   -:    |
           | one       | two       |   three |   four  |
           """
    ast = p(text)
    test_table("whitespace", ast)

    # Unicode content
    text = """
           | Tables   |      Are      |  Cool |
           |----------|-------------|------|
           | col 3 is | right-aligned δεδομέ |   1 |
           """
    ast = p(text)
    test_table("unicode", ast)
end
