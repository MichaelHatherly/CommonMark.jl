update:
    julia --project=. -e 'import Pkg; Pkg.update()'
    julia --project=.ci -e 'import Pkg; Pkg.update()'
    julia --project=.format -e 'import Pkg; Pkg.update()'

format:
    julia --project=.format .format/format.jl

changelog:
    julia --project=.ci .ci/changelog.jl
