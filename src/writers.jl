#
# `fmt` interface.
#

"""
    Fmt{Ext, Fn}

Formatter object that controls how an AST is displayed. `Ext` is an "extension"
type exposed to users for customising the display of the AST. `Fn` is the
formatter function type to be called when formatting the AST. `Fn` shouldn't
need to be listed explicitly in most cases.

`Fmt` types don't need to be created manually by users. They are exposed to
users for the purpose of dispatching in method definitions.
"""
struct Fmt{Ext, Fn, I<:IO} <: IO
    fn::Fn
    io::I
    env::Dict{String,Any}
    state::Dict{Symbol,Any}
end

function Fmt(fn::Fn, io::I, ast::Node, Ext; ctx...) where {Fn, I}
    # Create an environment that is the merged result of taking all the
    # available environments and recursively merging them from bottom to top.
    env = recursive_merge(
        default_env(),
        get(Dict{String,Any}, ctx, :env),
        frontmatter(ast),
        ast.meta,
    )
    return Fmt{Ext, Fn, I}(fn, io, env, Dict{Symbol,Any}())
end

Fmt(f::Fmt{Ext, Fn, I}, NewExt) where {Ext, Fn, I} = Fmt{NewExt, Fn, I}(f.fn, f.io, f.env, f.state)

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

fmt(fn, io::IO, ast::Node, Ext=Any; ctx...) = fmt(Fmt(fn, io, ast, Ext; ctx...), ast)

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
# The 'parent' implementation of `html` can be called from within this
# extension by using `invoke(...)` on the unparameterised `Fmt` argument.
#
# To make use of templating and other extensions at the same time you must define
# the `TemplateExtension` as a subtype of the `LinkExtension`.

"""
Root type for template rendering. To make use of templating a user must define
a subtype of `TemplateExtension` as well as implement `renderer` and optionally
`ancestor` if other extensions are expected to be used during templating.

```julia
using CommonMark, Mustache

struct Custom <: CommonMark.TemplateExtension end

CommonMark.renderer(f::CommonMark.Fmt{Custom}, env) = Mustache.render(f.io, env["template"], env)
```

The user, as mentioned above, should implement `ancestor` if they wish to alter
other parts of the formatting pipeline.

```julia
CommonMark.ancestor(::Type{Custom}) = LinkExtension
```

The rendered inner content that will be written to the template is stored in a
field called `"body"` within the `env` `Dict` passed as the second argument to
`renderer`.
"""
abstract type TemplateExtension end

"""
    ancestor(::Type{T})

Defines the "supertype" of a subtype `T` of `TemplateExtension` for the
purposes of dispatching template rendering to the correct methods.

By default this will return `Any` such that it will always result in a useful
formatting pipeline. If you have other defined extensions that form part of
the pipeline then `ancestor` should return that type instead.

```julia
CommonMark.ancestor(::Type{Custom}) = Other
```
"""
ancestor(::Type) = Any

"""
    renderer(f::Fmt{T}, env)

Defines what template renderer implementation is called to fill in a template
provided by the `env`. This method should always be defined for your custom
subtype of `TemplateExtension` otherwise the templating is skipped.

```julia
CommonMark.renderer(f::Fmt{Custom}, env) = render(f.io, env["template"], env)
```

Different formats can define their own renderers by defining the method signatures
more tightly:

```julia
CommonMark.renderer(f::Fmt{Custom, T"html"}, env) = render(f.io, env["html"]["template"], env)
CommonMark.renderer(f::Fmt{Custom, T"latex"}, env) = render(f.io, env["latex"]["template"], env)
```
"""
renderer(f::Fmt, env) = print(f.io, env["body"])

fmt(f::Fmt{T}, ast::Node) where T<:TemplateExtension = renderer(f, recursive_merge(f.env, Dict("body" => fmt(f.fn, ast, ancestor(T)))))
