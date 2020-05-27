# Public

html(io::IO, ast::Node) = render(Writer(HTML(), io), ast)
html(ast::Node) = sprint(html, ast)

latex(io::IO, ast::Node) = render(Writer(LaTeX(), io), ast)
latex(ast::Node) = sprint(latex, ast)

term(io::IO, ast::Node) = render(Writer(Term(), io), ast)
term(ast::Node) = sprint(term, ast)

# Internals

mutable struct Writer{F, I <: IO}
    format::F
    buffer::I
    last::Char
    enabled::Bool
end
Writer(format, buffer=IOBuffer()) = Writer(format, buffer, '\n', true)

Base.show(io::IO, ::Writer{T}) where {T} = print(io, "CommonMark.Writer{$T}(...)")

clear_renderer!(r::Writer{F, IOBuffer}) where F = take!(r.buffer)
clear_renderer!(r::Writer) = nothing

function render(r::Writer, ast::Node)
    r.last = '\n'
    clear_renderer!(r)
    for (node, entering) in ast
        render(r, node.t, node, entering)
    end
    return nothing
end

(r::Writer)(ast::Node) = render(r, ast)
(r::Writer)(ast::Node, ::Type{String}) = String(take!(render(r, ast)))

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

Base.read(r::Writer{F, IOBuffer}, ::Type{String}) where F =
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
