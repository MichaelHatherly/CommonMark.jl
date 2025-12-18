# Quick benchmark for development iteration
# Usage: julia --project=benchmark benchmark/quick.jl

using CommonMark
using BenchmarkTools

const SPEC_MD =
    read(joinpath(@__DIR__, "..", "test", "samples", "cmark", "spec.md"), String)
const PARSER = Parser()

println("Parsing spec.md ($(length(SPEC_MD)) bytes):")
@btime $PARSER($SPEC_MD)

println("\nAllocation details:")
@time PARSER(SPEC_MD)
