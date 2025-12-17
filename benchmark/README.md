# Benchmarks for CommonMark.jl

Continuous benchmarking tracks performance over time. Results stored in `benchmark-results` branch, visualized via GitHub Pages.

## Running locally

```bash
# Run all benchmarks and output JSON
julia --project=benchmark benchmark/run.jl output.json

# Or just see results in terminal
julia --project=benchmark benchmark/run.jl
```

## Benchmark suite

The suite in `benchmarks.jl` covers:

- **parse/** - Parsing (simple, complex, spec.md, all spec cases)
- **html/** - HTML generation
- **markdown/** - Markdown roundtrip
- **latex/** - LaTeX generation
- **term/** - Terminal output
- **allocations/** - Allocation-focused measurements

## CI workflow

- **Push to master**: Results stored in `gh-pages` branch under `benchmarks/`
- **Pull requests**: Comparison posted as PR comment
- **Visualization**: https://michaelhatherly.github.io/CommonMark.jl/benchmarks/

## Comparing results

```bash
julia --project=benchmark -e '
    include("benchmark/compare.jl")
    compare_and_report("baseline.json", "current.json", "comparison.md")
'
```
