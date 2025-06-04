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
