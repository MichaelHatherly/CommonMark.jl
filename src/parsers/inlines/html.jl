struct HtmlInline <: AbstractInline end

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

"""
    HtmlInlineRule()

Parse inline HTML tags.

Enabled by default. Passes through raw HTML tags unchanged.

```markdown
This has <em>inline HTML</em> tags.
```
"""
struct HtmlInlineRule end
inline_rule(::HtmlInlineRule) = Rule(parse_html_tag, 2, "<")

"""
    HtmlEntityRule()

Parse HTML entities (`&amp;`, `&#123;`, `&#x7B;`).

Enabled by default. Converts entities to their Unicode equivalents.

```markdown
&copy; &amp; &#60; &#x3C;
```
"""
struct HtmlEntityRule end
inline_rule(::HtmlEntityRule) = Rule(parse_entity, 1, "&")
