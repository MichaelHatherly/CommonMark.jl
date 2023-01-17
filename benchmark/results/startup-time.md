# Startup latency

About this file
- It was created in [a PR to add precompilation][1] to CommonMark.jl.
- The `.md` version of this file is auto-generated (see `benchmark/README.md`).
  Edit the underlying `.jl` instead.

[1]: https://github.com/MichaelHatherly/CommonMark.jl/pull/59

## Setup

````julia
using Pkg
Pkg.activate(@__DIR__)
# ↪ Note that this is executed in `benchmark/results/`,
#   not in `benchmark/` (where this src .jl file lives)
````
````
  Activating project at `C:\Users\tfiers\.julia\dev\CommonMark\benchmark\results`
````

````julia
parentdir = dirname  # (Alias of a built-in function)
benchmark_dir = parentdir(@__DIR__)
reporoot = parentdir(benchmark_dir)

srcfile = joinpath(reporoot, "src", "CommonMark.jl")
touch(srcfile)  # To trigger full re-pre-compilation

testfile = joinpath(reporoot, "test", "integration.md")
teststr = read(testfile, String)
````
````
"---\nfront: matter\n---\n\n# Integration Tests\n\n!!! danger\n\n    Warning [@cite] admonition[^1]...\n\n    ```math\n    maths\n    ```\n\n    {.class}\n    [^1]: 1\n\n        footnote content\n\n!!! warning\n\n    \"Warning\" [@cite] admonition[^2].\n\n    | table |\n    | - |\n    | content |\n\n    [^2]: 2\n\n!!! info\n\n    'Tip' [@cite] 'admonition'[^3].\n\n    [^3]: ``x``\n\n!!! note\n\n    Note [@cite] \"admonition\"[^4].\n\n    ```{=latex}\n    latex\n    ```\n\n    [^4]: 4\n\n!!! tip\n\n    Tip [@cite] admonition[^5].\n\n    [^5]: 5\n\n{#refs}\n## References\n\n"
````

## Results

### Precompilation time

````julia
Pkg.precompile("CommonMark")
# (No need for @time, Pkg prints time itself)
````
````
Precompiling project...
[32m  ✓ [39mCommonMark
  1 dependency successfully precompiled in 7 seconds. 5 already precompiled.
````

### Package load time

````julia
@time using CommonMark
````
````
  7.387662 seconds (736.17 k allocations: 43.326 MiB, 0.26% gc time, 0.34% compilation time)
````

### First function call times

````julia
@time parser = Parser();
````
````
  0.753673 seconds (21.06 k allocations: 1.009 MiB, 99.93% compilation time)
````

````julia
@time ast = parser(teststr);
````
````
  1.462268 seconds (558.29 k allocations: 27.821 MiB, 1.38% gc time, 99.93% compilation time)
````

````julia
@time CommonMark.html(ast);
````
````
  0.270778 seconds (94.01 k allocations: 4.818 MiB, 99.81% compilation time)
````

## Runtime environment

````julia
using InteractiveUtils
versioninfo()
````
````
Julia Version 1.8.1
Commit afb6c60d69 (2022-09-06 15:09 UTC)
Platform Info:
  OS: Windows (x86_64-w64-mingw32)
  CPU: 8 × Intel(R) Core(TM) i7-10510U CPU @ 1.80GHz
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-13.0.1 (ORCJIT, skylake)
  Threads: 7 on 8 virtual cores
Environment:
  JULIA_DEBUG = Literate
  JULIA_EDITOR = code.cmd
  JULIA_NUM_THREADS = 7
````

