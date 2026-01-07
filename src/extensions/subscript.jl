#
# Subscript extension: ~text~
#

"""Subscript text. Contains inline children."""
struct Subscript <: AbstractInline end

is_container(::Subscript) = true

Node(::Type{Subscript}, children...) = _build(Subscript(), children)

"""
    SubscriptRule()

Parse subscript text (`~subscript~`).

Not enabled by default. Uses single tildes to mark subscript text.

```markdown
H~2~O renders as H₂O
```
"""
struct SubscriptRule end

inline_rule(::SubscriptRule) = Rule(parse_tilde, 1, "~")
inline_modifier(::SubscriptRule) = Rule(process_emphasis, 1)
delim_nodes(::SubscriptRule) = Dict(('~', 1) => Subscript)
flanking_rule(::SubscriptRule) = ('~', :permissive)

#
# Writers
#

write_html(::Subscript, r, n, ent) =
    tag(r, ent ? "sub" : "/sub", ent ? attributes(r, n) : [])

function write_latex(::Subscript, w, n, ent)
    print(w.buffer, ent ? "\\textsubscript{" : "}")
end

function write_typst(::Subscript, w, n, ent)
    print(w.buffer, ent ? "#sub[" : "]")
end

function write_term(::Subscript, w, n, ent)
    ent ? push!(w.format.text_context, :subscript) : pop!(w.format.text_context)
end

function write_markdown(::Subscript, w, n, ent)
    literal(w, "~")
end

function write_json(::Subscript, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Subscript", inlines))
    end
end
