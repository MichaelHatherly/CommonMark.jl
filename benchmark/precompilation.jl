
# # Benchmarking the effect of precompilation
#
# [Relevant PR](https://github.com/MichaelHatherly/CommonMark.jl/pull/59)


using Pkg
Pkg.activate(@__DIR__)
## ↪ Note that this is executed in `benchmark/results/`,
##   not in `benchmark/` (where this src .jl file lives)
#--------------------------------


@time Pkg.precompile("CommonMark")
#--------------------------------


@time using CommonMark
#--------------------------------


@time parser = Parser();
#--------------------------------


parentdir = dirname  # (alias a built-in function)
benchmark_dir = parentdir(@__DIR__)
reporoot = parentdir(benchmark_dir)
testfile = joinpath(reporoot, "test", "integration.md")
teststr = read(testfile, String)
#--------------------------------

@time ast = parser(teststr);
#--------------------------------


@time CommonMark.html(ast);
#--------------------------------


using InteractiveUtils
versioninfo()
#--------------------------------
