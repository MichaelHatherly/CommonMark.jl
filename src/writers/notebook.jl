# Public.

function Base.show(
    io::IO,
    ::MIME"application/x-ipynb+json",
    ast::Node,
    env = Dict{String,Any}(),
)
    json = Dict(
        "cells" => [],
        "metadata" => Dict(
            "kernelspec" => Dict(
                "display_name" => "Julia $VERSION",
                "language" => "julia",
                "name" => "julia-$VERSION",
            ),
            "language_info" => Dict(
                "file_extension" => ".jl",
                "mimetype" => "application/julia",
                "name" => "julia",
                "version" => "$VERSION",
            ),
        ),
        "nbformat" => 4,
        "nbformat_minor" => 4,
    )
    for (node, enter) in ast
        write_notebook(json, node, enter, env)
    end
    _json(io, json)
    return nothing
end
"""
    notebook(ast::Node) -> String
    notebook(filename::String, ast::Node)
    notebook(io::IO, ast::Node)

Render a CommonMark AST to a Jupyter notebook (`.ipynb` format).

Code blocks are converted to code cells, and other content becomes
Markdown cells.

# Examples

```julia
p = Parser()
ast = p("# Title\\n\\n```julia\\nprintln(\\"Hello\\")\\n```")
notebook("output.ipynb", ast)
```
"""
notebook(args...) = writer(MIME"application/x-ipynb+json"(), args...)

# Internal.

mime_to_str(::MIME"application/x-ipynb+json") = "notebook"

function write_notebook(json, node, enter, env)
    split_lines = str -> collect(eachline(IOBuffer(str); keep = true))
    if !isnull(node) &&
       node.t isa CodeBlock &&
       node.parent.t isa Document &&
       node.t.info == "julia"
        # Toplevel Julia codeblocks become code cells.
        cell = Dict(
            "cell_type" => "code",
            "execution_count" => nothing,
            "metadata" => Dict(),
            "source" => split_lines(rstrip(node.literal, '\n')),
            "outputs" => [],
        )
        push!(json["cells"], cell)
    elseif !isnull(node.parent) && node.parent.t isa Document && enter
        # All other toplevel turns into markdown cells.
        cells = json["cells"]
        if !isempty(cells) && cells[end]["cell_type"] == "markdown"
            # When we already have a current markdown cell then append content.
            append!(cells[end]["source"], split_lines(markdown(node, env)))
        else
            # ... otherwise open a new cell.
            cell = Dict(
                "cell_type" => "markdown",
                "metadata" => Dict(),
                "source" => split_lines(markdown(node)),
            )
            push!(cells, cell)
        end
    end
end

struct StringContext{T<:IO} <: IO
    io::T
end

Base.write(io::StringContext, byte::UInt8) = write(io.io, ESCAPED_ARRAY[byte+1])

function _json(io::IO, str::AbstractString)
    write(io, STRING_DELIM)
    print(StringContext(io), str)
    write(io, STRING_DELIM)
end
_json(io::IO, ::Nothing) = print(io, "null")
_json(io::IO, num::Real) = print(io, num)

function _json(io::IO, dict::AbstractDict)
    print(io, "{")
    for (nth, (key, value)) in enumerate(dict)
        if nth > 1
            print(io, ",")
        end
        _json(io, key)
        print(io, ":")
        _json(io, value)
    end
    print(io, "}")
end

function _json(io::IO, vec::AbstractVector)
    print(io, "[")
    for (nth, value) in enumerate(vec)
        if nth > 1
            print(io, ",")
        end
        _json(io, value)
    end
    print(io, "]")
end

# The following bytes have significant meaning in JSON
const BACKSPACE = UInt8('\b')
const TAB = UInt8('\t')
const NEWLINE = UInt8('\n')
const FORM_FEED = UInt8('\f')
const RETURN = UInt8('\r')
const SPACE = UInt8(' ')
const STRING_DELIM = UInt8('"')
const PLUS_SIGN = UInt8('+')
const DELIMITER = UInt8(',')
const MINUS_SIGN = UInt8('-')
const DECIMAL_POINT = UInt8('.')
const SOLIDUS = UInt8('/')
const DIGIT_ZERO = UInt8('0')
const DIGIT_NINE = UInt8('9')
const SEPARATOR = UInt8(':')
const LATIN_UPPER_A = UInt8('A')
const LATIN_UPPER_E = UInt8('E')
const LATIN_UPPER_F = UInt8('F')
const LATIN_UPPER_I = UInt8('I')
const LATIN_UPPER_N = UInt8('N')
const ARRAY_BEGIN = UInt8('[')
const BACKSLASH = UInt8('\\')
const ARRAY_END = UInt8(']')
const LATIN_A = UInt8('a')
const LATIN_B = UInt8('b')
const LATIN_E = UInt8('e')
const LATIN_F = UInt8('f')
const LATIN_I = UInt8('i')
const LATIN_L = UInt8('l')
const LATIN_N = UInt8('n')
const LATIN_R = UInt8('r')
const LATIN_S = UInt8('s')
const LATIN_T = UInt8('t')
const LATIN_U = UInt8('u')
const LATIN_Y = UInt8('y')
const OBJECT_BEGIN = UInt8('{')
const OBJECT_END = UInt8('}')

const ESCAPES = Dict(
    STRING_DELIM => STRING_DELIM,
    BACKSLASH => BACKSLASH,
    SOLIDUS => SOLIDUS,
    LATIN_B => BACKSPACE,
    LATIN_F => FORM_FEED,
    LATIN_N => NEWLINE,
    LATIN_R => RETURN,
    LATIN_T => TAB,
)

const REVERSE_ESCAPES = Dict(reverse(p) for p in ESCAPES)
const ESCAPED_ARRAY = Vector{Vector{UInt8}}(undef, 256)
for c = 0x00:0xFF
    ESCAPED_ARRAY[c+1] = if c == SOLIDUS
        [SOLIDUS]  # don't escape this one
    elseif c ≥ 0x80
        [c]  # UTF-8 character copied verbatim
    elseif haskey(REVERSE_ESCAPES, c)
        [BACKSLASH, REVERSE_ESCAPES[c]]
    elseif iscntrl(Char(c)) || !isprint(Char(c))
        UInt8[BACKSLASH, LATIN_U, string(c, base = 16, pad = 4)...]
    else
        [c]
    end
end
