#
# `ast`
#

"""
    ast([io | file], ast, Extension; env)

Display the given AST as a pretty-printed tree diagram showing the parsed
structure of the data.
"""
ast(args...; kws...) = fmt(ast, args...; kws...)

mimefunc(::MIME"text/ast") = ast

function before(f::Fmt{Ext, T"ast"}, ast::Node) where Ext
    f[:indent] = -2
    return nothing
end

function ast(t, f::Fmt, node, enter)
    T = typeof(t)
    if is_container(node)
        f[:indent] += enter ? 2 : -2
        enter && printstyled(f.io, ' '^f[:indent], T, "\n"; color = :blue)
    else
        printstyled(f.io, ' '^(f[:indent] + 2), T, "\n"; bold = true, color = :red)
        println(f.io, ' '^(f[:indent] + 4), repr(node.literal))
    end
    return nothing
end
