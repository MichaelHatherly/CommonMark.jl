"""Text paragraph containing inline content."""
struct Paragraph <: AbstractBlock end

is_container(::Paragraph) = true

accepts_lines(::Paragraph) = true

continue_(::Paragraph, parser::Parser, ::Node) = parser.blank ? 1 : 0

function finalize(::Paragraph, p::Parser, block::Node)
    finalize_literal!(block)
    strip_reference_definitions!(p, block)
    # Definitions are not content, so a paragraph left with nothing else is not
    # a paragraph at all. A setext underline strips them the same way, leaving
    # the emptied paragraph here to be dropped.
    is_blank(block.literal) && unlink(block)
    return nothing
end

can_contain(::Paragraph, t) = false

Node(::Type{Paragraph}, children...) = _build(Paragraph(), children)
