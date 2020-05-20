# CommonMark

*A [CommonMark](https://spec.commonmark.org/current/)-compliant parser for Julia.*

[![Build Status](https://travis-ci.org/MichaelHatherly/CommonMark.jl.svg?branch=master)](https://travis-ci.org/MichaelHatherly/CommonMark.jl)
[![Codecov](https://codecov.io/gh/MichaelHatherly/CommonMark.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/MichaelHatherly/CommonMark.jl)

## Interface

```
julia> using CommonMark

julia> p = CommonMark.Parser();

julia> ast = CommonMark.parse(p, "Hello *world*");

julia> r = CommonMark.Renderer(CommonMark.HTML());

julia> read(CommonMark.render(r, ast), String)
"<p>Hello <em>world</em></p>\n"
```

The parser outputs `Node` trees that can then be written to `HTML`, `LaTeX`, or
`Term` formats.

## Extensions

Available extensions include the following:

- Frontmatter: support for JSON, TOML, and YAML.
- GFM-tables, strict requirement for alignment of `|` between columns
- Double backtick inline LaTeX math and display math blocks
- Admonitions
- Footnotes

Extensions have no public API at the moment. See `test/extensions/` for details
on how to enable them. The final interface is up for discussion.

Implementation of new extensions can follow the examples found in `src/extensions`.
