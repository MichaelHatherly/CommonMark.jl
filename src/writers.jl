mutable struct Renderer{F, I <: IO}
    format::F
    buffer::I
    last::Char
end
Renderer(format, buffer=IOBuffer()) = Renderer(format, buffer, '\n')

clear_renderer!(r::Renderer{F, IOBuffer}) where F = take!(r.buffer)
clear_renderer!(r::Renderer) = nothing

function render(r::Renderer, ast::Node)
    r.last = '\n'
    clear_renderer!(r)
    for (node, entering) in ast
        render(r, node.t, node, entering)
    end
    return r
end

function literal(r::Renderer, args...)
    for arg in args
        write(r.buffer, arg)
        r.last = isempty(arg) ? r.last : last(arg)
    end
end

function cr(r::Renderer)
    if r.last != '\n'
        r.last = '\n'
        write(r.buffer, '\n')
    end
    return nothing
end

Base.read(r::Renderer{F, IOBuffer}, ::Type{String}) where F =
    Base.read(seekstart(r.buffer), String)

include("writers/html.jl")
include("writers/latex.jl")
include("writers/term.jl")

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
