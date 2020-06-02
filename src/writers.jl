mutable struct Writer{F, I <: IO}
    format::F
    buffer::I
    last::Char
    enabled::Bool
    context::Dict{Symbol, Any}
end
Writer(format, buffer=IOBuffer()) = Writer(format, buffer, '\n', true, Dict{Symbol, Any}())

Base.get(w::Writer, k::Symbol, default) = get(w.context, k, default)
Base.get!(f, w::Writer, k::Symbol) = get!(f, w.context, k)

function literal(r::Writer, args...)
    if r.enabled
        for arg in args
            write(r.buffer, arg)
            r.last = isempty(arg) ? r.last : last(arg)
        end
    end
    return nothing
end

function cr(r::Writer)
    if r.enabled && r.last != '\n'
        r.last = '\n'
        write(r.buffer, '\n')
    end
    return nothing
end

include("writers/html.jl")
include("writers/latex.jl")
include("writers/term.jl")
include("writers/markdown.jl")
include("writers/notebook.jl")

function ast_dump(io::IO, ast::Node)
    indent = -2
    for (node, enter) in ast
        T = typeof(node.t).name.name
        if is_container(node)
            indent += enter ? 2 : -2
            enter && printstyled(io, ' '^indent, T, "\n"; color=:blue)
        else
            printstyled(io, ' '^(indent + 2), T, "\n"; bold=true, color=:red)
            println(io, ' '^(indent + 4), repr(node.literal))
        end
    end
end
ast_dump(ast::Node) = ast_dump(stdout, ast)
