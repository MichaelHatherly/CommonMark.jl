struct FootnoteRule
    cache::Dict{String, Node}
    FootnoteRule() = new(Dict())
end
block_rule(fr::FootnoteRule) = Rule(0.5, "[") do parser, container
    if !parser.indented
        ln = SubString(parser.current_line, parser.next_nonspace)
        m = match(r"^\[\^([\w\d]+)\]:[ ]?", ln)
        if m !== nothing
            close_unmatched_blocks(parser)
            fr.cache[m[1]] = add_child(parser, FootnoteDefinition(m[1]), parser.next_nonspace)
            advance_offset(parser, length(m.match), false)
            return 1
        end
    end
    return 0
end
inline_rule(fr::FootnoteRule) = Rule(0.5, "[") do p, node
    m = consume(p, match(r"^\[\^([\w\d]+)]", p))
    m === nothing && return false
    append_child(node, Node(FootnoteLink(m[1], fr)))
    return true
end

struct FootnoteDefinition <: AbstractBlock
    id::String
end

struct FootnoteLink <: AbstractInline
    id::String
    rule::FootnoteRule
end

is_container(::FootnoteDefinition) = true
accepts_lines(::FootnoteDefinition) = false
can_contain(::FootnoteDefinition, t) = !(t isa Item)
finalize(::FootnoteDefinition, ::Parser, ::Node) = nothing
function continue_(::FootnoteDefinition, parser::Parser, ::Any)
    if parser.indent ≥ 4 || parser.blank
        advance_offset(parser, 4, false)
    else
        return 1
    end
    return 0
end

#
# Writers
#

function html(f::FootnoteDefinition, rend, node, enter)
    if enter
        attrs = ["class" => "footnote", "id" => "footnote-$(f.id)"]
        tag(rend, "div", attrs)
        tag(rend, "p", ["class" => "footnote-title"])
        print(rend.buffer, f.id)
        tag(rend, "/p")
    else
        tag(rend, "/div")
    end
end

function latex(f::FootnoteDefinition, w, node, enter)
    get(w.buffer, :footnote, false) || (w.enabled = !enter)
    return nothing
end

function term(f::FootnoteDefinition, rend, node, enter)
    style = crayon"red"
    if enter
        header = rpad("┌ [^$(f.id)] ", available_columns(rend), "─")
        print_margin(rend)
        print_literal(rend, style, header, inv(style), "\n")
        push_margin!(rend, "│", style)
        push_margin!(rend, " ", crayon"")
    else
        pop_margin!(rend)
        pop_margin!(rend)
        print_margin(rend)
        print_literal(rend, style, rpad("└", available_columns(rend), "─"), inv(style), "\n")
        if !isnull(node.nxt)
            print_margin(rend)
            print_literal(rend, "\n")
        end
    end
end

function html(f::FootnoteLink, rend, node, enter)
    tag(rend, "a", ["href" => "#footnote-$(f.id)", "class" => "footnote"])
    print(rend.buffer, f.id)
    tag(rend, "/a")
end

function latex(f::FootnoteLink, w, node, enter)
    if haskey(f.rule.cache, f.id)
        seen = get!(() -> Set{String}(), w.format, :footnotes)
        if f.id in seen
            literal(w, "\\footref{fn:$(f.id)}")
        else
            push!(seen, f.id)
            literal(w, "\\footnote{")
            latex(IOContext(w.buffer, :footnote => true), f.rule.cache[f.id])
            literal(w, "\\label{fn:$(f.id)}}")
        end
    end
    return nothing
end

function term(f::FootnoteLink, rend, node, enter)
    style = crayon"red"
    print_literal(rend, style)
    push_inline!(rend, style)
    print_literal(rend, "[^", f.id, "]")
    pop_inline!(rend)
    print_literal(rend, inv(style))
end
