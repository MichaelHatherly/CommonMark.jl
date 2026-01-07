# CommonMark.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://michaelhatherly.github.io/CommonMark.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://michaelhatherly.github.io/CommonMark.jl/dev)

*A [CommonMark](https://spec.commonmark.org/current/)-compliant parser for Julia.*

## Features

- **Spec compliant** – passes the CommonMark spec test suite
- **Multiple outputs** – HTML, LaTeX, Typst, terminal (ANSI), Jupyter notebooks, Pandoc JSON
- **Markdown roundtrip** – parse and re-emit normalized markdown
- **Modular parser** – enable/disable individual syntax rules
- **Extensions** – tables, footnotes, math, front matter, admonitions, attributes, citations, and more

## Quick Start

```julia
using CommonMark

parser = Parser()
enable!(parser, TableRule())
enable!(parser, MathRule())

ast = parser("# Hello *world*")
html(ast)       # HTML string
latex(ast)      # LaTeX string
term(stdout, ast)  # ANSI terminal output
```
