import Crayons: Crayon, @crayon_str

mutable struct MarginSegment
    text::String
    width::Int
    count::Int
end

mutable struct Term
    indent::Int
    margin::Vector{MarginSegment}
    buffer::IOBuffer
    wrap::Int
    Term() = new(0, [], IOBuffer(), -1)
end

"""
Renders the `ast` to the buffer provided by `r.buffer`. We use a double buffer
technique here otherwise we will get flicking display as the output is built up
by the nested calls to each `term` function. By writing to the true buffer
after all calls to `term` are done we get a much better user experience.
"""
function render(r::Writer{Term}, ast::Node)
    # Renew the double buffer.
    r.format.buffer = IOBuffer()
    r.format.wrap = -1
    r.format.margin = []
    r.format.indent = 0
    for (node, entering) in ast
        term(node.t, r, node, entering)
    end
    # Double buffered writing to avoid noticeable lag.
    write(r.buffer, take!(r.format.buffer))
    return nothing
end

# Utilities.

function padding_between(cols, objects)
    count = length(objects) - 1
    nchars = sum(Base.Unicode.textwidth, objects)
    return (cols - nchars) ÷ count
end
padding_between(cols, width::Integer) = (cols - width) ÷ 2

"""
What is the width of the literal text stored in `node` and all of it's child
nodes. Used to determine alignment for rendering nodes such as centered.
"""
function literal_width(node::Node)
    width = 0
    for (node, enter) in node
        if enter
            width += Base.Unicode.textwidth(node.literal)
        end
    end
    return width
end

const LEFT_MARGIN = " "

"""
Given the current indent of the renderer we check to see how much space is left
on the current line.
"""
function available_columns(r::Writer{Term})
    _, cols = displaysize(r.buffer)
    return cols - r.format.indent - length(LEFT_MARGIN)
end

"""
Adds a new segment to the margin buffer. This segment is persistent and thus
will print on every margin print.
"""
function push_margin!(r::Writer{Term}, text::AbstractString, style=crayon"")
    return push_margin!(r, -1, text, style)
end

"""
Adds a new segment to the margin buffer, but will only print out for the given
number of `count` calls to `print_margin`. After `count` calls it will instead
print out spaces equal to the width of `text`.
"""
function push_margin!(r::Writer{Term}, count::Integer, text::AbstractString, style=crayon"")
    text = string(style, text, inv(style))
    width = Base.Unicode.textwidth(text)
    r.format.indent += width
    seg = MarginSegment(text, width, count)
    push!(r.format.margin, seg)
    return nothing
end

# Matching call for a `push_margin!`. Must be call on exiting a node where a
# `push_margin!` was used when entering.
function pop_margin!(r::Writer{Term})
    seg = pop!(r.format.margin)
    r.format.indent -= seg.width
    return nothing
end

function push_inline!(r::Writer, style)
    push!(r.format.margin, MarginSegment(string(style), 0, -1))
    pushfirst!(r.format.margin, MarginSegment(string(inv(style)), 0, -1))
    return nothing
end

function pop_inline!(r::Writer)
    pop!(r.format.margin)
    popfirst!(r.format.margin)
    return nothing
end

"""
Print out all the current segments present in the margin buffer.

Each time a segment gets printed it's count is reduced. When a segment has a
count of zero it won't be printed and instead spaces equal to it's width are
printed. For persistent printing a count of -1 should be used.
"""
function print_margin(r::Writer{Term})
    for seg in r.format.margin
        if seg.count == 0
            # Blank space case.
            print(r.format.buffer, ' '^seg.width)
        else
            # The normal case, where .count is reduced after each print.
            print(r.format.buffer, seg.text)
            seg.count > 0 && (seg.count -= 1)
        end
    end
end

"""
Literal printing of a of `parts`. Behaviour depends on when `.wrap` is active
at the moment, which is set in `Paragraph` rendering.
"""
function print_literal(r::Writer{Term}, parts...)
    # Ignore printing literals when there isn't much space, stops causing
    # stackoverflows and avoids printing badly wrapped lines when there's no
    # use printing them.
    available_columns(r) < 5 && return

    if r.format.wrap < 0
        # We just print everything normally here, allowing for the possibility
        # of bad automatic line wrapping by the terminal.
        for part in parts
            print(r.format.buffer, part)
        end
    else
        # We're in a `Paragraph` and so want nice line wrapping.
        for part in parts
            print_literal_part(r, part)
        end
    end
end

function print_literal_part(r::Writer{Term}, lit::AbstractString, rec=0)
    width = Base.Unicode.textwidth(lit)
    space = (available_columns(r) - r.format.wrap) + ispunct(get(lit, 1, '\0'))
    if width < space
        print(r.format.buffer, lit)
        r.format.wrap += width
    else
        index = findprev(c -> c in " -–—", lit, space)
        index = index === nothing ? (rec > 0 ? space : 0) : index
        head = SubString(lit, 1, thisind(lit, index))
        tail = SubString(lit, nextind(lit, index))

        print(r.format.buffer, rstrip(head), "\n")

        print_margin(r)
        r.format.wrap = 0

        print_literal_part(r, lstrip(tail), rec+1)
    end
end
print_literal_part(r::Writer{Term}, c::Crayon) = print(r.format.buffer, c)

# Rendering to terminal.

function term(::Document, render, node, enter)
    if enter
        push_margin!(render, LEFT_MARGIN, crayon"")
    else
        pop_margin!(render)
    end
end

function term(::Text, render, node, enter)
    print_literal(render, replace(node.literal, r"\s+" => ' '))
end

function term(::SoftBreak, render, node, enter)
    print_literal(render, " ")
end

function term(::LineBreak, render, node, enter)
    print(render.format.buffer, "\n")
    print_margin(render)
    render.format.wrap = render.format.wrap < 0 ? -1 : 0
end

function term(::Code, render, node, enter)
    style = crayon"cyan"
    print_literal(render, style)
    push_inline!(render, style)
    print_literal(render, node.literal)
    pop_inline!(render)
    print_literal(render, inv(style))
end

function term(::HtmlInline, render, node, enter)
    style = crayon"dark_gray"
    print_literal(render, style)
    push_inline!(render, style)
    print_literal(render, node.literal)
    pop_inline!(render)
    print_literal(render, inv(style))
end

function term(::Link, render, node, enter)
    style = crayon"blue underline"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

function term(::Image, render, node, enter)
    style = crayon"green"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

function term(::Emph, render, node, enter)
    style = crayon"italics"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

function term(::Strong, render, node, enter)
    style = crayon"bold"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

function term(::Paragraph, render, node, enter)
    if enter
        render.format.wrap = 0
        print_margin(render)
    else
        render.format.wrap = -1
        print_literal(render, "\n")
        if !isnull(node.nxt)
            print_margin(render)
            print_literal(render, "\n")
        end
    end
end

function term(heading::Heading, render, node, enter)
    if enter
        print_margin(render)
        style = crayon"blue bold"
        print_literal(render, style, "#"^heading.level, inv(style), " ")
    else
        print_literal(render, "\n")
        if !isnull(node.nxt)
            print_margin(render)
            print_literal(render, "\n")
        end
    end
end

function term(::BlockQuote, render, node, enter)
    if enter
        push_margin!(render, "│", crayon"bold")
        push_margin!(render, " ", crayon"")
    else
        pop_margin!(render)
        pop_margin!(render)
        if !isnull(node.nxt)
            print_margin(render)
            print_literal(render, "\n")
        end
    end
end

function term(list::List, render, node, enter)
    if enter
        push_margin!(render, " ", crayon"")
    else
        pop_margin!(render)
        if !isnull(node.nxt)
            print_margin(render)
            print_literal(render, "\n")
        end
    end
end

function term(item::Item, render, node, enter)
    if enter
        push_margin!(render, 1, "• ", crayon"")
    else
        pop_margin!(render)
        if !isnull(node.nxt)
            print_margin(render)
            print_literal(render, "\n")
        end
    end
end

function term(::ThematicBreak, render, node, enter)
    print_margin(render)
    style = crayon"magenta"
    print_literal(render, style, "* * *", inv(style), "\n")
    if !isnull(node.nxt)
        print_margin(render)
        print_literal(render, "\n")
    end
end

function term(::CodeBlock, render, node, enter)
    pipe = crayon"cyan"
    style = crayon"dark_gray"
    for line in eachline(IOBuffer(node.literal))
        print_margin(render)
        print_literal(render, "  ", pipe, "│", inv(pipe), " ")
        print_literal(render, style, line, inv(style), "\n")
    end
    if !isnull(node.nxt)
        print_margin(render)
        print_literal(render, "\n")
    end
end

function term(::HtmlBlock, render, node, enter)
    style = crayon"dark_gray"
    for line in eachline(IOBuffer(node.literal))
        print_margin(render)
        print_literal(render, style, line, inv(style), "\n")
    end
    if !isnull(node.nxt)
        print_margin(render)
        print_literal(render, "\n")
    end
end
