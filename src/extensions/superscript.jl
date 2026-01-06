#
# Superscript extension: ^text^
#

struct Superscript <: AbstractInline end

is_container(::Superscript) = true

"""
    SuperscriptRule()

Parse superscript text (`^superscript^`).

Not enabled by default. Uses carets to mark superscript text.

```markdown
x^2^ renders as x²
```
"""
struct SuperscriptRule end

parse_caret(parser, block) = handle_delim(parser, '^', block)

inline_rule(::SuperscriptRule) = Rule(parse_caret, 1, "^")
inline_modifier(::SuperscriptRule) = Rule(process_emphasis, 1)
delim_nodes(::SuperscriptRule) = Dict(('^', 1) => Superscript)
flanking_rule(::SuperscriptRule) = ('^', :permissive)

#
# Writers
#

write_html(::Superscript, r, n, ent) =
    tag(r, ent ? "sup" : "/sup", ent ? attributes(r, n) : [])

function write_latex(::Superscript, w, n, ent)
    print(w.buffer, ent ? "\\textsuperscript{" : "}")
end

function write_typst(::Superscript, w, n, ent)
    print(w.buffer, ent ? "#super[" : "]")
end

function write_term(::Superscript, w, n, ent)
    ent ? push!(w.format.text_context, :superscript) : pop!(w.format.text_context)
end

function write_markdown(::Superscript, w, n, ent)
    literal(w, "^")
end

function write_json(::Superscript, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "Superscript", inlines))
    end
end
