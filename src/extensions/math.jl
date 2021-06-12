#
# Inline math
#

struct Math <: AbstractInline end

function parse_inline_math_backticks(p::InlineParser, node::Node)
    ticks = match(reTicksHere, p)
    if ticks === nothing || isodd(length(ticks.match))
        return false
    end
    consume(p, ticks)
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
# Dollar math
#

struct DollarMathRule end

function parse_block_dollar_math(p::Parser, node::Node)
    if node.t isa Paragraph
        left = match(r"^(\$+)", node.literal)
        left === nothing && return nothing
        right = match(r"(\$+)$", rstrip(node.literal))
        right === nothing && return nothing
        if length(left[1]) == length(right[1]) == 2
            node.literal = strip(c -> isspace(c) || c === '$', node.literal)
            node.t = DisplayMath()
        end
    end
    return nothing
end

block_modifier(::DollarMathRule) = Rule(parse_block_dollar_math, 0)

const reDollarsHere = r"^\$+"
const reDollars = r"\$+"

function parse_inline_dollar_math(p::InlineParser, node::Node)
    dollars = match(reDollarsHere, p)
    if dollars === nothing || length(dollars.match) > 1
        return false
    end
    consume(p, dollars)
    after_opener, count = position(p), length(dollars.match)
    while true
        matched = consume(p, match(reDollars, p))
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
    # We didn't match a balanced closing sequence.
    seek(p, after_opener)
    append_child(node, text(dollars.match))
    return true
end

inline_rule(::DollarMathRule) = Rule(parse_inline_dollar_math, 0, "\$")

#
# Writers
#

function html(::Math, f::Fmt, n::Node, ::Bool)
    tag(f, "span", attributes(f, n, ["class" => "math"]))
    literal(f, "\\(", n.literal, "\\)")
    tag(f, "/span")
end

latex(::Math, f::Fmt, n::Node, ::Bool) = literal(f, "\\(", n.literal, "\\)")

function term(::Math, f::Fmt, n::Node, ::Bool)
    style = crayon"magenta"
    push_inline!(f, style)
    print_literal(f, style, n.literal, inv(style))
    pop_inline!(f)
end

function markdown(::Math, f::Fmt, n::Node, ::Bool)
    num = foldl(eachmatch(r"`+", n.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(f, "`"^(num == 2 ? 4 : 2))
    literal(f, n.literal)
    literal(f, "`"^(num == 2 ? 4 : 2))
end

function html(::DisplayMath, f::Fmt, n::Node, ::Bool)
    tag(f, "div", attributes(f, n, ["class" => "display-math"]))
    literal(f, "\\[", n.literal, "\\]")
    tag(f, "/div")
end

function latex(::DisplayMath, f::Fmt, n::Node, ::Bool)
    literal(f, "\\begin{equation*}\n")
    literal(f, n.literal, "\n")
    literal(f, "\\end{equation*}\n")
end

function term(::DisplayMath, f::Fmt, n::Node, ::Bool)
    pipe = crayon"magenta"
    style = crayon"dark_gray"
    for line in eachline(IOBuffer(n.literal))
        print_margin(f)
        print_literal(f, "  ", pipe, "│", inv(pipe), " ")
        print_literal(f, style, line, inv(style), "\n")
    end
    if !isnull(n.nxt)
        print_margin(f)
        print_literal(f, "\n")
    end
end

function markdown(::DisplayMath, f::Fmt, n::Node, ::Bool)
    print_margin(f)
    literal(f, "```math\n")
    for line in eachline(IOBuffer(n.literal))
        print_margin(f)
        literal(f, line, "\n")
    end
    print_margin(f)
    literal(f, "```")
    cr(f)
    linebreak(f, n)
end
