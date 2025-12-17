#
# Strikethrough extension: ~~text~~
#

struct Strikethrough <: AbstractInline end

is_container(::Strikethrough) = true

"""
    StrikethroughRule()

Parse strikethrough text (`~~deleted~~`).

Not enabled by default. Uses double tildes to mark deleted text.

```markdown
~~This text is struck through.~~
```
"""
struct StrikethroughRule end

parse_tilde(parser, block) = handle_delim(parser, '~', block)

inline_rule(::StrikethroughRule) = Rule(parse_tilde, 1, "~")
inline_modifier(::StrikethroughRule) = Rule(process_emphasis, 1)
delim_nodes(::StrikethroughRule) = Dict(('~', 2) => Strikethrough)
flanking_rule(::StrikethroughRule) = ('~', :standard)

#
# Writers
#

write_html(::Strikethrough, r, n, ent) =
    tag(r, ent ? "del" : "/del", ent ? attributes(r, n) : [])

function write_latex(::Strikethrough, w, n, ent)
    # Requires \usepackage{soul} or \usepackage{ulem}
    print(w.buffer, ent ? "\\sout{" : "}")
end

function write_typst(::Strikethrough, w, n, ent)
    print(w.buffer, ent ? "#strike[" : "]")
end

function write_term(::Strikethrough, w, n, ent)
    style = crayon"strikethrough"
    if ent
        print_literal(w, style)
        push_inline!(w, style)
    else
        pop_inline!(w)
        print_literal(w, inv(style))
    end
end

function write_markdown(::Strikethrough, w, n, ent)
    literal(w, "~~")
end
