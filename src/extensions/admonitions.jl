struct Admonition <: AbstractBlock
    category::String
    title::String
end

is_container(::Admonition) = true
accepts_lines(::Admonition) = false
can_contain(::Admonition, t) = !(t isa Item)
finalize(::Admonition, parser::Parser, node::Node) = nothing
function continue_(::Admonition, parser::Parser, ::Any)
    if parser.indent ≥ 4
        advance_offset(parser, 4, true)
    elseif parser.blank
        advance_next_nonspace(parser)
    else
        return 1
    end
    return 0
end

function parse_admonition(parser::Parser, container::Node)
    if !parser.indented
        ln = SubString(parser.buf, parser.next_nonspace)
        m = match(r"^!!! (\w+)(?: \"([^\"]+)\")?$", ln)
        if m !== nothing
            close_unmatched_blocks(parser)
            title = m[2] === nothing ? uppercasefirst(m[1]) : m[2]
            add_child(parser, Admonition(m[1], title), parser.next_nonspace)
            advance_offset(parser, length(parser.buf) - parser.pos + 1, false)
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

function html(a::Admonition, f::Fmt, n::Node, enter::Bool)
    if enter
        tag(f, "div", attributes(f, n, ["class" => "admonition $(a.category)"]))
        tag(f, "p", ["class" => "admonition-title"])
        literal(f, a.title)
        tag(f, "/p")
    else
        tag(f, "/div")
    end
end

# Requires tcolorbox package and custom newtcolorbox definitions.
function latex(a::Admonition, f::Fmt, ::Node, enter::Bool)
    if enter
        cr(f)
        literal(f, "\\begin{admonition@$(a.category)}{$(a.title)}\n")
    else
        literal(f, "\\end{admonition@$(a.category)}\n")
        cr(f)
    end
end

function term(a::Admonition, f::Fmt, n::Node, enter::Bool)
    styles = Dict(
        "danger"  => crayon"red bold",
        "warning" => crayon"yellow bold",
        "info"    => crayon"cyan bold",
        "note"    => crayon"cyan bold",
        "tip"     => crayon"green bold"
    )
    style = get(styles, a.category, crayon"default bold")
    if enter
        header = rpad("┌ $(a.title) ", available_columns(f), "─")
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

function markdown(a::Admonition, f::Fmt, n::Node, enter::Bool)
    if enter
        push_margin!(f, "    ")
        literal(f, "!!! ", a.category)
        if lowercase(a.title) != lowercase(a.category)
            literal(f, " \"$(a.title)\"")
        end
        literal(f, "\n")
        print_margin(f)
        literal(f, "\n")
    else
        pop_margin!(f)
        cr(f)
        linebreak(f, n)
    end
end
