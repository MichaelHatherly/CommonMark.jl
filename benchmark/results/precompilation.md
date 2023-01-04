# Benchmarking the effect of precompilation

[Relevant PR](https://github.com/MichaelHatherly/CommonMark.jl/pull/59)

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
@time Pkg.precompile("CommonMark")
````
````
Precompiling project...
[32m  ✓ [39mCommonMark
  1 dependency successfully precompiled in 7 seconds. 5 already precompiled.
  7.949459 seconds (2.66 M allocations: 169.047 MiB, 1.79% gc time, 10.02% compilation time)
````

````julia
@time using CommonMark
````
````
  7.320974 seconds (736.18 k allocations: 43.349 MiB, 0.26% gc time, 0.34% compilation time)
````

````julia
@time parser = Parser();
````
````
  0.723616 seconds (21.06 k allocations: 1.009 MiB, 99.92% compilation time)
````

````julia
parentdir = dirname  # (alias a built-in function)
benchmark_dir = parentdir(@__DIR__)
reporoot = parentdir(benchmark_dir)
testfile = joinpath(reporoot, "test", "integration.md")
teststr = read(testfile, String)
````
````
"---\nfront: matter\n---\n\n# Integration Tests\n\n!!! danger\n\n    Warning [@cite] admonition[^1]...\n\n    ```math\n    maths\n    ```\n\n    {.class}\n    [^1]: 1\n\n        footnote content\n\n!!! warning\n\n    \"Warning\" [@cite] admonition[^2].\n\n    | table |\n    | - |\n    | content |\n\n    [^2]: 2\n\n!!! info\n\n    'Tip' [@cite] 'admonition'[^3].\n\n    [^3]: ``x``\n\n!!! note\n\n    Note [@cite] \"admonition\"[^4].\n\n    ```{=latex}\n    latex\n    ```\n\n    [^4]: 4\n\n!!! tip\n\n    Tip [@cite] admonition[^5].\n\n    [^5]: 5\n\n{#refs}\n## References\n\n"
````

````julia
@time ast = parser(teststr);
````
````
  1.425825 seconds (558.29 k allocations: 27.806 MiB, 1.18% gc time, 99.93% compilation time)
````

````julia
@time CommonMark.html(ast);
````
````
  0.270362 seconds (94.01 k allocations: 4.821 MiB, 96.21% compilation time)
````

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
  JULIA_EDITOR = code.cmd
  JULIA_NUM_THREADS = 7
````

