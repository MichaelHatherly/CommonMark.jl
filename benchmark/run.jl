# Benchmark runner for CI
#
# Usage: julia --project=benchmark benchmark/run.jl [output.json]
#
# Outputs JSON with benchmark results and metadata for historical tracking.

import BenchmarkTools
import JSON3
import Dates

include("benchmarks.jl")

function get_git_info()
    commit = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    branch = try
        strip(read(`git rev-parse --abbrev-ref HEAD`, String))
    catch
        "unknown"
    end
    dirty = try
        !isempty(read(`git status --porcelain`, String))
    catch
        false
    end
    (commit = commit, branch = branch, dirty = dirty)
end

function extract_trial_stats(trial::BenchmarkTools.Trial)
    t = trial.times
    m = trial.memory
    a = trial.allocs
    gc = trial.gctimes
    (
        time_ns = (
            minimum = minimum(t),
            median = BenchmarkTools.median(trial).time,
            mean = BenchmarkTools.mean(trial).time,
            maximum = maximum(t),
            std = length(t) > 1 ? BenchmarkTools.std(trial).time : 0.0,
        ),
        memory_bytes = m,
        allocations = a,
        gc_time_ns = length(gc) > 0 ? sum(gc) / length(gc) : 0.0,
        samples = length(t),
    )
end

function flatten_results(group::BenchmarkTools.BenchmarkGroup, prefix = "")
    results = Dict{String,Any}()
    for (key, value) in group
        full_key = isempty(prefix) ? string(key) : "$(prefix)/$(key)"
        if value isa BenchmarkTools.BenchmarkGroup
            merge!(results, flatten_results(value, full_key))
        elseif value isa BenchmarkTools.Trial
            results[full_key] = extract_trial_stats(value)
        end
    end
    results
end

function run_benchmarks()
    println("Running CommonMark.jl benchmarks...")
    println("Julia version: ", VERSION)
    println()

    # Tune and run
    BenchmarkTools.tune!(SUITE)
    results = BenchmarkTools.run(SUITE, verbose = true)

    # Gather metadata
    git = get_git_info()

    output = Dict(
        "timestamp" => Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SSZ"),
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "arch" => string(Sys.ARCH),
        "cpu_threads" => Sys.CPU_THREADS,
        "git" =>
            Dict("commit" => git.commit, "branch" => git.branch, "dirty" => git.dirty),
        "benchmarks" => flatten_results(results),
    )

    output
end

function main()
    output_file = length(ARGS) >= 1 ? ARGS[1] : nothing

    results = run_benchmarks()

    if output_file !== nothing
        mkpath(dirname(output_file))
        open(output_file, "w") do io
            JSON3.pretty(io, results)
        end
        println("\nResults written to: $output_file")
    else
        println("\n", "="^60)
        println("RESULTS")
        println("="^60)
        JSON3.pretty(stdout, results)
        println()
    end

    results
end

main()
