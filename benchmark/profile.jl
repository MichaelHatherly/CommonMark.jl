# Profile CommonMark parsing to find optimization targets
# Usage: julia --project=benchmark benchmark/profile.jl

using CommonMark
using Profile

const SPEC_MD =
    read(joinpath(@__DIR__, "..", "test", "samples", "cmark", "spec.md"), String)
const PARSER = Parser()

# Warmup
PARSER(SPEC_MD)

# Profile with more iterations for better sampling
Profile.clear()
@profile for _ = 1:100
    PARSER(SPEC_MD)
end

# Write to file
open(joinpath(@__DIR__, "profile.txt"), "w") do io
    println(io, "=== FLAT PROFILE ===\n")
    Profile.print(io, format = :flat, sortedby = :count, mincount = 10)
    println(io, "\n\n=== TREE PROFILE ===\n")
    Profile.print(io, mincount = 10, noisefloor = 2.0)
end

println("Profile written to benchmark/profile.txt")
