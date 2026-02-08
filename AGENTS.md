# AGENTS.md

Project guidance for AI coding assistants.

## Project Overview

CommonMark.jl is a Julia implementation of the CommonMark specification. It provides a modular parser, AST representation, and multiple output formats (HTML, LaTeX, Typst, Terminal, Markdown, Notebook).

## Development Commands

### Testing
```bash
julia --project -e 'using Pkg; Pkg.test()'  # Run all tests
just test-all                                # Via justfile
just test-item <name>                        # Run specific test item
```

To run tests with TestItemRunner (filtered by tag, name, etc.):
```bash
julia --project <<'EOF'
using TestEnv; TestEnv.activate(); cd("test")
using TestItemRunner
@run_package_tests(filter=ti->:math in ti.tags)
EOF
```

### Code Formatting
```bash
just format
```

### Building
```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

### Documentation
```bash
julia --project=docs -e 'include("docs/make.jl")'  # Build docs locally
```

### Benchmarking
```bash
just bench                           # Run benchmarks (terminal output)
just bench-save <name>               # Save results to benchmark/results/<name>.json
just bench-compare <baseline> <cur>  # Compare two saved results
```

## Key Entry Points

- `src/CommonMark.jl` - main module, exports
- `src/ast.jl` - Node struct, tree operations
- `src/parsers.jl` - Parser struct, block/inline parsing
- `src/writers.jl` - output format dispatch
- `src/extensions.jl` - extension includes

## Architecture

### Core Components

1. **AST (Abstract Syntax Tree)**: Built around `Node` type with container hierarchy
   - `AbstractContainer` → `AbstractBlock`/`AbstractInline`
   - Doubly-linked tree with parent/child/sibling references
   - Source position tracking (`sourcepos` field)
   - Metadata dictionary for extensibility

2. **Parser System**: Two-phase parsing (blocks then inlines)
   - Rule-based with pluggable components
   - Parser state tracks position and context
   - Rules in `src/parsers/blocks/` and `src/parsers/inlines/`

3. **Writer System**: MIME-based dispatch for output formats
   - Each writer in `src/writers/` (html.jl, latex.jl, etc.)
   - Template support via Mustache
   - Environment configuration passing

4. **Extension System**: Optional features via rule modification
   - Extensions in `src/extensions/`
   - Enabled via parser configuration
   - Maintains CommonMark compliance when disabled

### Key Design Patterns

- **Visitor Pattern**: Tree traversal via iterator protocol
- **Rule Pattern**: Modular parsing rules that can be enabled/disabled
- **MIME Dispatch**: Output format selection via Julia's MIME system
- **Type Stability**: Careful use of concrete types in AST

### Creating New Rules

See `docs/src/developing.md` for internal documentation on writing extension rules. Covers AST nodes, parser hooks, and writer functions.

### Testing Strategy

- CommonMark spec compliance tested against `test/spec.json`
- Unit tests for each component
- Integration tests in `test/integration.jl`
- Sample-based testing with expected outputs in `test/samples/`
