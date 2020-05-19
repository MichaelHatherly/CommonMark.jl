function parse_html_tag(parser::InlineParser, block::Node)
    m = consume(parser, match(reHtmlTag, parser))
    m === nothing && return false
    node = Node(HtmlInline())
    node.literal = m.match
    append_child(block, node)
    return true
end

function parse_entity(parser::InlineParser, block::Node)
    m = consume(parser, match(reEntityHere, parser))
    m === nothing && return false
    append_child(block, text(HTMLunescape(m.match)))
    return true
end

