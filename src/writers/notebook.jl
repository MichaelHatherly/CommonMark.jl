#
# `notebook`
#

"""
    notebook([io | file], ast, Extension; env)

Write `ast` to a Jupyter notebook format.
"""
notebook(args...; kws...) = fmt(notebook, args...; kws...)

mimefunc(::MIME"application/x-ipynb+json") = notebook

function notebook(t, f::Fmt{Ext}, node, enter) where Ext
    split_lines = str -> collect(eachline(IOBuffer(str); keep=true))
    cells = f.state[:json]["cells"]
    if !isnull(node) && node.t isa CodeBlock && node.parent.t isa Document && node.t.info == "julia"
        # Toplevel Julia codeblocks become code cells.
        cell = Dict(
            "cell_type" => "code",
            "execution_count" => nothing,
            "metadata" => Dict(),
            "source" => split_lines(rstrip(node.literal, '\n')),
            "outputs" => [],
        )
        push!(cells, cell)
    elseif !isnull(node.parent) && node.parent.t isa Document && enter
        # All other toplevel turns into markdown cells.
        md = split_lines(markdown(node, Ext; env = f.env))
        if !isempty(cells) && cells[end]["cell_type"] == "markdown"
            # When we already have a current markdown cell then append content.
            append!(cells[end]["source"], md)
        else
            # ... otherwise open a new cell.
            cell = Dict(
                "cell_type" => "markdown",
                "metadata" => Dict(),
                "source" => md,
            )
            push!(cells, cell)
        end
    end
    return nothing
end

function before(f::Fmt{Ext,T"notebook"}, ast::Node) where Ext
    f.state[:json] = Dict(
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
    return nothing
end

function after(f::Fmt{Ext,T"notebook"}, ::Node) where Ext
    mini_json(f.io, f.state[:json])
    return nothing
end

# Mini JSON printer. Sufficient for the restricted datatypes that get used for `notebook`.
function mini_json(io::IO, v::AbstractVector)
    print(io, '[')
    for (nth, item) in enumerate(v)
        nth > 1 && print(io, ',')
        mini_json(io, item)
    end
    print(io, ']')
end
function mini_json(io::IO, d::AbstractDict)
    print(io, '{')
    for (nth, (k, v)) in enumerate(d)
        nth > 1 && print(io, ',')
        mini_json(io, k)
        print(io, ':')
        mini_json(io, v)
    end
    print(io, '}')
end
mini_json(io::IO, s::AbstractString) = show(io, s)
mini_json(io::IO, r::Real) = print(io, r == -Inf ? "-Infinity" : r == Inf ? "Infinity" : isnan(r) ? "NaN" : r)
mini_json(io::IO, ::Nothing) = print(io, "null")
