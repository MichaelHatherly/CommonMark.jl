update:
    julia --project=. -e 'import Pkg; Pkg.update()'
    julia --project=.ci -e 'import Pkg; Pkg.update()'
    julia --project=.format -e 'import Pkg; Pkg.update()'

format:
    julia --project=.format .format/format.jl

changelog:
    julia --project=.ci .ci/changelog.jl

# REPLicant recipes
# Execute Julia code via REPLicant
julia code:
    printf '%s' "{{code}}" | nc localhost $(cat REPLICANT_PORT)

# Documentation lookup
docs binding:
    just julia "@doc {{binding}}"

# Run all tests
test-all:
    just julia "@run_package_tests"

# Run specific test item
test-item item:
    just julia "@run_package_tests filter=ti->ti.name == String(:{{item}})"

# Run benchmarks (output to terminal)
bench:
    julia --project=benchmark benchmark/run.jl

# Quick benchmark for iteration
bench-quick:
    julia --project=benchmark benchmark/quick.jl

# Profile to find hot spots
bench-profile:
    julia --project=benchmark benchmark/profile.jl

# Run benchmarks and save to file
bench-save name:
    julia --project=benchmark benchmark/run.jl benchmark/results/{{name}}.json

# Compare two benchmark results
bench-compare baseline current:
    julia --project=benchmark -e 'include("benchmark/compare.jl"); compare_and_report("benchmark/results/{{baseline}}.json", "benchmark/results/{{current}}.json", "benchmark/comparison.md")'
    cat benchmark/comparison.md
