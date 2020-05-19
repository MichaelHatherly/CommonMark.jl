accepts_lines(::CodeBlock) = true

function continue_(::CodeBlock, parser::Parser, container::Node)
    ln = parser.current_line
    indent = parser.indent
    if container.t.is_fenced
        match = indent <= 3 &&
            length(ln) >= parser.next_nonspace + 1 &&
            ln[parser.next_nonspace] == container.t.fence_char &&
            Base.match(reClosingCodeFence, SubString(ln, parser.next_nonspace))
        t = indent <= 3 && length(ln) >= parser.next_nonspace + 1 &&
            ln[parser.next_nonspace] == container.t.fence_char
        m = t ? Base.match(reClosingCodeFence, SubString(ln, parser.next_nonspace)) : nothing
        if m !== nothing && length(m.match) >= container.t.fence_length
            # closing fence - we're at end of line, so we can return
            finalize(parser, container, parser.line_number)
            return 2
        else
            # skip optional spaces of fence offset
            i = container.t.fence_offset
            while i > 0 && is_space_or_tab(peek(ln, parser.offset))
                advance_offset(parser, 1, true)
                i -= 1
            end
        end
    else
        # indented
        if indent >= CODE_INDENT
            advance_offset(parser, CODE_INDENT, true)
        elseif parser.blank
            advance_next_nonspace(parser)
        else
            return 1
        end
    end
    return 0
end

# TODO: make more robust.
function split_info_line(str)
    line = rstrip(lstrip(str, '{'), '}')
    return split(line, ' ')
end

function finalize(::CodeBlock, parser::Parser, block::Node)
    if block.t.is_fenced
        # first line becomes info string
        first_line, rest = split(block.string_content, '\n'; limit=2)
        info = unescape_string(strip(first_line))
        parts = split_info_line(info)
        if haskey(parser.fenced_literals, get(parts, 1, nothing))
            fn = parser.fenced_literals[parts[1]]
            fn(block, parts, rest)
        else
            block.t.info = info
            block.literal = rest
        end
    else
        # indented
        block.literal = replace(block.string_content, r"(\n *)+$" => "\n")
    end
    block.string_content = ""
    return nothing
end

can_contain(t) = false

function fenced_code_block(parser::Parser, container::Node)
    if !parser.indented
        m = Base.match(reCodeFence, SubString(parser.current_line, parser.next_nonspace))
        if m !== nothing
            fence_length = length(m.match)
            close_unmatched_blocks(parser)
            container = add_child(parser, CodeBlock(), parser.next_nonspace)
            container.t.is_fenced = true
            container.t.fence_length = fence_length
            container.t.fence_char = m.match[1]
            container.t.fence_offset = parser.indent
            advance_next_nonspace(parser)
            advance_offset(parser, fence_length, false)
            return 2
        end
    end
    return 0
end

function indented_code_block(parser::Parser, container::Node)
    if parser.indented && !(parser.tip.t isa Paragraph) && !parser.blank
        # indented code
        advance_offset(parser, CODE_INDENT, true)
        close_unmatched_blocks(parser)
        add_child(parser, CodeBlock(), parser.offset)
        return 2
    end
    return 0
end
