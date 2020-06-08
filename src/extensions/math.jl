#
# Inline math
#

struct Math <: AbstractInline end

function parse_inline_math_backticks(p::InlineParser, node::Node)
    ticks = consume(p, match(reTicksHere, p))
    if ticks === nothing || isodd(length(ticks.match))
        return false
    end
    after_opener, count = position(p), length(ticks.match)
    while true
        matched = consume(p, match(reTicks, p))
        matched === nothing && break
        if length(matched.match) === count
            before_closer = position(p) - count - 1
            raw = String(bytes(p, after_opener, before_closer))
            child = Node(Math())
            child.literal = strip(replace(raw, r"\s+" => ' '))
            append_child(node, child)
            return true
        end
    end
    # We didn't match an even length sequence.
    seek(p, after_opener)
    append_child(node, text(ticks.match))
    return true
end

#
# Display math
#

struct DisplayMath <: AbstractBlock end

function handle_fenced_math_block(node::Node, info, source)
    node.t = DisplayMath()
    node.literal = strip(source, '\n')
end

struct MathRule end
block_modifier(::MathRule) = Rule(1.5) do parser, node
    if node.t isa CodeBlock && node.t.info == "math"
        node.t = DisplayMath()
        node.literal = strip(node.literal, '\n')
    end
    return nothing
end
inline_rule(::MathRule) = Rule(parse_inline_math_backticks, 0, "`")

#
# Writers
#

function write_html(::Math, rend, node, enter)
    tag(rend, "span", ["class" => "math"])
    print(rend.buffer, "\\(", node.literal, "\\)")
    tag(rend, "/span")
end

function write_latex(::Math, rend, node, enter)
    print(rend.buffer, "\\(", node.literal, "\\)")
end

function write_term(::Math, rend, node, enter)
    style = crayon"magenta"
    push_inline!(rend, style)
    print_literal(rend, style, node.literal, inv(style))
    pop_inline!(rend)
end

function markdown(::Math, w, node, ent)
    num = foldl(eachmatch(r"`+", node.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(w, "`"^(num == 2 ? 4 : 2))
    literal(w, node.literal)
    literal(w, "`"^(num == 2 ? 4 : 2))
end

function write_html(::DisplayMath, rend, node, enter)
    tag(rend, "div", ["class" => "display-math"])
    print(rend.buffer, "\\[", node.literal, "\\]")
    tag(rend, "/div")
end

function write_latex(::DisplayMath, rend, node, enter)
    println(rend.buffer, "\\begin{equation*}")
    println(rend.buffer, node.literal)
    println(rend.buffer, "\\end{equation*}")
end

function write_term(::DisplayMath, rend, node, enter)
    pipe = crayon"magenta"
    style = crayon"dark_gray"
    for line in eachline(IOBuffer(node.literal))
        print_margin(rend)
        print_literal(rend, "  ", pipe, "│", inv(pipe), " ")
        print_literal(rend, style, line, inv(style), "\n")
    end
    if !isnull(node.nxt)
        print_margin(rend)
        print_literal(rend, "\n")
    end
end

function markdown(::DisplayMath, w, node, ent)
    literal(w, "```math\n")
    for line in eachline(IOBuffer(node.literal))
        print_margin(w)
        literal(w, line, "\n")
    end
    literal(w, "```")
    cr(w)
    linebreak(w, node)
end
