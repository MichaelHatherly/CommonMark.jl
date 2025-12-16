struct BlockQuote <: AbstractBlock end

is_container(::BlockQuote) = true

accepts_lines(::BlockQuote) = false

function continue_(::BlockQuote, parser::Parser, container::Node)
    if !parser.indented && peek_nonspace(parser) == '>'
        advance_next_nonspace(parser)
        advance_offset(parser, 1, false)
        if is_space_or_tab(trypeek(parser, UInt8))
            advance_offset(parser, 1, true)
        end
    else
        return 1
    end
    return 0
end

finalize(::BlockQuote, ::Parser, ::Node) = nothing

can_contain(::BlockQuote, t) = !(t isa Item)

function block_quote(parser::Parser, container::Node)
    if !parser.indented && peek_nonspace(parser) == '>'
        advance_next_nonspace(parser)
        advance_offset(parser, 1, false)
        # optional following space
        if is_space_or_tab(trypeek(parser, UInt8))
            advance_offset(parser, 1, true)
        end
        close_unmatched_blocks(parser)
        add_child(parser, BlockQuote(), parser.next_nonspace)
        return 1
    end
    return 0
end

struct BlockQuoteRule end
block_rule(::BlockQuoteRule) = Rule(block_quote, 1, ">")
