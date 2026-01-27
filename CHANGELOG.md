# CommonMark.jl changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [v0.10.2] - 2026-01-27

### Fixed

- Fix extension loading when CommonMark is not on LOAD_PATH [#135]

## [v0.10.1] - 2026-01-27

### Added

- Add `@docstring_parser` macro for CommonMark-formatted module docstrings (experimental) [#131]
- Add `Parser(enable=[], disable=[])` keyword arguments for rule configuration at construction [#133]
- Add bidirectional conversion between CommonMark and MarkdownAST via `MarkdownAST.Node(cm)` and `CommonMark.Node(mast)` [#130]

### Fixed

- Fix ExtensionLoader breaking precompilation by evaling into closed module during `__init__` [#132]

## [v0.10.0] - 2026-01-08

### Added

- Add `MarkRule` extension for highlighted text (`==text==` renders as `<mark>`) with Pandoc JSON roundtrip [#129]
- Document `@cm_str` macro, `json(Dict, ast)`, `Node(dict)`, `frontmatter()`, and writer `env` parameter [#128]
- Add `Node(md::Markdown.MD)` to convert Julia stdlib Markdown AST to CommonMark AST [#126]
- Add `transform` keyword argument to writers for AST node interception during rendering [#123]
- Add transforms documentation page with URL rewriting, syntax highlighting, and document wrapper examples [#123]
- Add `UnresolvedReference` node type for detecting undefined reference links with `ReferenceLinkRule` [#121]
- Add programmatic AST construction with `Node(Type, children...)` builders for all container types [#120]
- Add tree manipulation functions as public API: `append_child`, `prepend_child`, `insert_after`, `insert_before`, `unlink`, `isnull`, `text` [#120]
- Add docstrings to all container types and tree manipulation functions [#120]
- Add "Building ASTs" documentation page for programmatic construction [#120]
- Add `json(Dict, ast)` to return Pandoc AST dict without JSON serialization [#119]
- Export `Node` as public API [#119]
- Add `Node(dict)` constructor for Pandoc AST JSON import [#118]
- Add `json()` writer for Pandoc AST JSON export [#116]
- Add stdlib compatibility tests covering 30 Julia Markdown issues [#113]
- Add continuous benchmarking CI with historical tracking and PR comparisons [#104]
- Add internal documentation for writing extension rules [#103]
- Add AGENTS.md for AI coding assistants [#103]
- Add Documenter.jl documentation [#102]
- Add docstrings to all parser rules, writers, and core API [#102]
- Add roundtrip stability to markdown writer (opinionated formatting with no trailing whitespace) [#100]
- Add `FencedDivRule` extension for Pandoc-style fenced divs (`::: class` blocks with nesting) [#99]
- Add `GitHubAlertRule` extension for GitHub-style alert blockquotes (`> [!NOTE]`, etc.) [#98]
- Add `ReferenceLinkRule` extension to preserve reference link style in AST [#95]
- Add `TaskListRule` extension for GitHub-style task lists (`- [ ]`/`- [x]`) [#94]
- Add `StrikethroughRule` (`~~text~~`), `SubscriptRule` (`~text~`), and `SuperscriptRule` (`^text^`) extensions [#93]
- Add generalized delimiter-based inline extension system (`delim_nodes`, `flanking_rule`, `uses_odd_match` hooks) [#93]
- Add Unicode sub/superscript rendering for terminal writer [#93]

### Removed

- Remove `template-engine`, `smartlink-engine`, and `syntax-highlighter` env hooks (use `transform` instead) [#123]
- Remove built-in Mustache templates for HTML and LaTeX (use transform on `Document` instead) [#123]

### Fixed

- Update to CommonMark spec 0.31.2 (649 → 655 test cases) [#115]
- Fix Unicode punctuation check for emphasis flanking (include Symbol category) [#115]
- Fix Unicode case folding for reference link matching (ẞ → ss) [#115]
- Fix entity regex allowing 8 decimal digits instead of spec-mandated 7 [#114]
- Fix benchmark select dropdowns rendering inconsistently in webkit browsers [#106]
- Fix benchmark CI failing on gh-pages branch (missing project files) [#105]
- Fix HTML attribute ordering for Julia 1.12+ compatibility (dict iteration order changed) [#101]
- Fix table parser not ending on blank lines (consecutive tables merged incorrectly) [#100]
- Fix markdown writer loose list spacing inconsistency [#100]
- Fix markdown writer inline code using even backtick counts (conflicted with math syntax) [#100]
- Fix markdown writer empty list items having trailing whitespace [#100]
- Fix markdown writer adding unwanted blank lines in tight lists with nested content [#97]
- Fix markdown writer not escaping quotes in link/image titles [#95]
- Fix citations author lookup failing for JSON-parsed bibliography data [#93]

### Changed

- Add type annotations and helper function for type stability in block parser hot path [#125]
- Cache heading tag strings and bullet strings to reduce allocations in writers [#125]
- Replace regex with character check in table spec validation [#111]
- Eliminate redundant dictionary lookup in auto-identifier rule [#111]
- Use BitVector trigger table for O(1) inline parser character lookups [#110]
- Replace regex NUL check with character membership test [#110]
- Remove dead code in fenced code block parser (regex called twice) [#110]
- Precompute emphasis delimiter lookups to avoid repeated iteration in hot path [#109]
- Use IOBuffer for literal accumulation and pre-allocate delimiter strings to reduce allocations [#108]
- Lazy initialization for Node.meta to reduce memory allocations during parsing [#107]

- Require JSON.jl v1 (drop support for 0.20, 0.21) [#93]

## [v0.9.0] - 2025-03-06

### Added

- Add `typst` writer [#84]

## [v0.8.15] - 2024-10-04

### Fixed

- Remove `URIs` dependency [#80]
- Remove `JSON` dependency [#81]
- Reduce stored entity data [#82]

## [v0.8.14] - 2024-10-04

### Fixed

- Fixed duplicate attributes in HTML rendering [#78]

## [v0.8.13] - 2024-10-03

### Fixed

- Fixed `sourcepos` for HTML output [#75]
- Correctly restrict `julia` version to those that are actively tested [#76]

## [v0.8.12] - 2023-04-27

### Fixed

- Migrate to using `PrecompileTools` instead of `SnoopPrecompile` [#64]

## [v0.8.11] - 2023-04-14

### Fixed

- Early exit while parsing rows with unicode characters [#63]

## [v0.8.10] - 2023-01-22

### Fixed

- Specialize `occursin` on `Regex` [#62]

## [v0.8.9] - 2023-01-20

### Fixed

- Improve precompilation with `SnoopPrecompile` workload [#59]

## [v0.8.8] - 2023-01-18

### Fixed

- Pass `IOContext` through to `JuliaValue`s in HTML renderer [#58]

## [v0.8.7] - 2022-11-16

### Fixed

- Fixed Unicode bug in admonition syntax [#53]
- Fixed interpolation when mutating interpolated values [#51]
- Fixed interpolation bug with assignment operators [#50]
- Avoid duplicating rules when `enable!`ing and `disable!`ing [#46]

## [v0.8.6] - 2022-02-10

### Fixed

- Fixed extra whitespace in table parsing

## [v0.8.5] - 2021-12-16

### Fixed

- Avoid mutating parsed AST in `@cm_str`

## [v0.8.4] - 2021-12-07

### Fixed

- Fixed method ambiguity in `Base.get!` definition

## [v0.8.3] - 2021-09-23

### Fixed

- Added `tex` class to rendered math in `html` output

## [v0.8.2] - 2021-07-15

### Added

- Added `frontmatter` to extract frontmatter from parsed document

### Fixed

- Fixed enumi counter bug in `latex`

## [v0.8.1] - 2021-03-18

### Fixed

- Fixed empty list and block quote rendering of margins

## [v0.8.0] - 2021-03-10

### Added

- Added `@cm_str` macro
- Added interpolation extension

## [v0.7.3] - 2021-03-01

### Fixed

- Fixed tab indent in admonitions and footnote bodies

## [v0.7.2] - 2021-02-06

### Fixed

- Improve types for `Parser` rules and priorities

## [v0.7.1] - 2020-11-30

### Fixed

- Fixed stackoverflow in `disable!`

## [v0.7.0] - 2020-11-28

### Added

- Added syntax highlighting hooks to rendering

### Fixed

- Improve `latex` rendering
- Escape characters in non-highlighted code blocks

## [v0.6.4] - 2020-09-03

### Fixed

- Allow empty attribute keys

## [v0.6.3] - 2020-08-29

### Fixed

- Fixed `latex` table rendering

## [v0.6.2] - 2020-08-16

### Fixed

- Fixed typo in admonition rendering
- Allow whitespace before attribute syntax
- Pass through node to smartlinks
- Fixed greedy consume in `TypographyRule`

## [v0.6.1] - 2020-08-07

### Fixed

- Relaxed GitHub-flavoured markdown table parsing

## [v0.6.0] - 2020-08-06

### Added

- `$` math syntax
- Added header and footer variables to default templates

## [v0.5.2] - 2020-07-14

### Fixed

- Update HTML block parsing to match upstream changes

## [v0.5.1] - 2020-07-12

### Fixed

- Fixed bug in `TableRule`

## [v0.5.0] - 2020-07-04

### Added

- Automatically add IDs to headers with the `AutoIdentifierRule` extension
- Allow passing `Parser`s to `open` to parse files directly
- Non-strict table alignment

### Fixed

- Improve `markdown` roundtripping

## [v0.4.0] - 2020-06-14

### Added

- Attribute extension for attaching metadata to AST nodes
- Template system for writing standalone documents
- Citation and reference extension

### Fixed

- Fixed `markdown` to allow for better roundtrip rendering

## [v0.3.0] - 2020-06-03

### Added

- Raw content extension
- `markdown` and Jupyter `notebook` output

### Fixed

- Fixed `latex` rendering bugs where newlines were not preserved

## [v0.2.0] - 2020-05-26

### Added

- Frontmatter blocks
- Added rules system for parser extensions
- Added callable API for parser objects
- Export public API
- Smart typography rules
- Added custom admonition titles

### Fixed

- Fixed pirated `peek` method
- Handle poorly aligned tables better

## [v0.1.0] - 2020-05-23

Initial release.


<!-- Links generated by Changelog.jl -->

[v0.1.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.1.0
[v0.2.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.2.0
[v0.3.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.3.0
[v0.4.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.4.0
[v0.5.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.5.0
[v0.5.1]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.5.1
[v0.5.2]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.5.2
[v0.6.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.6.0
[v0.6.1]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.6.1
[v0.6.2]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.6.2
[v0.6.3]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.6.3
[v0.6.4]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.6.4
[v0.7.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.7.0
[v0.7.1]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.7.1
[v0.7.2]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.7.2
[v0.7.3]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.7.3
[v0.8.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.0
[v0.8.1]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.1
[v0.8.2]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.2
[v0.8.3]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.3
[v0.8.4]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.4
[v0.8.5]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.5
[v0.8.6]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.6
[v0.8.7]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.7
[v0.8.8]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.8
[v0.8.9]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.9
[v0.8.10]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.10
[v0.8.11]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.11
[v0.8.12]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.12
[v0.8.13]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.13
[v0.8.14]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.14
[v0.8.15]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.8.15
[v0.9.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.9.0
[v0.10.0]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.10.0
[v0.10.1]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.10.1
[v0.10.2]: https://github.com/MichaelHatherly/CommonMark.jl/releases/tag/v0.10.2
[#46]: https://github.com/MichaelHatherly/CommonMark.jl/issues/46
[#50]: https://github.com/MichaelHatherly/CommonMark.jl/issues/50
[#51]: https://github.com/MichaelHatherly/CommonMark.jl/issues/51
[#53]: https://github.com/MichaelHatherly/CommonMark.jl/issues/53
[#58]: https://github.com/MichaelHatherly/CommonMark.jl/issues/58
[#59]: https://github.com/MichaelHatherly/CommonMark.jl/issues/59
[#62]: https://github.com/MichaelHatherly/CommonMark.jl/issues/62
[#63]: https://github.com/MichaelHatherly/CommonMark.jl/issues/63
[#64]: https://github.com/MichaelHatherly/CommonMark.jl/issues/64
[#75]: https://github.com/MichaelHatherly/CommonMark.jl/issues/75
[#76]: https://github.com/MichaelHatherly/CommonMark.jl/issues/76
[#78]: https://github.com/MichaelHatherly/CommonMark.jl/issues/78
[#80]: https://github.com/MichaelHatherly/CommonMark.jl/issues/80
[#81]: https://github.com/MichaelHatherly/CommonMark.jl/issues/81
[#82]: https://github.com/MichaelHatherly/CommonMark.jl/issues/82
[#84]: https://github.com/MichaelHatherly/CommonMark.jl/issues/84
[#93]: https://github.com/MichaelHatherly/CommonMark.jl/issues/93
[#94]: https://github.com/MichaelHatherly/CommonMark.jl/issues/94
[#95]: https://github.com/MichaelHatherly/CommonMark.jl/issues/95
[#97]: https://github.com/MichaelHatherly/CommonMark.jl/issues/97
[#98]: https://github.com/MichaelHatherly/CommonMark.jl/issues/98
[#99]: https://github.com/MichaelHatherly/CommonMark.jl/issues/99
[#100]: https://github.com/MichaelHatherly/CommonMark.jl/issues/100
[#101]: https://github.com/MichaelHatherly/CommonMark.jl/issues/101
[#102]: https://github.com/MichaelHatherly/CommonMark.jl/issues/102
[#103]: https://github.com/MichaelHatherly/CommonMark.jl/issues/103
[#104]: https://github.com/MichaelHatherly/CommonMark.jl/issues/104
[#105]: https://github.com/MichaelHatherly/CommonMark.jl/issues/105
[#106]: https://github.com/MichaelHatherly/CommonMark.jl/issues/106
[#107]: https://github.com/MichaelHatherly/CommonMark.jl/issues/107
[#108]: https://github.com/MichaelHatherly/CommonMark.jl/issues/108
[#109]: https://github.com/MichaelHatherly/CommonMark.jl/issues/109
[#110]: https://github.com/MichaelHatherly/CommonMark.jl/issues/110
[#111]: https://github.com/MichaelHatherly/CommonMark.jl/issues/111
[#113]: https://github.com/MichaelHatherly/CommonMark.jl/issues/113
[#114]: https://github.com/MichaelHatherly/CommonMark.jl/issues/114
[#115]: https://github.com/MichaelHatherly/CommonMark.jl/issues/115
[#116]: https://github.com/MichaelHatherly/CommonMark.jl/issues/116
[#118]: https://github.com/MichaelHatherly/CommonMark.jl/issues/118
[#119]: https://github.com/MichaelHatherly/CommonMark.jl/issues/119
[#120]: https://github.com/MichaelHatherly/CommonMark.jl/issues/120
[#121]: https://github.com/MichaelHatherly/CommonMark.jl/issues/121
[#123]: https://github.com/MichaelHatherly/CommonMark.jl/issues/123
[#125]: https://github.com/MichaelHatherly/CommonMark.jl/issues/125
[#126]: https://github.com/MichaelHatherly/CommonMark.jl/issues/126
[#128]: https://github.com/MichaelHatherly/CommonMark.jl/issues/128
[#129]: https://github.com/MichaelHatherly/CommonMark.jl/issues/129
[#130]: https://github.com/MichaelHatherly/CommonMark.jl/issues/130
[#131]: https://github.com/MichaelHatherly/CommonMark.jl/issues/131
[#132]: https://github.com/MichaelHatherly/CommonMark.jl/issues/132
[#133]: https://github.com/MichaelHatherly/CommonMark.jl/issues/133
[#135]: https://github.com/MichaelHatherly/CommonMark.jl/issues/135
