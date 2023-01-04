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
  1.332231 seconds (2.59 M allocations: 164.960 MiB, 10.58% gc time, 58.20% compilation time)
````

````julia
@time using CommonMark
````
````
  0.823340 seconds (781.39 k allocations: 47.084 MiB, 2.44% gc time, 0.96% compilation time)
````

````julia
@time parser = Parser();
````
````
  0.784270 seconds (21.06 k allocations: 1.009 MiB, 99.92% compilation time)
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
  1.239548 seconds (163.25 k allocations: 8.134 MiB, 99.91% compilation time)
````

````julia
@time CommonMark.html(ast);
````
````
  0.235873 seconds (31.45 k allocations: 1.572 MiB, 99.81% compilation time)
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

