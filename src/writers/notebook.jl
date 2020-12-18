#
# `notebook`
#

"""
    notebook([io | file], ast, Extension; env)

Write `ast` to a Jupyter notebook format.
"""
notebook(args...; kws...) = fmt(notebook, args...; kws...)

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

function after(f::Fmt{Ext,T"notebook"}, ast::Node) where Ext
    JSON.Writer.print(f.io, f.state[:json])
    return nothing
end
