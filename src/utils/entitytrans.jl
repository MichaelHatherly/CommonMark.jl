include("entities.jl")

function generate_entities(fileparser; input="entities.json", output="entities.jl")
    cd(@__DIR__) do
        open(output, "w") do io
            println(io, "const ENTITY_DATA = Dict{String,String}(")
            for (k, v) in sort!(collect(fileparser(input)); by = first)
                println(io, "    ", repr(k), " => ", repr(v["characters"]), ",")
            end
            println(io, ")")
        end
    end
end

function HTMLunescape(s)
    @assert startswith(s, '&')
    if startswith(s, "&#")
        num = if startswith(s, "&#X") || startswith(s, "&#x")
            Base.parse(UInt32, s[4:end-1]; base=16)
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
        return get(ENTITY_DATA, s, s)
    end
end
