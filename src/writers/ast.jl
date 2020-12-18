#
# `ast`
#

"""
    ast([io | file], ast, Extension; env)

Display the given AST as a pretty-printed tree diagram showing the parsed
structure of the data.
"""
ast(args...; kws...) = fmt(ast, args...; kws...)

function ast(t, f::Fmt, node, enter)
    indent = get!(f.state, :indent, -2)
    T = typeof(t)
    if is_container(node)
        indent = (f.state[:indent] += enter ? 2 : -2)
        enter && printstyled(f.io, ' '^indent, T, "\n"; color = :blue)
    else
        printstyled(f.io, ' '^(indent + 2), T, "\n"; bold = true, color = :red)
        println(f.io, ' '^(indent + 4), repr(node.literal))
    end
    return nothing
end
