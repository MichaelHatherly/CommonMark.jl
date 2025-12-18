# Runtime benchmarks for CommonMark.jl
#
# Run with: julia --project=benchmark benchmark/run.jl
# Or interactively: include("benchmark/benchmarks.jl"); run(SUITE)

import BenchmarkTools
import CommonMark
import JSON3

const SUITE = BenchmarkTools.BenchmarkGroup()

# Load test data
const SPEC_MD =
    read(joinpath(@__DIR__, "..", "test", "samples", "cmark", "spec.md"), String)
const SPEC_JSON = JSON3.read(read(joinpath(@__DIR__, "..", "test", "spec.json"), String))

# Smaller test inputs for micro-benchmarks
const SIMPLE_MD = """
# Heading

This is a paragraph with **bold** and *italic* text.

- Item 1
- Item 2
- Item 3

```julia
println("Hello")
```

[Link](https://example.com)
"""

const COMPLEX_MD = """
# Document Title

## Section 1

This paragraph has **bold**, *italic*, `code`, and [links](url).

> A blockquote with
> multiple lines

1. Ordered item
2. Another item
   - Nested unordered
   - More nesting

## Section 2

| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |

```python
def hello():
    print("world")
```

Final paragraph with an image: ![alt](image.png)
"""

# Create parsers
const PARSER = CommonMark.Parser()
const PARSER_WITH_EXTENSIONS = let
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.TableRule())
    CommonMark.enable!(p, CommonMark.FootnoteRule())
    CommonMark.enable!(p, CommonMark.MathRule())
    CommonMark.enable!(p, CommonMark.TaskListRule())
    p
end

# Pre-parse ASTs for writer benchmarks
const AST_SIMPLE = PARSER(SIMPLE_MD)
const AST_COMPLEX = PARSER_WITH_EXTENSIONS(COMPLEX_MD)
const AST_SPEC = PARSER(SPEC_MD)

# === Parsing Benchmarks ===
SUITE["parse"] = BenchmarkTools.BenchmarkGroup()
SUITE["parse"]["simple"] = BenchmarkTools.@benchmarkable $PARSER($SIMPLE_MD)
SUITE["parse"]["complex"] =
    BenchmarkTools.@benchmarkable $PARSER_WITH_EXTENSIONS($COMPLEX_MD)
SUITE["parse"]["spec_md"] = BenchmarkTools.@benchmarkable $PARSER($SPEC_MD)

# All spec JSON cases
SUITE["parse"]["spec_cases_all"] = BenchmarkTools.@benchmarkable begin
    for case in $SPEC_JSON
        $PARSER(case.markdown)
    end
end

# === Writer Benchmarks ===
SUITE["html"] = BenchmarkTools.BenchmarkGroup()
SUITE["html"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.html($AST_SIMPLE)
SUITE["html"]["complex"] = BenchmarkTools.@benchmarkable CommonMark.html($AST_COMPLEX)
SUITE["html"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.html($AST_SPEC)

SUITE["markdown"] = BenchmarkTools.BenchmarkGroup()
SUITE["markdown"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.markdown($AST_SIMPLE)
SUITE["markdown"]["complex"] =
    BenchmarkTools.@benchmarkable CommonMark.markdown($AST_COMPLEX)
SUITE["markdown"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.markdown($AST_SPEC)

SUITE["latex"] = BenchmarkTools.BenchmarkGroup()
SUITE["latex"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.latex($AST_SIMPLE)
SUITE["latex"]["complex"] = BenchmarkTools.@benchmarkable CommonMark.latex($AST_COMPLEX)
SUITE["latex"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.latex($AST_SPEC)

SUITE["term"] = BenchmarkTools.BenchmarkGroup()
SUITE["term"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.term($AST_SIMPLE)
SUITE["term"]["complex"] = BenchmarkTools.@benchmarkable CommonMark.term($AST_COMPLEX)
SUITE["term"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.term($AST_SPEC)

SUITE["typst"] = BenchmarkTools.BenchmarkGroup()
SUITE["typst"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.typst($AST_SIMPLE)
SUITE["typst"]["complex"] = BenchmarkTools.@benchmarkable CommonMark.typst($AST_COMPLEX)
SUITE["typst"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.typst($AST_SPEC)

SUITE["notebook"] = BenchmarkTools.BenchmarkGroup()
SUITE["notebook"]["simple"] = BenchmarkTools.@benchmarkable CommonMark.notebook($AST_SIMPLE)
SUITE["notebook"]["complex"] =
    BenchmarkTools.@benchmarkable CommonMark.notebook($AST_COMPLEX)
SUITE["notebook"]["spec_md"] = BenchmarkTools.@benchmarkable CommonMark.notebook($AST_SPEC)

# === Roundtrip benchmark (all extensions) ===
const ROUNDTRIP_MD = read(joinpath(@__DIR__, "..", "test", "roundtrip", "input.md"), String)
const PARSER_ALL_EXTENSIONS = let
    p = CommonMark.Parser()
    CommonMark.enable!(p, CommonMark.AdmonitionRule())
    CommonMark.enable!(p, CommonMark.AttributeRule())
    CommonMark.enable!(p, CommonMark.AutoIdentifierRule())
    CommonMark.enable!(p, CommonMark.CitationRule())
    CommonMark.enable!(p, CommonMark.DollarMathRule())
    CommonMark.enable!(p, CommonMark.FencedDivRule())
    CommonMark.enable!(p, CommonMark.FootnoteRule())
    CommonMark.enable!(p, CommonMark.FrontMatterRule())
    CommonMark.enable!(p, CommonMark.GitHubAlertRule())
    CommonMark.enable!(p, CommonMark.MathRule())
    CommonMark.enable!(p, CommonMark.RawContentRule())
    CommonMark.enable!(p, CommonMark.ReferenceLinkRule())
    CommonMark.enable!(p, CommonMark.StrikethroughRule())
    CommonMark.enable!(p, CommonMark.SubscriptRule())
    CommonMark.enable!(p, CommonMark.SuperscriptRule())
    CommonMark.enable!(p, CommonMark.TableRule())
    CommonMark.enable!(p, CommonMark.TaskListRule())
    CommonMark.enable!(p, CommonMark.TypographyRule())
    p
end
const AST_ROUNDTRIP = PARSER_ALL_EXTENSIONS(ROUNDTRIP_MD)

SUITE["roundtrip"] = BenchmarkTools.BenchmarkGroup()
SUITE["roundtrip"]["parse_all_ext"] =
    BenchmarkTools.@benchmarkable $PARSER_ALL_EXTENSIONS($ROUNDTRIP_MD)
SUITE["roundtrip"]["markdown_all_ext"] =
    BenchmarkTools.@benchmarkable CommonMark.markdown($AST_ROUNDTRIP)
SUITE["roundtrip"]["full"] =
    BenchmarkTools.@benchmarkable CommonMark.markdown($PARSER_ALL_EXTENSIONS($ROUNDTRIP_MD))

# === Allocation-focused benchmarks ===
SUITE["allocations"] = BenchmarkTools.BenchmarkGroup()
SUITE["allocations"]["parse_spec"] =
    BenchmarkTools.@benchmarkable $PARSER($SPEC_MD) evals = 1 samples = 10
SUITE["allocations"]["html_spec"] =
    BenchmarkTools.@benchmarkable CommonMark.html($AST_SPEC) evals = 1 samples = 10
