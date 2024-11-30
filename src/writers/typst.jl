# Public.

function Base.show(io::IO, ::MIME"text/typst", ast::Node, env = Dict{String,Any}())
    writer = Writer(Typst(io), io, env)
    write_typst(writer, ast)
    return nothing
end
typst(args...) = writer(MIME"text/typst"(), args...)

# Internals.

mime_to_str(::MIME"text/typst") = "typst"

mutable struct Typst{I<:IO}
    buffer::I
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    Typst(io::I) where {I} = new{I}(io, 0, [], 0, [])
end

function write_typst(writer::Writer, ast::Node)
    for (node, entering) in ast
        write_typst(node.t, writer, node, entering)
    end
end

# Writers.

write_typst(::Document, w, node, ent) = nothing

write_typst(::Text, w, node, ent) = typst_escape(w, node.literal)

write_typst(::Backslash, w, node, ent) = literal(w, "\\")

function write_typst(::Union{SoftBreak,LineBreak}, w, node, ent)
    cr(w)
    print_margin(w)
end

function write_typst(::Code, w, node, ent)
    num = foldl(eachmatch(r"`+", node.literal); init = 0) do a, b
        max(a, length(b.match))
    end
    literal(w, "`"^(num == 1 ? 3 : 1))
    literal(w, node.literal)
    literal(w, "`"^(num == 1 ? 3 : 1))
end

write_typst(::HtmlInline, w, node, ent) = nothing

function write_typst(link::Link, w, node, ent)
    if ent
        link = _smart_link(MIME"text/typst"(), link, node, w.env)
        literal(w, "#link(", repr(link.destination), ")[")
    else
        literal(w, "]")
    end
end

function write_typst(image::Image, w, node, ent)
    if ent
        image = _smart_link(MIME"text/typst"(), image, node, w.env)
        literal(w, "#figure(image(", repr(image.destination), "), caption: [")
    else
        literal(w, "])")
    end
end

write_typst(::Emph, w, node, ent) = literal(w, ent ? "#emph[" : "]")

write_typst(::Strong, w, node, ent) = literal(w, ent ? "#strong[" : "]")

function write_typst(::Paragraph, w, node, ent)
    if ent
        print_margin(w)
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_typst(heading::Heading, w, node, ent)
    if ent
        print_margin(w)
        literal(w, "="^heading.level, " ")
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_typst(::BlockQuote, w, node, ent)
    if ent
        literal(w, "#quote(block: true)[")
        cr(w)
    else
        literal(w, "]")
        cr(w)
    end
end

function write_typst(list::List, w, node, ent)
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

function write_typst(item::Item, w, node, enter)
    if enter
        if item.list_data.type === :ordered
            number = lpad(string(w.format.list_item_number[end], ". "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number)
        else
            push_margin!(w, 1, lpad("- ", 4, " "))
        end
    else
        if isnull(node.first_child)
            print_margin(w)
            linebreak(w, node)
        end
        pop_margin!(w)
        if !item.list_data.tight
            cr(w)
            linebreak(w, node)
        end
    end
end

function write_typst(::ThematicBreak, w, node, ent)
    literal(w, "#line(start: (25%, 0%), end: (75%, 0%))")
    cr(w)
    linebreak(w, node)
end

function write_typst(code::CodeBlock, w, node, ent)
    fence = code.is_fenced ? code.fence_char^code.fence_length : "```"
    print_margin(w)
    literal(w, fence, code.info)
    cr(w)
    for line in eachline(IOBuffer(node.literal); keep = true)
        print_margin(w)
        literal(w, line)
    end
    print_margin(w)
    literal(w, fence)
    cr(w)
    linebreak(w, node)
end

function write_typst(::HtmlBlock, w, node, ent)
    for line in eachline(IOBuffer(node.literal); keep = true)
        print_margin(w)
        literal(w, line)
    end
    linebreak(w, node)
end

let chars = Dict{Char,String}()
    for c in "~\$#_"
        chars[c] = "\\$c"
    end
    global function typst_escape(w::Writer, s::AbstractString)
        for ch in s
            literal(w, get(chars, ch, ch))
        end
    end

    global function typst_escape(s::AbstractString)
        buffer = IOBuffer()
        for ch in s
            write(buffer, get(chars, ch, ch))
        end
        return String(take!(buffer))
    end
end
