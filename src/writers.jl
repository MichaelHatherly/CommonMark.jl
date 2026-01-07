function writer(
    mime,
    file::AbstractString,
    ast::Node,
    env = Dict{String,Any}();
    transform = default_transform,
    kws...,
)
    env = merge(env, Dict("outputfile" => file))
    open(io -> writer(io, mime, ast, env; transform = transform, kws...), file, "w")
end
function writer(
    mime,
    io::IO,
    ast::Node,
    env = nothing;
    transform = default_transform,
    kws...,
)
    writer(io, mime, ast, env; transform = transform, kws...)
end
function writer(mime, ast::Node, env = nothing; transform = default_transform, kws...)
    io = IOBuffer()
    writer(mime, io, ast, env; transform = transform, kws...)
    return String(take!(io))
end

function writer(
    io::IO,
    mime::MIME,
    ast::Node,
    env::Dict;
    transform = default_transform,
    kws...,
)
    # Merge all metadata provided, priority is right-to-left.
    env = recursive_merge(
        default_config(),
        env,
        frontmatter(ast),
        something(ast.meta, Dict{String,Any}()),
    )
    show(io, mime, ast, env; transform = transform, kws...)
end
function writer(
    io::IO,
    mime::MIME,
    ast::Node,
    ::Nothing;
    transform = default_transform,
    kws...,
)
    show(io, mime, ast; transform = transform, kws...)
end

default_config() = Dict{String,Any}(
    "authors" => [],
    "curdir" => pwd(),
    "title" => "",
    "subtitle" => "",
    "abstract" => "",
    "keywords" => [],
    "lang" => "en",
    "latex" => Dict{String,Any}("documentclass" => "article"),
)

recursive_merge(ds::AbstractDict...) = merge(recursive_merge, ds...)
recursive_merge(args...) = last(args)

"""
    frontmatter(ast::Node) -> Dict{String,Any}

Extract front matter data from a parsed document.

Returns an empty dictionary if no front matter is present. Requires
[`FrontMatterRule`](@ref) to be enabled during parsing. Supports YAML (`---`),
TOML (`+++`), and JSON (`;;;`) delimiters.

# Examples

```julia
p = Parser()
enable!(p, FrontMatterRule(yaml=YAML.load))
ast = p(\"\"\"
---
title: My Document
author: Jane Doe
---
# Content
\"\"\")
frontmatter(ast)  # Dict("title" => "My Document", "author" => "Jane Doe")
```
"""
frontmatter(n::Node) = has_frontmatter(n) ? n.first_child.t.data : Dict{String,Any}()
has_frontmatter(n::Node) = !isnull(n.first_child) && n.first_child.t isa FrontMatter

mutable struct Writer{F,I<:IO,T}
    format::F
    buffer::I
    last::Char
    enabled::Bool
    context::Dict{Symbol,Any}
    env::Dict{String,Any}
    transform::T
end
Writer(
    format,
    buffer = IOBuffer(),
    env = Dict{String,Any}();
    transform = default_transform,
) = Writer(format, buffer, '\n', true, Dict{Symbol,Any}(), env, transform)

Base.get(w::Writer, k::Symbol, default) = get(w.context, k, default)
Base.get!(f::Function, w::Writer, k::Symbol) = get!(f, w.context, k)

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

"""
    default_transform(mime, container, node, entering, writer)

Default transform - passes through node unchanged.
Users can define methods dispatching on container types to transform nodes.

# Example
```julia
function my_transform(::MIME"text/html", link::Link, node, entering, writer)
    if entering
        dest = transform_url(link.destination)
        (Node(Link; dest = dest, title = link.title), entering)
    else
        (node, entering)
    end
end
my_transform(mime, ::AbstractContainer, node, entering, writer) =
    (node, entering)
```
"""
default_transform(mime, ::AbstractContainer, node, entering, writer) = (node, entering)

# Dispatch helper: no-op for default, calls transform otherwise.
# Pass node not node.t - only access .t in the transform path.
@inline _transform(::typeof(default_transform), mime, node, entering, writer) =
    (node, entering)
@noinline _transform(f, mime, node, entering, writer) =
    f(mime, node.t, node, entering, writer)

include("writers/html.jl")
include("writers/latex.jl")
include("writers/term.jl")
include("writers/markdown.jl")
include("writers/notebook.jl")
include("writers/typst.jl")
include("writers/json.jl")

function ast_dump(io::IO, ast::Node)
    indent = -2
    for (node, enter) in ast
        T = typeof(node.t).name.name
        if is_container(node)
            indent += enter ? 2 : -2
            enter && printstyled(io, ' '^indent, T, "\n"; color = :blue)
        else
            printstyled(io, ' '^(indent + 2), T, "\n"; bold = true, color = :red)
            println(io, ' '^(indent + 4), repr(node.literal))
        end
    end
end
ast_dump(ast::Node) = ast_dump(stdout, ast)
