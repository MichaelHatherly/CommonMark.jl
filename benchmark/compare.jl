# Benchmark comparison script
# Generates markdown report comparing two benchmark results

import JSON3
import Printf: @sprintf

function load_results(path)
    JSON3.read(read(path, String))
end

function format_time(ns)
    if ns < 1_000
        @sprintf("%.1f ns", ns)
    elseif ns < 1_000_000
        @sprintf("%.2f μs", ns / 1_000)
    elseif ns < 1_000_000_000
        @sprintf("%.2f ms", ns / 1_000_000)
    else
        @sprintf("%.2f s", ns / 1_000_000_000)
    end
end

function format_memory(bytes)
    if bytes < 1024
        @sprintf("%d B", bytes)
    elseif bytes < 1024^2
        @sprintf("%.1f KiB", bytes / 1024)
    elseif bytes < 1024^3
        @sprintf("%.1f MiB", bytes / 1024^2)
    else
        @sprintf("%.1f GiB", bytes / 1024^3)
    end
end

function format_change(baseline, current)
    if baseline == 0
        return "N/A"
    end
    ratio = current / baseline
    pct = (ratio - 1) * 100
    if abs(pct) < 1
        "~"
    elseif pct > 0
        @sprintf("+%.1f%%", pct)
    else
        @sprintf("%.1f%%", pct)
    end
end

function status_emoji(baseline, current; lower_is_better = true)
    if baseline == 0
        return "⚪"
    end
    ratio = current / baseline
    threshold_good = lower_is_better ? 0.95 : 1.05
    threshold_bad = lower_is_better ? 1.05 : 0.95

    if lower_is_better
        ratio < threshold_good ? "🟢" : ratio > threshold_bad ? "🔴" : "⚪"
    else
        ratio > threshold_good ? "🟢" : ratio < threshold_bad ? "🔴" : "⚪"
    end
end

function compare_and_report(baseline_path, current_path, output_path)
    baseline = load_results(baseline_path)
    current = load_results(current_path)

    base_benchmarks = baseline.benchmarks
    curr_benchmarks = current.benchmarks

    # Collect all benchmark names
    all_names = union(keys(base_benchmarks), keys(curr_benchmarks))
    sorted_names = sort(collect(all_names))

    io = IOBuffer()

    println(io, "## Benchmark Comparison")
    println(io)
    println(
        io,
        "**Baseline:** `$(get(get(baseline, :git, Dict()), :commit, "unknown")[1:min(7,end)])`",
    )
    println(
        io,
        "**Current:** `$(get(get(current, :git, Dict()), :commit, "unknown")[1:min(7,end)])`",
    )
    println(io)

    # Summary table
    println(io, "### Summary")
    println(io)
    println(
        io,
        "| Benchmark | Base Time | Cur Time | Δ | Base Mem | Cur Mem | Δ | Base Alloc | Cur Alloc | Δ | Status |",
    )
    println(
        io,
        "|-----------|-----------|----------|---|----------|---------|---|------------|-----------|---|--------|",
    )

    regressions = String[]
    improvements = String[]

    for name in sorted_names
        base = get(base_benchmarks, Symbol(name), nothing)
        curr = get(curr_benchmarks, Symbol(name), nothing)

        if base === nothing || curr === nothing
            println(io, "| $name | - | - | - | ⚪ new/removed |")
            continue
        end

        base_time = base.time_ns.median
        curr_time = curr.time_ns.median
        base_mem = base.memory_bytes
        curr_mem = curr.memory_bytes
        base_alloc = base.allocations
        curr_alloc = curr.allocations

        time_change = format_change(base_time, curr_time)
        mem_change = format_change(base_mem, curr_mem)
        alloc_change = format_change(base_alloc, curr_alloc)

        status = status_emoji(base_time, curr_time)

        # Track significant changes
        if base_time > 0
            ratio = curr_time / base_time
            if ratio > 1.10
                push!(
                    regressions,
                    "$name: $(format_time(base_time)) → $(format_time(curr_time)) ($time_change)",
                )
            elseif ratio < 0.90
                push!(
                    improvements,
                    "$name: $(format_time(base_time)) → $(format_time(curr_time)) ($time_change)",
                )
            end
        end

        println(
            io,
            "| $name | $(format_time(base_time)) | $(format_time(curr_time)) | $time_change | $(format_memory(base_mem)) | $(format_memory(curr_mem)) | $mem_change | $base_alloc | $curr_alloc | $alloc_change | $status |",
        )
    end

    println(io)

    # Highlight significant changes
    if !isempty(regressions)
        println(io, "### ⚠️ Regressions (>10%)")
        println(io)
        for r in regressions
            println(io, "- $r")
        end
        println(io)
    end

    if !isempty(improvements)
        println(io, "### 🎉 Improvements (>10%)")
        println(io)
        for i in improvements
            println(io, "- $i")
        end
        println(io)
    end

    # Legend
    println(io, "<details>")
    println(io, "<summary>Legend</summary>")
    println(io)
    println(io, "- 🟢 Improved (>5%)")
    println(io, "- 🔴 Regressed (>5%)")
    println(io, "- ⚪ No significant change")
    println(io)
    println(io, "</details>")

    result = String(take!(io))
    write(output_path, result)
    println(result)
    println("Comparison written to: $output_path")
    result
end
