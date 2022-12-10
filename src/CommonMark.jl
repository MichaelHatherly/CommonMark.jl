module CommonMark

import JSON, URIs

include("utils.jl")
include("ast.jl")
include("parsers.jl")
include("writers.jl")
include("extensions.jl")

# Interface
export Parser, enable!, disable!, html, latex, term, markdown, notebook,
    frontmatter

# Core block rules
export
    AtxHeadingRule,
    BlockQuoteRule,
    FencedCodeBlockRule,
    HtmlBlockRule,
    IndentedCodeBlockRule,
    ListItemRule,
    SetextHeadingRule,
    ThematicBreakRule

# Core inline rules
export
    AsteriskEmphasisRule,
    AutolinkRule,
    HtmlEntityRule,
    HtmlInlineRule,
    ImageRule,
    InlineCodeRule,
    LinkRule,
    UnderscoreEmphasisRule

# Extension rules
export
    AdmonitionRule,
    AttributeRule,
    AutoIdentifierRule,
    CitationRule,
    DollarMathRule,
    FootnoteRule,
    FrontMatterRule,
    MathRule,
    RawContentRule,
    TableRule,
    TypographyRule

function debug_node(node::Node, indent = 0)
    if !isdefined(node, :t)
        return
    end
    print("\t"^indent, String(typeof(node.t).name.name))
    if !isdefined(node, :literal) || isempty(node.literal)
        println()
    else
        println(" [ ", node.literal, " ]")
    end
    if !isdefined(node, :first_child)
        return
    end
    ch = node.first_child
    last = node.last_child
    while true
        debug_node(ch, indent+1)
        if ch == last
            break
        end
        ch = ch.nxt
    end
end

end # module
