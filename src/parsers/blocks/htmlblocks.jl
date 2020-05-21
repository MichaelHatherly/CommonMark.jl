accepts_lines(::HtmlBlock) = true

function continue_(::HtmlBlock, parser::Parser, container::Node)
    (parser.blank && container.t.html_block_type in 6:7) ? 1 : 0
end

function finalize(::HtmlBlock, parser::Parser, block::Node)
    block.literal = replace(block.string_content, r"(\n *)+$" => "")
    # allow GC
    block.string_content = ""
    return nothing
end

can_contain(::HtmlBlock, t) = false

function html_block(parser::Parser, container::Node)
    if !parser.indented && get(parser.current_line, parser.next_nonspace, nothing) == '<'
        s = SubString(parser.current_line, parser.next_nonspace)
        for (block_type, regex) in enumerate(reHtmlBlockOpen)
            if occursin(regex, s) && (block_type < 7 || !(container.t isa Paragraph))
                close_unmatched_blocks(parser)
                # Don't adjust parser.offset; spaces are part of HTML block.
                b = add_child(parser, HtmlBlock(), parser.offset)
                b.t.html_block_type = block_type
                return 2
            end
        end
    end
    return 0
end
