# Public.

function Base.show(io::IO, ::MIME"text/markdown", ast::Node, env = Dict{String,Any}())
    writer = Writer(Markdown(io), io, env)
    write_markdown(writer, ast)
    return nothing
end
"""
    markdown(ast::Node) -> String
    markdown(filename::String, ast::Node)
    markdown(io::IO, ast::Node)

Render a CommonMark AST back to Markdown text.

Useful for normalizing Markdown formatting or for roundtrip testing.
Output uses opinionated formatting with no trailing whitespace.

# Examples

```julia
p = Parser()
ast = p("# Hello\\n\\nWorld")
markdown(ast)  # "# Hello\\n\\nWorld\\n"
```
"""
markdown(args...) = writer(MIME"text/markdown"(), args...)

# Internals.

mime_to_str(::MIME"text/markdown") = "markdown"

mutable struct Markdown{I<:IO}
    buffer::I
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    Markdown(io::I) where {I} = new{I}(io, 0, [], 0, [])
end

escape_markdown_title(s::AbstractString) = replace(s, "\"" => "\\\"")

# Print margin with trailing whitespace stripped (for blank lines)
function print_margin_rstrip(w)
    margin = sprint() do io
        for seg in w.format.margin
            if seg.count == 0
                print(io, ' '^seg.width)
            else
                print(io, seg.text)
            end
        end
    end
    literal(w, rstrip(margin))
end

function write_markdown(writer::Writer, ast::Node)
    for (node, entering) in ast
        write_markdown(node.t, writer, node, entering)
    end
end

function linebreak(w, node)
    if !isnull(node.nxt)
        # Skip in tight lists - Item writer handles loose list spacing
        if node.parent.t isa Item && node.parent.parent.t.list_data.tight
            return nothing
        end
        print_margin_rstrip(w)
        literal(w, "\n")
    end
    return nothing
end

# Writers.

write_markdown(::Document, w, node, ent) = nothing

write_markdown(::Text, w, node, ent) = literal(w, node.literal)

write_markdown(::Backslash, w, node, ent) = literal(w, "\\")

function write_markdown(::Union{SoftBreak,LineBreak}, w, node, ent)
    cr(w)
    print_margin(w)
end

function write_markdown(::Code, w, node, ent)
    # Find longest consecutive backtick run in content
    num = foldl(eachmatch(r"`+", node.literal); init = 0) do a, b
        max(a, length(b.match))
    end
    # Use next odd number > num (avoid even counts which are math syntax)
    backticks = num + (isodd(num) ? 2 : 1)
    content = node.literal
    # Add space padding if content starts/ends with backtick (avoid merging with delimiter)
    pad = !isempty(content) && (startswith(content, '`') || endswith(content, '`'))
    literal(w, "`"^backticks)
    pad && literal(w, " ")
    literal(w, content)
    pad && literal(w, " ")
    literal(w, "`"^backticks)
end

write_markdown(::HtmlInline, w, node, ent) = literal(w, node.literal)

function write_markdown(link::Link, w, node, ent)
    if ent
        literal(w, "[")
    else
        link = _smart_link(MIME"text/markdown"(), link, node, w.env)
        literal(w, "](", link.destination)
        isempty(link.title) || literal(w, " \"", escape_markdown_title(link.title), "\"")
        literal(w, ")")
    end
end

function write_markdown(image::Image, w, node, ent)
    if ent
        literal(w, "![")
    else
        image = _smart_link(MIME"text/markdown"(), image, node, w.env)
        literal(w, "](", image.destination)
        isempty(image.title) || literal(w, " \"", escape_markdown_title(image.title), "\"")
        literal(w, ")")
    end
end

write_markdown(::Emph, w, node, ent) = literal(w, node.literal)

write_markdown(::Strong, w, node, ent) = literal(w, node.literal)

function write_markdown(::Paragraph, w, node, ent)
    if ent
        print_margin(w)
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(heading::Heading, w, node, ent)
    if ent
        print_margin(w)
        literal(w, "#"^heading.level, " ")
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(::BlockQuote, w, node, ent)
    if ent
        push_margin!(w, ">")
        push_margin!(w, " ")
    else
        pop_margin!(w)
        maybe_print_margin(w, node)
        pop_margin!(w)
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(list::List, w, node, ent)
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

function write_markdown(item::Item, w, node, enter)
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
        if isnull(node.first_child)
            print_margin_rstrip(w)
            cr(w)
        end
        pop_margin!(w)
        if !node.parent.t.list_data.tight
            cr(w)
            linebreak(w, node)
        end
    end
end

function write_markdown(::ThematicBreak, w, node, ent)
    print_margin(w)
    literal(w, "* * *")
    cr(w)
    linebreak(w, node)
end

function write_markdown(code::CodeBlock, w, node, ent)
    if code.is_fenced
        fence = code.fence_char^code.fence_length
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
    else
        for line in eachline(IOBuffer(node.literal); keep = true)
            print_margin(w)
            indent = all(isspace, line) ? 0 : CODE_INDENT
            literal(w, ' '^indent, line)
        end
    end
    linebreak(w, node)
end

function write_markdown(::HtmlBlock, w, node, ent)
    for line in eachline(IOBuffer(node.literal); keep = true)
        print_margin(w)
        literal(w, line)
    end
    if !isnull(node.nxt)
        cr(w)
    end
    linebreak(w, node)
end
