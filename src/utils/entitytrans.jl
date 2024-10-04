#=
# Generated data:

import JSON
ENTITY_DATA = JSON.Parser.parsefile(joinpath(@__DIR__, "src", "utils", "entities.json"))
open(joinpath(@__DIR__, "src", "utils", "entities.jl"), "w") do io
    print(io, "const ENTITY_DATA = Dict(")
    for k in sort(collect(keys(ENTITY_DATA)))
        v = ENTITY_DATA[k]
        print(io, repr(k))
        print(io, "=>")

        print(io, "Dict(")

        print(io, repr("codepoints"))
        print(io, "=>")
        print(io, repr(identity.(v["codepoints"])))
        print(io, ",")

        print(io, repr("characters"))
        print(io, "=>")
        print(io, repr(v["characters"]))

        print(io, "),")
    end
    print(io, ")")
end
=#
include("entities.jl")

function HTMLunescape(s)
    @assert startswith(s, '&')
    if startswith(s, "&#")
        num = if startswith(s, "&#X") || startswith(s, "&#x")
            Base.parse(UInt32, s[4:end-1]; base = 16)
        else
            Base.parse(UInt32, s[3:end-1])
        end
        num == 0 && return "\uFFFD"
        try
            return string(Char(num))
        catch err
            err isa Base.CodePointError || rethrow(err)
            return "\uFFFD"
        end
    else
        haskey(ENTITY_DATA, s) || return s
        return ENTITY_DATA[s]["characters"]
    end
end
