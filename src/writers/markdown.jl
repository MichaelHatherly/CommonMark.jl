#
# `markdown`
#

"""
    markdown([io | file], ast, Extension; env)

Round-trip printing of `ast` back to markdown format with as little loss of
information as possible.
"""
markdown(args...; kws...) = fmt(markdown, args...; kws...)

mimefunc(::MIME"text/markdown") = markdown

function before(f::Fmt{Ext, T"markdown"}, ::Node) where Ext
    f[:last] = '\n'
    f[:enabled] = true
    f[:indent] = 0
    f[:margin] = MarginSegment[]
    f[:list_depth] = 0
    f[:list_item_number] = Int[]
    return nothing
end

markdown(::Document, ::Fmt, ::Node, ::Bool) = nothing

markdown(::Text, f::Fmt, n::Node, ::Bool) = literal(f, n.literal)

markdown(::Backslash, f::Fmt, ::Node, ::Bool) = literal(f, "\\")

markdown(::Union{SoftBreak, LineBreak}, f::Fmt, ::Node, ::Bool) = (cr(f); print_margin(f))

function markdown(::Code, f::Fmt, n::Node, ::Bool)
    num = foldl(eachmatch(r"`+", n.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(f, "`"^(num == 1 ? 3 : 1))
    literal(f, n.literal)
    literal(f, "`"^(num == 1 ? 3 : 1))
end

markdown(::HtmlInline, f::Fmt, n::Node, ::Bool) = literal(f, n.literal)

function markdown(link::Link, f::Fmt, n::Node, enter::Bool)
    if enter
        literal(f, "[")
    else
        literal(f, "](", link.destination)
        isempty(link.title) || literal(f, " \"", link.title, "\"")
        literal(f, ")")
    end
end

function markdown(image::Image, f::Fmt, n::Node, enter::Bool)
    if enter
        literal(f, "![")
    else
        literal(f, "](", image.destination)
        isempty(image.title) || literal(f, " \"", image.title, "\"")
        literal(f, ")")
    end
end

markdown(::Emph, f::Fmt, n::Node, ::Bool) = literal(f, n.literal)

markdown(::Strong, f::Fmt, n::Node, ::Bool) = literal(f, n.literal)

function markdown(::Paragraph, f::Fmt, n::Node, enter::Bool)
    if enter
        print_margin(f)
    else
        cr(f)
        linebreak(f, n)
    end
end

function markdown(heading::Heading, f::Fmt, n::Node, enter::Bool)
    if enter
        print_margin(f)
        literal(f, "#"^heading.level, " ")
    else
        cr(f)
        linebreak(f, n)
    end
end

function markdown(::BlockQuote, f::Fmt, n::Node, enter::Bool)
    if enter
        push_margin!(f, ">")
        push_margin!(f, " ")
    else
        pop_margin!(f)
        pop_margin!(f)
        cr(f)
        linebreak(f, n)
    end
end

function markdown(list::List, f::Fmt, n::Node, enter::Bool)
    if enter
        f[:list_depth] += 1
        push!(f[:list_item_number], list.list_data.start)
    else
        f[:list_depth] -= 1
        pop!(f[:list_item_number])
        cr(f)
        linebreak(f, n)
    end
end

function markdown(item::Item, f::Fmt, n::Node, enter::Bool)
    if enter
        if item.list_data.type === :ordered
            number = lpad(string(f[:list_item_number][end], ". "), 4, " ")
            f[:list_item_number][end] += 1
            push_margin!(f, 1, number)
        else
            bullets = ['-', '+', '*', '-', '+', '*']
            bullet = bullets[min(f[:list_depth], length(bullets))]
            push_margin!(f, 1, lpad("$bullet ", 4, " "))
        end
    else
        pop_margin!(f)
        if !item.list_data.tight
            cr(f)
            linebreak(f, n)
        end
    end
end

function markdown(::ThematicBreak, f::Fmt, n::Node, ::Bool)
    print_margin(f)
    literal(f, "* * *")
    cr(f)
    linebreak(f, n)
end

function markdown(code::CodeBlock, f::Fmt, n::Node, ::Bool)
    if code.is_fenced
        fence = code.fence_char^code.fence_length
        print_margin(f)
        literal(f, fence, code.info)
        cr(f)
        for line in eachline(IOBuffer(n.literal); keep=true)
            print_margin(f)
            literal(f, line)
        end
        print_margin(f)
        literal(f, fence)
        cr(f)
    else
        for line in eachline(IOBuffer(n.literal); keep=true)
            print_margin(f)
            indent = all(isspace, line) ? 0 : CODE_INDENT
            literal(f, ' '^indent, line)
        end
    end
    linebreak(f, n)
end

function markdown(::HtmlBlock, f::Fmt, n::Node, ::Bool)
    for line in eachline(IOBuffer(node.literal); keep=true)
        print_margin(f)
        literal(f, line)
    end
    linebreak(f, n)
end
