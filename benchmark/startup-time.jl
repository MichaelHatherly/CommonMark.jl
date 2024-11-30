
# # Startup latency
#
# About this file
# - It was created in [a PR to add precompilation][1] to CommonMark.jl.
# - The `.md` version of this file is auto-generated (see `benchmark/README.md`).
#   Edit the underlying `.jl` instead.
#
# [1]: https://github.com/MichaelHatherly/CommonMark.jl/pull/59


# ## Setup

using Pkg
Pkg.activate(@__DIR__)
## ↪ Note that this is executed in `benchmark/results/`,
##   not in `benchmark/` (where this src .jl file lives)
#--

parentdir = dirname  # (Alias of a built-in function)
benchmark_dir = parentdir(@__DIR__)
reporoot = parentdir(benchmark_dir)

srcfile = joinpath(reporoot, "src", "CommonMark.jl")
touch(srcfile)  # To trigger full re-pre-compilation

testfile = joinpath(reporoot, "test", "integration.md")
teststr = read(testfile, String)



# ## Results


# ### Precompilation time
#
Pkg.precompile("CommonMark")
## (No need for @time, Pkg prints time itself)


# ### Package load time
#
@time using CommonMark
#src   # This is only after a re-precompilation.
#src   #
#src   # Subsequent package load times in new julia sessions:
#src   cmd = `julia --startup-file=no --project=$(@__DIR__) -E "@time using CommonMark"`
#src   buf = IOBuffer()
#src   run(pipeline(cmd, stdout = buf))
#src   String(take!(buf))
#src   # Hm, still slow.
#src   # Let's try again.
#src   run(pipeline(cmd, stdout = buf))
#src   String(take!(buf))
#
#src   I'm confused. The above keeps showing 7.8 seconds.


# ### First function call times
#
@time parser = Parser();
#--
@time ast = parser(teststr);
#--
@time CommonMark.html(ast);


# ## Runtime environment
#
using InteractiveUtils
versioninfo()
