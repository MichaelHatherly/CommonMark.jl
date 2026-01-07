"""
Generic div container. Build with `Node(FencedDiv, children...; class="name", id="id")`.
"""
mutable struct FencedDiv <: AbstractBlock
    fence_length::Int
end

is_container(::FencedDiv) = true
accepts_lines(::FencedDiv) = false
can_contain(::FencedDiv, t) = !(t isa Item)
finalize(::FencedDiv, ::Parser, ::Node) = nothing

function Node(
    ::Type{FencedDiv},
    children...;
    class::Union{AbstractString,Vector{String}} = String[],
    id::Union{AbstractString,Nothing} = nothing,
)
    fd = FencedDiv(3)
    node = _build(fd, children)
    classes = class isa AbstractString ? [class] : class
    if !isempty(classes) || id !== nothing
        node.meta = Dict{String,Any}()
        !isempty(classes) && (node.meta["class"] = classes)
        id !== nothing && (node.meta["id"] = id)
    end
    node
end

function continue_(::FencedDiv, parser::Parser, container::Node)
    ln = rest_from_nonspace(parser)
    # Closing fence: 3+ colons with no attributes (just whitespace after)
    m = match(r"^(:{3,})\s*$", ln)
    if m !== nothing && length(m[1]) >= container.t.fence_length
        # Only close if no open child fenced divs (innermost closes first)
        if !has_open_child_fenced_div(container)
            # Close any open children before closing this container
            while parser.tip !== container
                finalize(parser, parser.tip, parser.line_number)
            end
            finalize(parser, container, parser.line_number)
            return 2
        end
    end
    return 0
end

function has_open_child_fenced_div(node::Node)
    child = node.last_child
    while !isnull(child)
        if child.is_open && child.t isa FencedDiv
            return true
        end
        child = child.prv
    end
    return false
end

function parse_fenced_div(parser::Parser, container::Node)
    if !parser.indented
        ln = rest_from_nonspace(parser)
        # Opening fence: 3+ colons followed by attributes or bare word
        m = match(r"^(:{3,})\s*(.*)$", ln)
        if m !== nothing
            fence_length = length(m[1])
            rest = strip(m[2])
            # Must have something after the colons (attributes or class name)
            isempty(rest) && return 0
            # Parse attributes
            attrs = parse_div_attributes(rest)
            attrs === nothing && return 0
            close_unmatched_blocks(parser)
            node = add_child(parser, FencedDiv(fence_length), parser.next_nonspace)
            node.meta = attrs
            advance_to_end(parser)
            return 2
        end
    end
    return 0
end

function parse_div_attributes(s::AbstractString)
    s = strip(s)
    isempty(s) && return nothing
    if startswith(s, '{')
        # Full attribute syntax {#id .class key="value"} - reuse inline parser
        dict, _ = try_parse_attributes(StringParser(s))
        return dict
    else
        # Bare word(s) treated as class names (fenced div specific)
        words = split(s)
        all(w -> occursin(r"^[a-zA-Z_][a-zA-Z0-9_-]*$", w), words) || return nothing
        return Dict{String,Any}("class" => collect(words))
    end
end

"""
    FencedDivRule()

Parse Pandoc-style fenced divs (`::: class` blocks).

Not enabled by default. Creates generic container elements with CSS classes.
Divs can be nested by using more colons.

```markdown
::: warning
This is a warning div.
:::

:::: outer
::: inner
Nested divs.
:::
::::
```
"""
struct FencedDivRule end
block_rule(::FencedDivRule) = Rule(parse_fenced_div, 0.5, ":")

#
# Writers
#

function write_html(::FencedDiv, rend, node, enter)
    if enter
        cr(rend)
        tag(rend, "div", attributes(rend, node))
        cr(rend)
    else
        tag(rend, "/div")
        cr(rend)
    end
end

function write_latex(::FencedDiv, w, node, enter)
    classes = getmeta(node, "class", String[])
    env = isempty(classes) ? "fenceddiv" : "fenceddiv@$(first(classes))"
    if enter
        cr(w)
        literal(w, "\\begin{$env}\n")
    else
        literal(w, "\\end{$env}\n")
        cr(w)
    end
end

function write_typst(::FencedDiv, w, node, enter)
    if enter
        cr(w)
        literal(w, "#block[")
        cr(w)
    else
        literal(w, "]")
        id = getmeta(node, "id", nothing)
        if id !== nothing
            literal(w, " <", id, ">")
        end
        cr(w)
    end
end

function write_term(::FencedDiv, rend, node, enter)
    classes = getmeta(node, "class", String[])
    label = isempty(classes) ? "div" : first(classes)
    style = crayon"default bold"
    if enter
        header = rpad("┌ $label ", available_columns(rend), "─")
        print_margin(rend)
        print_literal(rend, style, header, inv(style), "\n")
        push_margin!(rend, "│", style)
        push_margin!(rend, " ", crayon"")
    else
        pop_margin!(rend)
        pop_margin!(rend)
        print_margin(rend)
        print_literal(
            rend,
            style,
            rpad("└", available_columns(rend), "─"),
            inv(style),
            "\n",
        )
        if !isnull(node.nxt)
            print_margin(rend)
            print_literal(rend, "\n")
        end
    end
end

function write_markdown(::FencedDiv, w, node, enter)
    if enter
        fence = ":"^node.t.fence_length
        print_margin(w)
        literal(w, fence)
        # Write attributes
        if !isnothing(node.meta) && !isempty(node.meta)
            literal(w, " ")
            write_div_attributes(w, node.meta)
        end
        literal(w, "\n")
    else
        fence = ":"^node.t.fence_length
        print_margin(w)
        literal(w, fence, "\n")
        linebreak(w, node)
    end
end

function write_div_attributes(w, meta)
    classes = get(meta, "class", String[])
    id = get(meta, "id", nothing)
    other = sort!([(k, v) for (k, v) in meta if k ∉ ("id", "class")], by = first)
    # Simple case: just classes, no id or other attrs
    if id === nothing && isempty(other) && !isempty(classes)
        if length(classes) == 1
            literal(w, first(classes))
        else
            literal(w, "{")
            literal(w, join([".$c" for c in classes], " "))
            literal(w, "}")
        end
    else
        # Full brace syntax
        literal(w, "{")
        parts = String[]
        if id !== nothing
            push!(parts, "#$id")
        end
        for c in classes
            push!(parts, ".$c")
        end
        for (k, v) in other
            if isempty(v)
                push!(parts, k)
            elseif contains(v, '"')
                push!(parts, "$k='$v'")
            else
                push!(parts, "$k=\"$v\"")
            end
        end
        literal(w, join(parts, " "))
        literal(w, "}")
    end
end

function write_json(::FencedDiv, ctx, node, enter)
    if enter
        blocks = Any[]
        push_container!(ctx, blocks)
    else
        blocks = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Div", Any[node_attr(node), blocks]))
    end
end
