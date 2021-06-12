struct FootnoteRule
    cache::Dict{String, Node}
    FootnoteRule() = new(Dict())
end
block_rule(fr::FootnoteRule) = Rule(0.5, "[") do parser, container
    if !parser.indented
        ln = SubString(parser.buf, parser.next_nonspace)
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
    if parser.indent ≥ 4
        advance_offset(parser, 4, true)
    elseif parser.blank
        advance_next_nonspace(parser)
    else
        return 1
    end
    return 0
end

#
# Writers
#

# Definitions

function html(footnote::FootnoteDefinition, f::Fmt, n::Node, enter::Bool)
    if enter
        tag(f, "div", attributes(f, n, ["class" => "footnote", "id" => "footnote-$(footnote.id)"]))
        tag(f, "p", ["class" => "footnote-title"])
        literal(f, footnote.id)
        tag(f, "/p")
    else
        tag(f, "/div")
    end
end

function latex(::FootnoteDefinition, f::Fmt, ::Node, enter::Bool)
    get(f, :footnote, false) || (f[:enabled] = !enter)
    return nothing
end

function term(footnote::FootnoteDefinition, f::Fmt, n::Node, enter::Bool)
    style = crayon"red"
    if enter
        header = rpad("┌ [^$(footnote.id)] ", available_columns(f), "─")
        print_margin(f)
        print_literal(f, style, header, inv(style), "\n")
        push_margin!(f, "│", style)
        push_margin!(f, " ", crayon"")
    else
        pop_margin!(f)
        pop_margin!(f)
        print_margin(f)
        print_literal(f, style, rpad("└", available_columns(f), "─"), inv(style), "\n")
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function markdown(footnote::FootnoteDefinition, f::Fmt, ::Node, enter::Bool)
    if enter
        push_margin!(f, 1, "[^$(footnote.id)]: ", " "^4)
    else
        pop_margin!(f)
        cr(f)
    end
end

# Links

function html(footnote::FootnoteLink, f::Fmt, n::Node, enter::Bool)
    tag(f, "a", attributes(f, n, ["href" => "#footnote-$(footnote.id)", "class" => "footnote"]))
    literal(f, footnote.id)
    tag(f, "/a")
end

function latex(footnote::FootnoteLink, f::Fmt, ::Node, enter::Bool)
    if haskey(footnote.rule.cache, footnote.id)
        seen = get!(Set{String}, f, :footnotes)
        if footnote.id in seen
            literal(f, "\\footref{fn:$(footnote.id)}")
        else
            push!(seen, footnote.id)
            literal(f, "\\footnote{")
            f[:footnote] = true
            for (each, enter) in footnote.rule.cache[footnote.id]
                latex(each.t, f, each, enter)
            end
            f[:footnote] = false
            literal(f, "\\label{fn:$(footnote.id)}}")
        end
    end
    return nothing
end

function term(footnote::FootnoteLink, f::Fmt, n::Node, enter::Bool)
    style = crayon"red"
    print_literal(f, style)
    push_inline!(f, style)
    print_literal(f, "[^", footnote.id, "]")
    pop_inline!(f)
    print_literal(f, inv(style))
end

markdown(footnote::FootnoteLink, f::Fmt, ::Node, ::Bool) = literal(f, "[^", footnote.id, "]")
