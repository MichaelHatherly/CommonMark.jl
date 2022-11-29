#= These imports can be used to use this file outside of CommonMark:

using CommonMark: Node, AbstractContainer, NULL_NODE,
    Document, Paragraph, BlockQuote, ThematicBreak, HtmlBlock, DisplayMath,
    Heading, CodeBlock, Admonition, List, Item, FootnoteDefinition,
    LineBreak, Backslash, SoftBreak, Emph, Strong, HtmlInline, Math, FootnoteLink, Text,
    Code, Image, Link, JuliaValue, Table, TableBody, TableCell, TableHeader, TableRow
=#

import MarkdownAST

function Base.convert(::Type{MarkdownAST.Node}, node::Node)
    mdast = _mdast_node(node)
    let child = node.first_child
        while child != NULL_NODE
            mdast_child = convert(MarkdownAST.Node, child)
            push!(mdast.children, mdast_child)
            child = child.nxt
        end
    end
    return mdast
end

_mdast_node(node::Node) = _mdast_node(node, node.t)

# Fallback convert function
_mdast_node(node::Node, ::T) where {T <: AbstractContainer} = error("'$T' container not supported in MarkdownAST")

# For all singleton containers that map trivially (i.e. they have no attributes),
# we can have a single implementation.
const SINGLETON_CONTAINER_MAP = Dict(
    Document => MarkdownAST.Document,
    Paragraph => MarkdownAST.Paragraph,
    BlockQuote => MarkdownAST.BlockQuote,
    ThematicBreak => MarkdownAST.ThematicBreak,
    LineBreak => MarkdownAST.LineBreak,
    Backslash => MarkdownAST.Backslash,
    SoftBreak => MarkdownAST.SoftBreak,
    Emph => MarkdownAST.Emph,
    Strong => MarkdownAST.Strong,
    # CommonMark.Item contains a field, but it's discarded in MarkdownAST
    Item => MarkdownAST.Item,
    # Internal nodes for tables
    TableBody => MarkdownAST.TableBody,
    TableHeader => MarkdownAST.TableHeader,
    TableRow => MarkdownAST.TableRow,
)
const SINGLETON_CONTAINERS = Union{keys(SINGLETON_CONTAINER_MAP)...}
function _mdast_node(node::Node, container::SINGLETON_CONTAINERS)
    e = SINGLETON_CONTAINER_MAP[typeof(container)]()
    return MarkdownAST.Node(e)
end

# Some containers use the .literal field of the Node object to store the content,
# which generally maps to MarkdownAST.T(node.literal).
const LITERAL_CONTAINER_MAP = Dict(
    Text => MarkdownAST.Text,
    HtmlBlock => MarkdownAST.HTMLBlock,
    HtmlInline => MarkdownAST.HTMLInline,
    DisplayMath => MarkdownAST.DisplayMath,
    Math => MarkdownAST.InlineMath,
    Code => MarkdownAST.Code,
)
const LITERAL_CONTAINERS = Union{keys(LITERAL_CONTAINER_MAP)...}
function _mdast_node(node::Node, container::LITERAL_CONTAINERS)
    e = LITERAL_CONTAINER_MAP[typeof(container)](node.literal)
    return MarkdownAST.Node(e)
end

# Containers that need special handling
_mdast_node(n::Node, c::Heading) = MarkdownAST.Node(MarkdownAST.Heading(c.level))
_mdast_node(n::Node, c::Link) = MarkdownAST.Node(MarkdownAST.Link(c.destination, c.title))
_mdast_node(n::Node, c::Image) = MarkdownAST.Node(MarkdownAST.Image(c.destination, c.title))
_mdast_node(n::Node, c::List) = MarkdownAST.Node(MarkdownAST.List(c.list_data.type, c.list_data.tight))
_mdast_node(n::Node, c::CodeBlock) = MarkdownAST.Node(MarkdownAST.CodeBlock(c.info, n.literal))
_mdast_node(n::Node, c::Admonition) = MarkdownAST.Node(MarkdownAST.Admonition(c.category, c.title))
_mdast_node(n::Node, c::FootnoteDefinition) = MarkdownAST.Node(MarkdownAST.FootnoteDefinition(c.id))
_mdast_node(n::Node, c::FootnoteLink) = MarkdownAST.Node(MarkdownAST.FootnoteLink(c.id))
_mdast_node(n::Node, c::Table) = MarkdownAST.Node(MarkdownAST.Table(c.spec))
_mdast_node(n::Node, c::TableCell) = MarkdownAST.Node(MarkdownAST.TableCell(c.align, c.header, c.column))
_mdast_node(n::Node, c::JuliaValue) = MarkdownAST.Node(MarkdownAST.JuliaValue(c.ex, c.ref))

# Unsupported containers (no MarkdownAST equivalent currently):
#
# Attributes, Citation, CitationBracket, FrontMatter, ReferenceList, References,
# LaTeXBlock, LaTeXInline
#
# Should never appear in a CommonMark tree:
#
# TablePipe (internal use), TableComponent (abstract), JuliaExpression (internal use)
