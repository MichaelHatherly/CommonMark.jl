@testitem "tables" tags = [:extensions, :tables] setup = [Utilities] begin
    using CommonMark
    using Test
    using ReferenceTests

    test_table = test_all_formats(pwd())

    p = create_parser(TableRule())

    # Basic table
    text = """
           | 1 | 10 | 100 |
           | - | --:|:---:|
           | x | y  | z   |
           """
    ast = p(text)
    test_table("basic", ast, "tables")

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
    test_table("misaligned", ast, "tables")

    # Table with attributes
    p = create_parser([TableRule(), AttributeRule()])

    text = """
           {#id}
           | 1 | 10 | 100 |
           | - | --:|:---:|
           | x | y  | z   |
           """
    ast = p(text)
    test_table("with_id", ast, "tables")

    # Internal pipes
    text = """
           |1|10|`|`|
           | -:| - |:-:|
           |*|*|![|](url)|
           |1|2|3|4|
           """
    ast = p(text)
    test_table("internal_pipes", ast, "tables")

    # Empty columns
    text = """
           |||
           |-|-|
           |||
           """
    ast = p(text)
    test_table("empty_columns", ast, "tables")

    # Table with header
    text = """
           # Header

           | table |
           | ----- |
           | content |
           """
    ast = p(text)
    test_table("with_header", ast, "tables")

    # Messy tables
    text = """
           # Messy tables

           | table
           | :-: |
           | *|*
           """
    ast = p(text)
    test_table("messy", ast, "tables")

    # Tables with lots of whitespace
    text = """
           # whitespace (#38)

           | 1         | 2         | 3       |       4 |
           |   :--:    |   :--     |   ---   |   -:    |
           | one       | two       |   three |   four  |
           """
    ast = p(text)
    test_table("whitespace", ast, "tables")

    # Unicode content
    text = """
           | Tables   |      Are      |  Cool |
           |----------|-------------|------|
           | col 3 is | right-aligned δεδομέ |   1 |
           """
    ast = p(text)
    test_table("unicode", ast, "tables")
end
