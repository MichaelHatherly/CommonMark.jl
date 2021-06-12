macro T_str(str)
    :(typeof($(esc(Symbol(str)))))
end

function literal(f::Fmt, args...)
    if f[:enabled]
        for arg in args
            write(f.io, arg)
            f[:last] = isempty(arg) ? f[:last] : last(arg)
        end
    end
    return nothing
end

function cr(f::Fmt)
    if f[:enabled] && f[:last] != '\n'
        f[:last] = '\n'
        write(f.io, '\n')
    end
    return nothing
end

function linebreak(f::Fmt, n::Node)
    if !isnull(n.nxt)
        print_margin(f)
        literal(f, "\n")
    end
    return nothing
end

mutable struct MarginSegment
    text::String
    width::Int
    count::Int
end

function padding_between(cols, objects)
    count = length(objects) - 1
    nchars = sum(Base.Unicode.textwidth, objects)
    return (cols - nchars) ÷ count
end
padding_between(cols, width::Integer) = (cols - width) ÷ 2

function literal_width(node::Node)
    width = 0
    for (node, enter) in node
        if enter
            width += Base.Unicode.textwidth(node.literal)
        end
    end
    return width
end

import Crayons: Crayon, @crayon_str

LEFT_MARGIN() = " "

function available_columns(f::Fmt)
    _, cols = displaysize(f.io)
    return cols - f[:indent] - length(LEFT_MARGIN())
end

function push_margin!(f::Fmt, text::AbstractString, style=crayon"")
    return push_margin!(f, -1, text, style)
end

function push_margin!(f::Fmt, count::Integer, initial::AbstractString, rest::AbstractString)
    width = Base.Unicode.textwidth(rest)
    f[:indent] += width
    seg = MarginSegment(initial, width, count)
    push!(f[:margin], seg)
    return nothing
end

function push_margin!(f::Fmt, count::Integer, text::AbstractString, style=crayon"")
    width = Base.Unicode.textwidth(text)
    text = string(style, text, inv(style))
    f[:indent] += width
    seg = MarginSegment(text, width, count)
    push!(f[:margin], seg)
    return nothing
end

function pop_margin!(f::Fmt)
    seg = pop!(f[:margin])
    f[:indent] -= seg.width
    return nothing
end

function push_inline!(f::Fmt, style)
    push!(f[:margin], MarginSegment(string(style), 0, -1))
    pushfirst!(f[:margin], MarginSegment(string(inv(style)), 0, -1))
    return nothing
end

function pop_inline!(f::Fmt)
    pop!(f[:margin])
    popfirst!(f[:margin])
    return nothing
end

function print_margin(f::Fmt)
    for seg in f[:margin]
        if seg.count == 0
            # Blank space case.
            print(f.io, ' '^seg.width)
        else
            # The normal case, where .count is reduced after each print.
            print(f.io, seg.text)
            seg.count > 0 && (seg.count -= 1)
        end
    end
end

function maybe_print_margin(f::Fmt, node::Node)
    if isnull(node.first_child)
        push_margin!(f, "\n")
        print_margin(f)
        pop_margin!(f)
    end
    return nothing
end

function print_literal(f::Fmt, parts...)
    # Ignore printing literals when there isn't much space, stops causing
    # stackoverflows and avoids printing badly wrapped lines when there's no
    # use printing them.
    available_columns(f) < 5 && return

    if f[:wrap] < 0
        # We just print everything normally here, allowing for the possibility
        # of bad automatic line wrapping by the terminal.
        for part in parts
            print(f.io, part)
        end
    else
        # We're in a `Paragraph` and so want nice line wrapping.
        for part in parts
            print_literal_part(f, part)
        end
    end
end

function print_literal_part(f::Fmt, lit::AbstractString, rec=0)
    width = Base.Unicode.textwidth(lit)
    space = (available_columns(f) - f[:wrap]) + ispunct(get(lit, 1, '\0'))
    if width < space
        print(f.io, lit)
        f[:wrap] += width
    else
        index = findprev(c -> c in " -–—", lit, space)
        index = index === nothing ? (rec > 0 ? space : 0) : index
        head = SubString(lit, 1, thisind(lit, index))
        tail = SubString(lit, nextind(lit, index))

        print(f.io, rstrip(head), "\n")

        print_margin(f)
        f[:wrap] = 0

        print_literal_part(f, lstrip(tail), rec+1)
    end
end
print_literal_part(f::Fmt, c::Crayon) = print(f.io, c)
