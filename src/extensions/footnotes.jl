#
# Block
#

struct FootnoteDefinition <: AbstractBlock
    id::String
end

is_container(::FootnoteDefinition) = true
accepts_lines(::FootnoteDefinition) = false
can_contain(::FootnoteDefinition, t) = !(t isa Item)
finalize(::FootnoteDefinition, parser::Parser, node::Node) = nothing
function continue_(::FootnoteDefinition, parser::Parser, ::Any)
    if parser.indent ≥ 4 || parser.blank
        advance_offset(parser, 4, false)
    else
        return 1
    end
    return 0
end

function parse_footnote_definition(parser::Parser, container::Node)
    if !parser.indented
        ln = SubString(parser.current_line, parser.next_nonspace)
        m = match(r"^\[\^([\w\d]+)\]:[ ]?", ln)
        if m !== nothing
            close_unmatched_blocks(parser)
            add_child(parser, FootnoteDefinition(m[1]), parser.next_nonspace)
            advance_offset(parser, length(m.match), false)
            return 1
        end
    end
    return 0
end

struct FootnoteRule end
block_rule(::FootnoteRule) = Rule(parse_footnote_definition, 0.5, "[")
inline_rule(::FootnoteRule) = Rule(parse_footnote, 0.5, "[")

#
# Inline
#

struct FootnoteLink <: AbstractInline
    id::String
end

function parse_footnote(p::InlineParser, node::Node)
    m = consume(p, match(r"^\[\^([\w\d]+)]", p))
    m == nothing && return false
    append_child(node, Node(FootnoteLink(m[1])))
    return true
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

function latex(f::FootnoteDefinition, rend, node, enter)
    if enter
        println(rend.buffer, "\\footnotetext[", f.id, "]{")
    else
        println(rend.buffer, "}")
    end
end

function term(f::FootnoteDefinition, rend, node, enter)
    if enter
        style = crayon"red"
        push_margin!(rend, "│", style)
        push_margin!(rend, " ", crayon"")
        print_margin(rend)
        print_literal(rend, style, "[^", f.id, "]", inv(style), "\n")
        print_margin(rend)
        print_literal(rend, "\n")
    else
        pop_margin!(rend)
        pop_margin!(rend)
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

function latex(f::FootnoteLink, rend, node, enter)
    print(rend.buffer, "\\footnotemark[", f.id, "]")
end

function term(f::FootnoteLink, rend, node, enter)
    style = crayon"red"
    print_literal(rend, style)
    push_inline!(rend, style)
    print_literal(rend, "[^", f.id, "]")
    pop_inline!(rend)
    print_literal(rend, inv(style))
end
