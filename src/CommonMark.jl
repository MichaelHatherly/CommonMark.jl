module CommonMark

include("utils.jl")
include("ast.jl")
include("parsers.jl")
include("writers.jl")
include("extensions.jl")
include("readers.jl")
include("precompile.jl")

isdefined(Base, :get_extension) || include("ExtensionLoader.jl")

# Interface
export Parser,
    enable!, disable!, html, latex, term, markdown, notebook, typst, json, frontmatter

# Core block rules
export AtxHeadingRule,
    BlockQuoteRule,
    FencedCodeBlockRule,
    HtmlBlockRule,
    IndentedCodeBlockRule,
    ListItemRule,
    SetextHeadingRule,
    ThematicBreakRule

# Core inline rules
export AsteriskEmphasisRule,
    AutolinkRule,
    HtmlEntityRule,
    HtmlInlineRule,
    ImageRule,
    InlineCodeRule,
    LinkRule,
    UnderscoreEmphasisRule

# Extension rules
export AdmonitionRule,
    AttributeRule,
    AutoIdentifierRule,
    CitationRule,
    DollarMathRule,
    FencedDivRule,
    FootnoteRule,
    FrontMatterRule,
    GitHubAlertRule,
    GridTableRule,
    MathRule,
    RawContentRule,
    ReferenceLinkRule,
    StrikethroughRule,
    MarkRule,
    SubscriptRule,
    SuperscriptRule,
    TableRule,
    ShortcodeRule,
    DefinitionListRule,
    TaskListRule,
    TypographyRule

# Container types: public API but not exported (requires qualified access)
# Must use eval(Meta.parse(...)) because `public` keyword doesn't exist in Julia < 1.11
# and would cause a parse error even inside @static if block
@static if VERSION >= v"1.11"
    eval(
        Meta.parse(
            """
    public Node,
        append_child, prepend_child, insert_after, insert_before, unlink, isnull, text,
        Document, Paragraph, Heading, BlockQuote, List, Item, CodeBlock, HtmlBlock, ThematicBreak,
        Text, SoftBreak, LineBreak, Code, Emph, Strong, Link, Image, HtmlInline,
        Table, TableHeader, TableBody, TableFoot, TableRow, TableCell,
        DisplayMath, Admonition, FencedDiv, FootnoteDefinition, LaTeXBlock, TypstBlock,
        Math, Strikethrough, Mark, Subscript, Superscript, LaTeXInline, TypstInline,
        GitHubAlert, TaskItem, FootnoteLink, Citation,
        ReferenceLink, ReferenceImage, ReferenceDefinition, UnresolvedReference,
        Shortcode, ShortcodeBlock, ShortcodeContext,
        DefinitionList, DefinitionTerm, DefinitionDescription
""",
        ),
    )
end

@docstring_parser Parser(enable = [AdmonitionRule(), TableRule()])

end # module
