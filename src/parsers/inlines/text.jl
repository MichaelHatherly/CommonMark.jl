struct SoftBreak <: AbstractInline end
struct LineBreak <: AbstractInline end

function parse_string(parser::InlineParser, block::Node)
    m = consume(parser, match(reMain, parser))
    m === nothing && return false
    n = m.match
    if get(parser.options, "smart", false)
        n = replace(n, reEllipses => "\u2026")
        n = replace(n, reDash => smart_dashes)
    end
    append_child(block, text(n))
    return true
end

function parse_newline(parser::InlineParser, block::Node)
    @assert read(parser, Char) === '\n'
    lastc = block.last_child
    if !isnull(lastc) && lastc.t isa Text && endswith(lastc.literal, ' ')
        child = Node(endswith(lastc.literal, "  ") ? LineBreak() : SoftBreak())
        lastc.literal = rstrip(lastc.literal)
        append_child(block, child)
    else
        append_child(block, Node(SoftBreak()))
    end
    # Gobble leading spaces in next line.
    consume(parser, match(reInitialSpace, parser))
    return true
end

function smart_dashes(chars::AbstractString)
    en_count, em_count, n = 0, 0, length(chars)
    if n % 3 == 0
        # If divisible by 3, use all em dashes.
        em_count = n ÷ 3
    elseif n % 2 == 0
        # If divisble by 2, use all en dashes.
        en_count = n ÷ 2
    elseif n % 3 == 2
        # If 2 extra dashes, use en dashfor last 2; em dashes for rest.
        en_count, em_count = 1, (n - 2) ÷ 3
    else
        # Use en dashes for last 4 hyphens; em dashes for rest.
        en_count, em_count = 2, (n - 4) ÷ 3
    end
    return ('\u2014'^em_count) * ('\u2013'^en_count)
end

struct Text <: AbstractInline end

function text(s::AbstractString)
    node = Node(Text())
    node.literal = s
    return node
end
text(c::AbstractChar) = text(string(c))
