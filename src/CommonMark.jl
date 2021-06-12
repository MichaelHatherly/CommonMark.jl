module CommonMark

import JSON

include("utils.jl")
include("ast.jl")
include("parsers.jl")
include("writers.jl")
include("extensions.jl")

# Parsing
export
    Parser,
    enable!,
    disable!

# Formatting
export
    Fmt,
    ast,
    html,
    latex,
    markdown,
    notebook,
    term

# Templating
export
    TemplateExtension,
    ancestor,
    renderer

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

end # module
