#
# `term`
#

"""
    term([io | file], ast, Extension; env)

Pretty-print `ast` for display in a terminal using control characters for
colouring different types of content.
"""
term(args...; kws...) = fmt(term, args...; kws...)

function before(f::Fmt{Ext, T"term"}, ::Node) where Ext
    f[:indent] = 0
    f[:margin] = MarginSegment[]
    f[:wrap] = -1
    f[:list_depth] = 0
    f[:list_item_number] = Int[]
    return nothing
end

term(::Document, f::Fmt, ::Node, enter) = enter ? push_margin!(f, LEFT_MARGIN(), crayon"") : pop_margin!(f)

term(::Text, f::Fmt, n::Node, ::Bool) = print_literal(f, replace(n.literal, r"\s+" => ' '))

term(::Backslash, ::Fmt, ::Node, ::Bool) = nothing

term(::SoftBreak, f::Fmt, ::Node, ::Bool) = print_literal(f, " ")

function term(::LineBreak, f::Fmt, n::Node, enter)
    print(f.io, "\n")
    print_margin(f)
    f[:wrap] = f[:wrap] < 0 ? -1 : 0
end

function term(::Code, f::Fmt, n::Node, ::Bool)
    style = crayon"cyan"
    print_literal(f, style)
    push_inline!(f, style)
    print_literal(f, n.literal)
    pop_inline!(f)
    print_literal(f, inv(style))
end

function term(::HtmlInline, f::Fmt, n::Node, ::Bool)
    style = crayon"dark_gray"
    print_literal(f, style)
    push_inline!(f, style)
    print_literal(f, n.literal)
    pop_inline!(f)
    print_literal(f, inv(style))
end

function term(::Link, f::Fmt, ::Node, enter::Bool)
    style = crayon"blue underline"
    if enter
        print_literal(f, style)
        push_inline!(f, style)
    else
        pop_inline!(f)
        print_literal(f, inv(style))
    end
end

function term(::Image, f::Fmt, ::Node, enter::Bool)
    style = crayon"green"
    if enter
        print_literal(f, style)
        push_inline!(f, style)
    else
        pop_inline!(f)
        print_literal(f, inv(style))
    end
end

function term(::Emph, f::Fmt, ::Node, enter::Bool)
    style = crayon"italics"
    if enter
        print_literal(f, style)
        push_inline!(f, style)
    else
        pop_inline!(f)
        print_literal(f, inv(style))
    end
end

function term(::Strong, f::Fmt, ::Node, enter::Bool)
    style = crayon"bold"
    if enter
        print_literal(f, style)
        push_inline!(f, style)
    else
        pop_inline!(f)
        print_literal(f, inv(style))
    end
end

function term(::Paragraph, f, n::Node, enter::Bool)
    if enter
        f[:wrap] = 0
        print_margin(f)
    else
        f[:wrap] = -1
        print_literal(f, "\n")
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function term(heading::Heading, f::Fmt, n::Node, enter::Bool)
    if enter
        print_margin(f)
        style = crayon"blue bold"
        print_literal(f, style, "#"^heading.level, inv(style), " ")
    else
        print_literal(f, "\n")
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function term(::BlockQuote, f::Fmt, n::Node, enter::Bool)
    if enter
        push_margin!(f, "│", crayon"bold")
        push_margin!(f, " ", crayon"")
    else
        pop_margin!(f)
        pop_margin!(f)
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function term(list::List, f::Fmt, n::Node, enter::Bool)
    if enter
        f[:list_depth] += 1
        push!(f[:list_item_number], list.list_data.start)
        push_margin!(f, " ", crayon"")
    else
        f[:list_depth] -= 1
        pop!(f[:list_item_number])
        pop_margin!(f)
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function term(item::Item, f::Fmt, n::Node, enter::Bool)
    if enter
        if item.list_data.type === :ordered
            number = string(f[:list_item_number][end], ". ")
            f[:list_item_number][end] += 1
            push_margin!(f, 1, number, crayon"")
        else
            #              ●         ○         ▶         ▷         ■         □
            bullets = ['\u25CF', '\u25CB', '\u25B6', '\u25B7', '\u25A0', '\u25A1']
            bullet = bullets[min(f[:list_depth], length(bullets))]
            push_margin!(f, 1, "$bullet ", crayon"")
        end
    else
        pop_margin!(f)
        if !isnull(n.nxt)
            print_margin(f)
            print_literal(f, "\n")
        end
    end
end

function term(::ThematicBreak, f::Fmt, n::Node, enter::Bool)
    print_margin(f)
    style = crayon"dark_gray"
    stars = " § "
    padding = '═'^padding_between(available_columns(f), length(stars))
    print_literal(f, style, padding, stars, padding, inv(style), "\n")
    if !isnull(n.nxt)
        print_margin(f)
        print_literal(f, "\n")
    end
end

function term(::CodeBlock, f::Fmt, n::Node, enter::Bool)
    pipe = crayon"cyan"
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

function term(::HtmlBlock, f::Fmt, n::Node, enter::Bool)
    style = crayon"dark_gray"
    for line in eachline(IOBuffer(n.literal))
        print_margin(f)
        print_literal(f, style, line, inv(style), "\n")
    end
    if !isnull(n.nxt)
        print_margin(f)
        print_literal(f, "\n")
    end
end
