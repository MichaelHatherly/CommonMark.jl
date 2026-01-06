# Public.

function Base.show(
    io::IO,
    ::MIME"application/pandoc+json",
    ast::Node,
    env = Dict{String,Any}();
    dicttype = Dict,
    kws...,
)
    DictType = get(env, "dicttype", dicttype)
    ctx = JSONContext(DictType)
    # Populate meta from frontmatter if present.
    if has_frontmatter(ast)
        fm = frontmatter(ast)
        for (k, v) in fm
            ctx.doc["meta"][k] = json_meta_value(ctx, v)
        end
    end
    for (node, enter) in ast
        write_json(node.t, ctx, node, enter)
    end
    _json(io, ctx.doc)
    return nothing
end

"""
    json(ast::Node; dicttype=Dict) -> String
    json(filename::String, ast::Node; dicttype=Dict)
    json(io::IO, ast::Node; dicttype=Dict)

Render a CommonMark AST to Pandoc AST JSON format.

The output can be piped to `pandoc -f json -t <format>` to convert to any
format Pandoc supports (docx, epub, rst, asciidoc, etc.).

The `dicttype` keyword argument controls the dictionary type used internally.
Use `OrderedCollections.OrderedDict` for deterministic key ordering.

# Examples

```julia
p = Parser()
ast = p("# Hello\\n\\nWorld")
output = json(ast)
# Use with: echo \$output | pandoc -f json -t docx -o out.docx
```
"""
json(args...; dicttype = Dict) =
    writer(MIME"application/pandoc+json"(), args...; dicttype = dicttype)

# Internals.

mime_to_str(::MIME"application/pandoc+json") = "json"

# Context for building AST during traversal.
mutable struct JSONContext{D<:AbstractDict}
    doc::D
    stack::Vector{Vector{Any}}  # Stack of inline/block containers
end

function JSONContext(DictType::Type = Dict)
    doc = DictType{String,Any}(
        "pandoc-api-version" => [1, 23, 1],
        "meta" => DictType{String,Any}(),
        "blocks" => Any[],
    )
    JSONContext{typeof(doc)}(doc, Vector{Any}[doc["blocks"]])
end

# Current container being built.
current(ctx::JSONContext) = ctx.stack[end]

# Push a new container onto the stack.
push_container!(ctx::JSONContext, container::Vector{Any}) = push!(ctx.stack, container)

# Pop container from stack.
pop_container!(ctx::JSONContext) = pop!(ctx.stack)

# Add element to current container.
push_element!(ctx::JSONContext, el) = push!(current(ctx), el)

# Element constructors - use same dict type as context.
dicttype(::JSONContext{D}) where {D} = D
json_el(ctx::JSONContext{D}, t::String) where {D} = D("t" => t)
json_el(ctx::JSONContext{D}, t::String, c) where {D} = D("t" => t, "c" => c)

# Empty attribute triple.
empty_attr() = Any["", String[], Any[]]

# Build attribute triple from node metadata.
function node_attr(node::Node)
    id = getmeta(node, "id", "")
    class_val = getmeta(node, "class", "")
    classes = if class_val isa AbstractVector
        String.(class_val)
    elseif isempty(class_val)
        String[]
    else
        String.(split(class_val))
    end
    Any[id, classes, Any[]]
end

# Convert frontmatter values to meta format.
json_meta_value(ctx::JSONContext{D}, s::AbstractString) where {D} =
    D("t" => "MetaString", "c" => s)
json_meta_value(ctx::JSONContext{D}, v::AbstractVector) where {D} =
    D("t" => "MetaList", "c" => Any[json_meta_value(ctx, x) for x in v])
json_meta_value(ctx::JSONContext{D}, d::AbstractDict) where {D} =
    D("t" => "MetaMap", "c" => D(string(k) => json_meta_value(ctx, v) for (k, v) in d))
json_meta_value(ctx::JSONContext{D}, b::Bool) where {D} = D("t" => "MetaBool", "c" => b)
json_meta_value(ctx::JSONContext{D}, n::Number) where {D} =
    D("t" => "MetaString", "c" => string(n))
json_meta_value(ctx::JSONContext{D}, x) where {D} = D("t" => "MetaString", "c" => string(x))

# Split text into Str + Space tokens.
function text_to_inlines(ctx::JSONContext, s::AbstractString)
    result = Any[]
    isempty(s) && return result
    i = 1
    while i <= lastindex(s)
        if isspace(s[i])
            # Collect whitespace run.
            j = i
            has_newline = false
            while j <= lastindex(s) && isspace(s[j])
                s[j] == '\n' && (has_newline = true)
                j = nextind(s, j)
            end
            push!(result, json_el(ctx, has_newline ? "SoftBreak" : "Space"))
            i = j
        else
            # Collect non-whitespace run.
            j = i
            while j <= lastindex(s) && !isspace(s[j])
                j = nextind(s, j)
            end
            push!(result, json_el(ctx, "Str", s[i:prevind(s, j)]))
            i = j
        end
    end
    result
end

# Core block types.

write_json(::Document, ctx, node, enter) = nothing

function write_json(::Paragraph, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        # Use Plain for tight list items, Para otherwise.
        grandparent = node.parent.parent
        block_type =
            if !isnull(grandparent) &&
               grandparent.t isa List &&
               grandparent.t.list_data.tight
                "Plain"
            else
                "Para"
            end
        push_element!(ctx, json_el(ctx, block_type, inlines))
    end
end

function write_json(h::Heading, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Header", Any[h.level, node_attr(node), inlines]))
    end
end

function write_json(::CodeBlock, ctx, node, enter)
    enter || return
    info = node.t.info
    classes = isempty(info) ? String[] : String[info]
    attr = Any["", classes, Any[]]
    # Strip trailing newline.
    content = chomp(node.literal)
    push_element!(ctx, json_el(ctx, "CodeBlock", Any[attr, content]))
end

function write_json(::BlockQuote, ctx, node, enter)
    if enter
        blocks = Any[]
        push_container!(ctx, blocks)
    else
        blocks = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "BlockQuote", blocks))
    end
end

function write_json(::ThematicBreak, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "HorizontalRule"))
end

function write_json(::HtmlBlock, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawBlock", Any["html", node.literal]))
end

# Lists.

function write_json(list::List, ctx, node, enter)
    if enter
        items = Any[]
        push_container!(ctx, items)
    else
        items = pop_container!(ctx)
        if list.list_data.type === :bullet
            push_element!(ctx, json_el(ctx, "BulletList", items))
        else
            start = list.list_data.start
            style = json_el(ctx, "Decimal")
            delim =
                list.list_data.delimiter == ")" ? json_el(ctx, "OneParen") :
                json_el(ctx, "Period")
            push_element!(
                ctx,
                json_el(ctx, "OrderedList", Any[Any[start, style, delim], items]),
            )
        end
    end
end

function write_json(::Item, ctx, node, enter)
    if enter
        blocks = Any[]
        push_container!(ctx, blocks)
    else
        blocks = pop_container!(ctx)
        push_element!(ctx, blocks)
    end
end

# Inline types.

function write_json(::Text, ctx, node, enter)
    enter || return
    append!(current(ctx), text_to_inlines(ctx, node.literal))
end

write_json(::SoftBreak, ctx, node, enter) =
    enter && push_element!(ctx, json_el(ctx, "SoftBreak"))

write_json(::LineBreak, ctx, node, enter) =
    enter && push_element!(ctx, json_el(ctx, "LineBreak"))

function write_json(::Code, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "Code", Any[empty_attr(), node.literal]))
end

function write_json(::Emph, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Emph", inlines))
    end
end

function write_json(::Strong, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Strong", inlines))
    end
end

function write_json(link::Link, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        target = Any[link.destination, link.title]
        push_element!(ctx, json_el(ctx, "Link", Any[node_attr(node), inlines, target]))
    end
end

function write_json(img::Image, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        target = Any[img.destination, img.title]
        push_element!(ctx, json_el(ctx, "Image", Any[node_attr(node), inlines, target]))
    end
end

function write_json(::HtmlInline, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawInline", Any["html", node.literal]))
end

write_json(::Backslash, ctx, node, enter) = nothing

# Fallback for unknown/extension types.
write_json(container, ctx, node, enter) = nothing
