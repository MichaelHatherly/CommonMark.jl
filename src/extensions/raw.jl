"""Raw LaTeX inline content. Build with `Node(LaTeXInline, "\\\\command")`."""
struct LaTeXInline <: AbstractInline end

"""Raw LaTeX block content. Build with `Node(LaTeXBlock, "\\\\begin{...}")`."""
struct LaTeXBlock <: AbstractBlock end

"""Raw Typst inline content. Build with `Node(TypstInline, "#command")`."""
struct TypstInline <: AbstractInline end

"""Raw Typst block content. Build with `Node(TypstBlock, "#figure[]")`."""
struct TypstBlock <: AbstractBlock end

function Node(::Type{LaTeXInline}, s::AbstractString)
    node = Node(LaTeXInline())
    node.literal = s
    node
end

function Node(::Type{LaTeXBlock}, s::AbstractString)
    node = Node(LaTeXBlock())
    node.literal = s
    node
end

function Node(::Type{TypstInline}, s::AbstractString)
    node = Node(TypstInline())
    node.literal = s
    node
end

function Node(::Type{TypstBlock}, s::AbstractString)
    node = Node(TypstBlock())
    node.literal = s
    node
end

const RAW_CONTENT_DEFAULTS = Dict(
    "html_inline" => () -> HtmlInline(raw = true),
    "latex_inline" => LaTeXInline,
    "typst_inline" => TypstInline,
    "html_block" => () -> HtmlBlock(raw = true),
    "latex_block" => LaTeXBlock,
    "typst_block" => TypstBlock,
)

"""
    RawContentRule(; formats...)

Parse format-specific raw content blocks.

Not enabled by default. Uses `` `content`{=format} `` syntax for inline and
fenced blocks with `{=format}` for blocks. The `_inline` or `_block` suffix
is added automatically based on context.

```markdown
`<span>html</span>`{=html}

```{=latex}
\\textbf{LaTeX content}
```
```

Default formats: `html`, `latex`, `typst`.
"""
struct RawContentRule
    formats::Dict{String,Any}
    function RawContentRule(; formats...)
        return isempty(formats) ? new(RAW_CONTENT_DEFAULTS) :
               new(Dict("$k" => v for (k, v) in formats))
    end
end

const reRawContent = r"^{=([a-z]+)}"

inline_rule(rule::RawContentRule) =
    Rule(1, "{") do parser, block
        if !isnull(block.last_child) && block.last_child.t isa Code
            m = match(reRawContent, parser)
            if m !== nothing
                key = "$(m[1])_inline"
                if haskey(rule.formats, key)
                    block.last_child.t = rule.formats[key]()
                    consume(parser, m)
                    return true
                end
            end
        end
        return false
    end

block_modifier(rule::RawContentRule) =
    Rule(2) do parser, node
        if node.t isa CodeBlock
            m = match(reRawContent, node.t.info)
            m === nothing && return nothing
            key = "$(m[1])_block"
            haskey(rule.formats, key) && (node.t = rule.formats[key]())
        end
        return nothing
    end

# Raw LaTeX doesn't get displayed in HTML documents.
write_html(::LaTeXBlock, w, n, en) = nothing
write_html(::LaTeXInline, w, n, ent) = nothing

# Raw Typst doesn't get displayed in HTML documents.
write_html(::TypstBlock, w, n, en) = nothing
write_html(::TypstInline, w, n, ent) = nothing

# Don't do any kind of escaping for the content.
function write_latex(::LaTeXBlock, w, n, ent)
    cr(w)
    literal(w, n.literal)
    cr(w)
end
write_latex(::LaTeXInline, w, n, ent) = literal(w, n.literal)

write_latex(::TypstBlock, w, n, en) = nothing
write_latex(::TypstInline, w, n, ent) = nothing

function write_typst(::TypstBlock, w, n, ent)
    cr(w)
    literal(w, n.literal)
    cr(w)
end
write_typst(::TypstInline, w, n, ent) = literal(w, n.literal)

write_typst(::LaTeXBlock, w, n, ent) = nothing
write_typst(::LaTeXInline, w, n, ent) = nothing

# Printing to terminal using the same implementations as for HTML content.
write_term(::LaTeXBlock, w, n, ent) = write_term(HtmlBlock(), w, n, ent)
write_term(::LaTeXInline, w, n, ent) = write_term(HtmlInline(), w, n, ent)

# Printing to terminal using the same implementations as for HTML content.
write_term(::TypstBlock, w, n, ent) = write_term(HtmlBlock(), w, n, ent)
write_term(::TypstInline, w, n, ent) = write_term(HtmlInline(), w, n, ent)

function write_markdown(t::Union{LaTeXBlock,TypstBlock}, w, n, ent)
    print_margin(w)
    literal(w, "```{=$(_raw_tag(t))}\n")
    for line in eachline(IOBuffer(n.literal))
        print_margin(w)
        literal(w, line, "\n")
    end
    print_margin(w)
    literal(w, "```\n")
    linebreak(w, n)
end

function write_markdown(t::Union{LaTeXInline,TypstInline}, w, n, ent)
    num = foldl(eachmatch(r"`+", n.literal); init = 0) do a, b
        max(a, length(b.match))
    end
    literal(w, '`'^(num == 1 ? 2 : 1))
    literal(w, n.literal)
    literal(w, '`'^(num == 1 ? 2 : 1), "{=$(_raw_tag(t))}")
end

_raw_tag(::LaTeXInline) = "latex"
_raw_tag(::LaTeXBlock) = "latex"
_raw_tag(::TypstInline) = "typst"
_raw_tag(::TypstBlock) = "typst"

function write_json(::LaTeXBlock, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawBlock", Any["latex", node.literal]))
end

function write_json(::LaTeXInline, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawInline", Any["latex", node.literal]))
end

function write_json(::TypstBlock, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawBlock", Any["typst", node.literal]))
end

function write_json(::TypstInline, ctx, node, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawInline", Any["typst", node.literal]))
end
