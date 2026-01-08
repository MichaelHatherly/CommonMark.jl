#
# Mark/Highlight extension: ==text==
#

"""Marked/highlighted text. Contains inline children."""
struct Mark <: AbstractInline end

is_container(::Mark) = true

Node(::Type{Mark}, children...) = _build(Mark(), children)

"""
    MarkRule()

Parse marked/highlighted text (`==highlighted==`).

Not enabled by default. Uses double equals to mark highlighted text.
Follows Pandoc `+mark` extension syntax.

```markdown
==This text is highlighted.==
```
"""
struct MarkRule end

parse_equals(parser, block) = handle_delim(parser, '=', block)

inline_rule(::MarkRule) = Rule(parse_equals, 1, "=")
inline_modifier(::MarkRule) = Rule(process_emphasis, 1)
delim_nodes(::MarkRule) = Dict(('=', 2) => Mark)
flanking_rule(::MarkRule) = ('=', :standard)

#
# Writers
#

write_html(::Mark, r, n, ent) = tag(r, ent ? "mark" : "/mark", ent ? attributes(r, n) : [])

function write_latex(::Mark, w, n, ent)
    # Requires \usepackage{soul}
    print(w.buffer, ent ? "\\hl{" : "}")
end

function write_typst(::Mark, w, n, ent)
    print(w.buffer, ent ? "#highlight[" : "]")
end

function write_term(::Mark, w, n, ent)
    style = crayon"negative"
    if ent
        print_literal(w, style)
        push_inline!(w, style)
    else
        pop_inline!(w)
        print_literal(w, inv(style))
    end
end

function write_markdown(::Mark, w, n, ent)
    literal(w, "==")
end

function write_json(::Mark, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        # Pandoc has no native Mark type; use Span with "mark" class
        push_element!(ctx, json_el(ctx, "Span", [["", ["mark"], []], inlines]))
    end
end
