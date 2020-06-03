# Public.

function markdown(io::IO, ast::Node)
    writer = Writer(Markdown(io), io)
    for (node, entering) in ast
        markdown(node.t, writer, node, entering)
    end
    return nothing
end
markdown(ast::Node) = sprint(markdown, ast)

# Internals.

mutable struct Markdown{I <: IO}
    buffer::I
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    Markdown(io::I) where {I} = new{I}(io, 0, [], 0, [])
end

function linebreak(w, node)
    if !isnull(node.nxt)
        print_margin(w)
        literal(w, "\n")
    end
    return nothing
end

# Writers.

markdown(::Document, w, node, ent) = nothing

function markdown(::Text, w, node, ent)
    for c in node.literal
        c in MARKDOWN_ESCAPES && literal(w, '\\')
        literal(w, c)
    end
end
const MARKDOWN_ESCAPES = Set("\\[]*_#`")

function markdown(::Union{SoftBreak, LineBreak}, w, node, ent)
    cr(w)
    print_margin(w)
end

function markdown(::Code, w, node, ent)
    num = foldl(eachmatch(r"`+", node.literal); init=0) do a, b
        max(a, length(b.match))
    end
    literal(w, "`"^(num == 1 ? 3 : 1))
    literal(w, node.literal)
    literal(w, "`"^(num == 1 ? 3 : 1))
end

markdown(::HtmlInline, w, node, ent) = literal(w, node.literal)

function markdown(link::Link, w, node, ent)
    if ent
        literal(w, "[")
    else
        literal(w, "](", link.destination)
        isempty(link.title) || literal(w, " \"", link.title, "\"")
        literal(w, ")")
    end
end

function markdown(image::Image, w, node, ent)
    if ent
        literal(w, "![")
    else
        literal(w, "](", image.destination)
        isempty(image.title) || literal(w, " \"", image.title, "\"")
        literal(w, ")")
    end
end

markdown(::Emph, w, node, ent) = literal(w, "*")

markdown(::Strong, w, node, ent) = literal(w, "**")

function markdown(::Paragraph, w, node, ent)
    if ent
        print_margin(w)
    else
        cr(w)
        linebreak(w, node)
    end
end

function markdown(heading::Heading, w, node, ent)
    if ent
        print_margin(w)
        literal(w, "#"^heading.level, " ")
    else
        cr(w)
        linebreak(w, node)
    end
end

function markdown(::BlockQuote, w, node, ent)
    if ent
        push_margin!(w, ">")
        push_margin!(w, " ")
    else
        pop_margin!(w)
        pop_margin!(w)
        cr(w)
        linebreak(w, node)
    end
end

function markdown(list::List, w, node, ent)
    if ent
        w.format.list_depth += 1
        push!(w.format.list_item_number, list.list_data.start)
    else
        w.format.list_depth -= 1
        pop!(w.format.list_item_number)
        cr(w)
        linebreak(w, node)
    end
end

function markdown(item::Item, w, node, enter)
    if enter
        if item.list_data.type === :ordered
            number = lpad(string(w.format.list_item_number[end], ". "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number)
        else
            bullets = ['-', '+', '*', '-', '+', '*']
            bullet = bullets[min(w.format.list_depth, length(bullets))]
            push_margin!(w, 1, lpad("$bullet ", 4, " "))
        end
    else
        pop_margin!(w)
        if !item.list_data.tight
            cr(w)
            linebreak(w, node)
        end
    end
end

function markdown(::ThematicBreak, w, node, ent)
    print_margin(w)
    literal(w, "* * *")
    cr(w)
    linebreak(w, node)
end

function markdown(code::CodeBlock, w, node, ent)
    if code.is_fenced
        fence = code.fence_char^code.fence_length
        print_margin(w)
        literal(w, fence, code.info)
        cr(w)
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            literal(w, line)
            cr(w)
        end
        print_margin(w)
        literal(w, fence)
        cr(w)
    else
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            isempty(line) || literal(w, ' '^CODE_INDENT, line)
            cr(w)
        end
    end
    linebreak(w, node)
end

function markdown(::HtmlBlock, w, node, ent)
    for line in eachline(IOBuffer(node.literal))
        print_margin(w)
        literal(w, line)
        cr(w)
    end
    linebreak(w, node)
end
