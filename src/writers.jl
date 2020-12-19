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
    # Create an environment that is the merged result of taking all the
    # available environments and recursively merging them from bottom to top.
    env = recursive_merge(
        default_env(),
        get(Dict{String,Any}, ctx, :env),
        frontmatter(ast),
        ast.meta,
    )
    return Fmt{Ext, F, I}(fn, io, env, Dict{Symbol,Any}())
end

#
# Dict-like interface for the `.state` field of `Fmt` objects.
#

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
    # When writing directly to a file path as the output destination we make
    # the file name available within the formatter's `.env`.
    ast.meta["outputfile"] = file
    open(io -> fmt(fn, io, ast, Ext; ctx...), file, "w")
end

# Main driver method for formatting. Iterates over an `ast` and formats it
# using the provided `f::Fmt`. Runs a `before` and `after` hook prior and post
# iteration, as well as ones before and after each node is inspected.
function fmt(f::Fmt, ast::Node; setup=true, cleanup=true)
    setup && before(f, ast)
    for (node, enter) in ast
        before(f, node, enter)
        fmt(f, node, enter)
        after(f, node, enter)
    end
    cleanup && after(f, ast)
    return nothing
end

# Not inlined since `node.t` is not type-stable so we introduce a function
# barrier here to isolate the dynamic dispatch.
@noinline fmt(f::Fmt, node::Node, enter::Bool) = f.fn(node.t, f, node, enter)

"""
    before(fmt, ast)

Run prior to iterating over each element of the `ast`. Used for setting up the
`fmt` object for specific formats.
"""
before(::Fmt, ::Node) = nothing

"""
    before(fmt, node, enter)

Run prior to calling `fmt` on each `node`.
"""
before(::Fmt, ::Node, ::Bool) = nothing

"""
    after(fmt, ast)

Run once iteration of the `ast` is complete. Used for finalisation actions
needed for a `fmt` object.
"""
after(::Fmt, ::Node) = nothing

"""
    after(fmt, node, enter)

Run after each `fmt` call on each `node`.
"""
after(::Fmt, ::Node, ::Bool) = nothing

#
# `show` interface.
#

for mime in ["text/ast", "text/html", "text/latex", "text/markdown", "text/plain", "application/x-ipynb+json"]
    @eval Base.show(io::IO, m::$(MIME{Symbol(mime)}), ast::Node) = fmt(io, m, ast)
end

"""
    fmt(io, mime, ast)

A shim method for hooking into the `Base.show` display system. This method is
called by the defined `show` methods. To pass in the `ctx` and `Ext` arguments
that are natively supported by the normal `fmt` definitions that must be packed
into an `IOContext` object which is then passed to `show`.
"""
fmt(io::IO, m::MIME, ast::Node) = fmt(mimefunc(m), io, ast, get(io, :Ext, Any); get(io, :ctx, NamedTuple())...)

"""
    mimefunc(mime)

Converts a `mime` object into the required `Function` used to actually format
an AST.
"""
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

#
# Template support
#

# Support for using "templates" with the various output functions is controlled
# by overloading the `fmt(f::Fmt, ast::Node)` method with a custom `Ext` type
# parameter.
#
# ```julia
# using CommonMark, Mustache
#
# abstract type Templated end
#
# function CommonMark.fmt(f::Fmt{Templated}, ast::Node)
#     f.env["body"] = f.fn(ast, supertype(Templated); env = f.env)
#     template = read(f.env["template"], String)
#     Mustache.render(f.io, template, f.env)
# end
# ```
#
# The use of `supertype(Templated)` here is important since otherwise dispatch
# will keep calling this same definition. By dispatching to `Any` instead we
# "unpeal" the extension layers. To support extensions to other parts of the
# formatting pipeline `Templated` would need to be a subtype of any other
# extensions, such as syntax highlighting and smartlinks types.

#
# Smart links and other formatting customisation
#

# Similar to the template extension support provided by defining a custom
# extension type and formatting methods other parts of the formatting pipeline
# can be extended by defining methods that target specific `Node` types. To
# define a custom link extension that changes how all links are rendered we can
# use the following:
#
# ```julia
# using CommonMark
# const CM = CommonMark
#
# abstract type LinkExtension end
#
# function CM.html(::CM.Link, ::CM.Fmt{LinkExtension}, ::CM.Node, ::Bool)
#     # ...
# end
# ```
#
# This will intercept all `html` rendering of `Link` nodes within an AST.
#
# ```julia
# html(ast, LinkExtension)
# ```
#
# To make use of templating and other extensions at the same time you must define
# the `TemplateExtension` as a subtype of the `LinkExtension`.
