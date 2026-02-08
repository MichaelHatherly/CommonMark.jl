#
# Inline math
#

"""Inline math expression. Build with `Node(Math, "expression")`."""
struct Math <: AbstractInline
    dollar::Bool
    display::Bool
    Math(dollar::Bool = false, display::Bool = false) = new(dollar, display)
end

function Node(::Type{Math}, s::AbstractString)
    node = Node(Math())
    node.literal = s
    node
end

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

"""Display math block. Build with `Node(DisplayMath, "expression")`."""
struct DisplayMath <: AbstractBlock
    dollar::Bool
    DisplayMath(dollar::Bool = false) = new(dollar)
end

function Node(::Type{DisplayMath}, s::AbstractString)
    node = Node(DisplayMath())
    node.literal = s
    node
end

function handle_fenced_math_block(node::Node, info, source)
    node.t = DisplayMath()
    node.literal = strip(source, '\n')
end

"""
    MathRule()

Parse LaTeX math in double-backtick code spans and fenced code blocks.

Not enabled by default. Inline math uses double backticks (``` ``...`` ```),
display math uses ``` ```math ``` fenced blocks.

````markdown
Inline: ``E = mc^2``

Display:
```math
\\int_0^\\infty e^{-x^2} dx
```
````
"""
struct MathRule end
block_modifier(::MathRule) =
    Rule(1.5) do parser, node
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

"""
    DollarMathRule()

Parse LaTeX math with dollar sign delimiters (without backticks).

Not enabled by default. Inline math uses `\$...\$`, display math uses `\$\$...\$\$`.

```markdown
Inline: \$E = mc^2\$

Display:
\$\$
\\int_0^\\infty e^{-x^2} dx
\$\$
```
"""
struct DollarMathRule end

function parse_block_dollar_math(p::Parser, node::Node)
    if node.t isa Paragraph
        left = match(r"^(\$+)", node.literal)
        left === nothing && return nothing
        right = match(r"(\$+)$", rstrip(node.literal))
        right === nothing && return nothing
        if length(left[1]) == length(right[1]) == 2
            node.literal = strip(c -> isspace(c) || c === '$', node.literal)
            node.t = DisplayMath(true)
        end
    end
    return nothing
end

block_modifier(::DollarMathRule) = Rule(parse_block_dollar_math, 0)

const reDollarsHere = r"^\$+"
const reDollars = r"\$+"

function parse_inline_dollar_math(p::InlineParser, node::Node)
    dollars = match(reDollarsHere, p)
    if dollars === nothing || length(dollars.match) > 2
        return false
    end
    display = length(dollars.match) == 2
    consume(p, dollars)
    after_opener, count = position(p), length(dollars.match)
    while true
        matched = consume(p, match(reDollars, p))
        matched === nothing && break
        if length(matched.match) === count
            before_closer = position(p) - count - 1
            raw = String(bytes(p, after_opener, before_closer))
            child = Node(Math(true, display))
            child.literal = display ? strip(raw, '\n') : strip(replace(raw, r"\s+" => ' '))
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

function write_html(m::Math, rend, node, enter)
    cls = m.display ? "math display" : "math tex"
    delims = m.display ? ("\\[", "\\]") : ("\\(", "\\)")
    tag(rend, "span", attributes(rend, node, ["class" => cls]))
    print(rend.buffer, delims[1], node.literal, delims[2])
    tag(rend, "/span")
end

function write_latex(m::Math, rend, node, enter)
    delims = m.display ? ("\\[", "\\]") : ("\\(", "\\)")
    print(rend.buffer, delims[1], node.literal, delims[2])
end

function write_typst(m::Math, rend, node, enter)
    if m.display
        print(rend.buffer, "\$ ", strip(node.literal), " \$")
    else
        print(rend.buffer, "\$", strip(node.literal), "\$")
    end
end

function write_term(::Math, rend, node, enter)
    style = crayon"magenta"
    push_inline!(rend, style)
    print_literal(rend, style, node.literal, inv(style))
    pop_inline!(rend)
end

function write_markdown(m::Math, w, node, ent)
    if m.dollar
        delim = m.display ? "\$\$" : "\$"
        literal(w, delim, node.literal, delim)
    else
        num = foldl(eachmatch(r"`+", node.literal); init = 0) do a, b
            max(a, length(b.match))
        end
        literal(w, "`"^(num == 2 ? 4 : 2))
        literal(w, node.literal)
        literal(w, "`"^(num == 2 ? 4 : 2))
    end
end

function write_html(::DisplayMath, rend, node, enter)
    tag(rend, "div", attributes(rend, node, ["class" => "display-math tex"]))
    print(rend.buffer, "\\[", node.literal, "\\]")
    tag(rend, "/div")
end

function write_latex(::DisplayMath, rend, node, enter)
    println(rend.buffer, "\\begin{equation*}")
    println(rend.buffer, node.literal)
    println(rend.buffer, "\\end{equation*}")
end

function write_typst(::DisplayMath, rend, node, enter)
    print(rend.buffer, "\$ ")
    print(rend.buffer, strip(node.literal))
    println(rend.buffer, " \$")
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

function write_markdown(m::DisplayMath, w, node, ent)
    if m.dollar
        print_margin(w)
        literal(w, "\$\$\n")
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            literal(w, line, "\n")
        end
        print_margin(w)
        literal(w, "\$\$")
        cr(w)
        linebreak(w, node)
    else
        print_margin(w)
        literal(w, "```math\n")
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            literal(w, line, "\n")
        end
        print_margin(w)
        literal(w, "```")
        cr(w)
        linebreak(w, node)
    end
end

function write_json(m::Math, ctx, node, enter)
    enter || return
    kind = m.display ? "DisplayMath" : "InlineMath"
    push_element!(ctx, json_el(ctx, "Math", Any[json_el(ctx, kind), node.literal]))
end

function write_json(::DisplayMath, ctx, node, enter)
    enter || return
    math_el = json_el(ctx, "Math", Any[json_el(ctx, "DisplayMath"), node.literal])
    # Only wrap in Para when DisplayMath is a top-level block.
    # If already inside a Paragraph, emit the Math inline directly.
    if node.parent.t isa Paragraph
        push_element!(ctx, math_el)
    else
        push_element!(ctx, json_el(ctx, "Para", Any[math_el]))
    end
end
