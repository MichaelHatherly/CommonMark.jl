accepts_lines(::Paragraph) = true

continue_(::Paragraph, parser::Parser, ::Node) = parser.blank ? 1 : 0

function finalize(::Paragraph, p::Parser, block::Node)
    has_reference_defs = false
    # Try parsing the beginning as link reference definitions.
    while peek(block.string_content, 1) === '['
        pos = parse_reference(p.inline_parser, block.string_content, p.refmap)
        pos == 0 && break
        block.string_content = block.string_content[pos+1:end]
        has_reference_defs = true
    end
    if has_reference_defs && is_blank(block.string_content)
        unlink(block)
    end
    return nothing
end

can_contain(::Paragraph, t) = false
