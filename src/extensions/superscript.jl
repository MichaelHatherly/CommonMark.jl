#
# Superscript extension: ^text^
#

struct Superscript <: AbstractInline end

is_container(::Superscript) = true

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
