module CommonMark

import JSON, URIParser

include("utils.jl")
include("ast.jl")
include("parsers.jl")
include("writers.jl")
include("extensions.jl")

# Interface
export Parser, enable!, disable!, html, latex, term

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
    BackslashEscapeRule,
    DoubleQuoteRule,
    HtmlEntityRule,
    HtmlInlineRule,
    ImageRule,
    InlineCodeRule,
    LinkRule,
    NewlineRule,
    SingleQuoteRule,
    TextRule,
    UnderscoreEmphasisRule

# Extension rules
export
    AdmonitionRule,
    FootnoteRule,
    FrontMatterRule,
    MathRule,
    TableRule

end # module
