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

Current extensions supported by this package are:

### Admonitions

```
!!! note

    This is the content of the note.

!!! warning

    And this is another one.
```

Enabled with:

```julia
parser = CommonMark.Parser()
CommonMark.enable!(parser, CommonMark.AdmonitionRule())
```

### Front matter

Fenced blocks at the start of a file containing structured data.

```
+++
[heading]
content = "..."
+++

The rest of the file...
```

The block **must** start on the first line of the file. Supported blocks are:

  - `;;;` for JSON
  - `+++` for TOML
  - `---` for YAML

Enable with:

```julia
using JSON, YAML
parser = CommonMark.Parser()
rule = CommonMark.FrontMatterRule(
    json=JSON.Parser.parse,
    yaml=YAML.load,
)
CommonMark.enable!(parser, rule)
```

### Footnotes

```
A paragraph containing a numbered footnote [^1] and a named one [^note].

[^1]: Numbered footnote text.

[^note]:

    Named footnote text containing several toplevel elements.

      * item one
      * item two
      * item three

    ```julia
    function func(x)
        # ...
    end
    ```
```

Enabled with:

```julia
parser = CommonMark.Parser()
CommonMark.enable!(parser, CommonMark.FootnoteRule())
```

### Math

Julia-style inline and display maths:

````
Some ``\LaTeX`` math:

```math
f(a) = \frac{1}{2\pi}\int_{0}^{2\pi} (\alpha+R\cos(\theta))d\theta
```
````

Enabled with:

```julia
parser = CommonMark.Parser()
CommonMark.enable!(parser, CommonMark.MathRule())
```

### Tables

Pipe-style tables, similar to GitHub's using `|`. Strict alignment required for pipes.

```
| Column One | Column Two | Column Three |
|:---------- | ---------- |:------------:|
| Row `1`    | Column `2` |              |
| *Row* 2    | **Row** 2  | Column ``3`` |
```

Enabled with:

```julia
parser = CommonMark.Parser()
CommonMark.enable!(parser, CommonMark.TableRule())
```
