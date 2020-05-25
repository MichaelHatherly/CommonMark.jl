struct Admonition <: AbstractBlock
    category::String
    title::String
end

is_container(::Admonition) = true
accepts_lines(::Admonition) = false
can_contain(::Admonition, t) = !(t isa Item)
finalize(::Admonition, parser::Parser, node::Node) = nothing
function continue_(::Admonition, parser::Parser, ::Any)
    if parser.indent ≥ 4 || parser.blank
        advance_offset(parser, 4, false)
    else
        return 1
    end
    return 0
end

function parse_admonition(parser::Parser, container::Node)
    if !parser.indented
        ln = SubString(parser.current_line, parser.next_nonspace)
        m = match(r"^!!! (\w+)(?: \"([^\"]+)\")?$", ln)
        if m !== nothing
            close_unmatched_blocks(parser)
            title = m[2] === nothing ? uppercasefirst(m[1]) : m[2]
            add_child(parser, Admonition(m[1], title), parser.next_nonspace)
            advance_offset(parser, length(parser.current_line) - parser.offset + 1, false)
            return 1
        end
    end
    return 0
end

struct AdmonitionRule end
block_rule(::AdmonitionRule) = Rule(parse_admonition, 0.5, "!")

#
# Writers
#

function html(a::Admonition, rend, node, enter)
    if enter
        tag(rend, "div", ["class" => "admonition $(a.category)"])
        tag(rend, "p", ["class" => "amonition-title"])
        print(rend.buffer, a.title)
        tag(rend, "/p")
    else
        tag(rend, "/div")
    end
end

function latex(a::Admonition, rend, node, enter)
    if enter
        println(rend.buffer, "\\quote{")
        println(rend.buffer, "\\textbf{", a.category, "}")
        println(rend.buffer, "\n\n", a.title, "\n")
    else
        println(rend.buffer, "}")
    end
end

function term(a::Admonition, rend, node, enter)
    if enter
        style = a.category == "danger" ? crayon"red" :
            a.category == "warning" ? crayon"yellow" :
            a.category in ("info", "note") ? crayon"cyan" :
            a.category == "tip" ? crayon"green" : crayon"default"

        push_margin!(rend, "│", style)
        push_margin!(rend, " ", crayon"")
        print_margin(rend)
        print_literal(rend, style, isempty(a.title) ? a.category : a.title, inv(style), "\n")
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
