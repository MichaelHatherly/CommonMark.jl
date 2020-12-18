#
# `fmt` interface.
#

"""
    Fmt{Ext}

Formatter object that controls how an AST is displayed. `Ext` is an "extension"
type exposed to users for customising the display of the AST.
"""
struct Fmt{Ext, F, I<:IO} <: IO
    fn::F
    io::I
    env::Dict{String,Any}
    state::Dict{Symbol,Any}
end

function Fmt(fn::F, io::I, ast::Node, Ext, ctx) where {F, I}
    env = recursive_merge(
        default_env(),
        get(Dict{String,Any}, ctx, :env),
        frontmatter(ast),
        ast.meta,
    )
    return Fmt{Ext, F, I}(fn, io, env, Dict{Symbol,Any}())
end

Base.getindex(f::Fmt, s::Symbol) = f.state[s]
Base.setindex!(f::Fmt, value, s::Symbol) = f.state[s] = value
Base.get(f::Fmt, s::Symbol, default) = get(f.state, s, default)
Base.get!(f::Fmt, s::Symbol, default) = get!(f.state, s, default)
Base.get(default::Base.Callable, f::Fmt, s::Symbol) = get(default, f.state, s)
Base.get!(default::Base.Callable, f::Fmt, s::Symbol) = get!(default, f.state, s)

"""
    fmt(fn::Function, [io::IO | file::String], ast::Node, [Ext]; ctx...)

Write `ast` to `io` or `file` using `fn` in context `ctx`. When neither `io`
not `file` are provided then return a `String` of the resulting formatting.

The optional `Ext` argument can be passed to allow customisation of the
formatting pipeline by overloading individual formatting methods with
`Fmt{Ext}` definitions.
"""
function fmt end

fmt(fn, io::IO, ast::Node, Ext=Any; ctx...) = fmt(Fmt(fn, io, ast, Ext, ctx), ast)

function fmt(fn, ast::Node, Ext=Any; ctx...)
    io = IOBuffer()
    fmt(fn, io, ast, Ext; ctx...)
    return String(take!(io))
end

function fmt(fn, file::AbstractString, ast::Node, Ext=Any; ctx...)
    ast.meta["outputfile"] = file
    open(io -> fmt(fn, io, ast, Ext; ctx...), file, "w")
end

function fmt(f::Fmt, ast::Node)
    before(f, ast)
    for (node, enter) in ast
        before(f, node, enter)
        fmt(f, node, enter)
        after(f, node, enter)
    end
    after(f, ast)
    return nothing
end

@noinline fmt(f::Fmt, node::Node, enter::Bool) = f.fn(node.t, f, node, enter)

before(::Fmt, ::Node) = nothing
before(::Fmt, ::Node, ::Bool) = nothing
after(::Fmt, ::Node) = nothing
after(::Fmt, ::Node, ::Bool) = nothing

#
# `show` interface.
#

for mime in ["text/ast", "text/html", "text/latex", "text/markdown", "text/plain", "application/x-ipynb+json"]
    @eval Base.show(io::IO, m::$(MIME{Symbol(mime)}), ast::Node) = fmt(io, m, ast)
end

fmt(io::IO, m::MIME, ast::Node) = fmt(mimefunc(m), io, ast, get(io, :Ext, Any); get(io, :ctx, NamedTuple())...)

mimefunc(::MIME) = throw(ArgumentError("unsupported MIME type `$MIME`."))

#
# utilities
#

include("writers/utilities.jl")

#
# formats
#

include("writers/ast.jl")
include("writers/html.jl")
include("writers/latex.jl")
include("writers/markdown.jl")
include("writers/notebook.jl")
include("writers/term.jl")

#
# environments
#

default_env() = Dict{String,Any}(
    "authors" => [],
    "curdir" => pwd(),
    "title" => "",
    "subtitle" => "",
    "abstract" => "",
    "keywords" => [],
    "lang" => "en",
    "latex" => Dict{String,Any}(
        "documentclass" => "article",
    ),
)

recursive_merge(ds::AbstractDict...) = merge(recursive_merge, ds...)
recursive_merge(args...) = last(args)
