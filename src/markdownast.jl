const AbstractContainer = MarkdownAST.AbstractElement
using MarkdownAST: AbstractBlock, AbstractInline

# MarkdownAST.Node does not allow uninitialized fields., so we put this in .t
# for NULL_NODE
struct NullElement <: AbstractContainer end

const SourcePos = NTuple{2, NTuple{2, Int}}

mutable struct NodeMeta
    sourcepos::SourcePos
    last_line_blank::Bool
    last_line_checked::Bool
    is_open::Bool
    literal::String
    meta::Dict{String,Any}

    function NodeMeta(sourcepos=((0, 0), (0, 0)))
        m = new()
        m.sourcepos = sourcepos
        m.last_line_blank = false
        m.last_line_checked = false
        m.is_open = true
        m.literal = ""
        m.meta = Dict{String,Any}()
        return m
    end
end

const Node = MarkdownAST.Node{NodeMeta}
Node(t::AbstractContainer, sourcepos::SourcePos) = Node(t, NodeMeta(sourcepos))
Node(t::AbstractContainer) = Node(t, NodeMeta())
Node() = Node(NullElement())

const NULL_NODE = Node()
isnull(node::Node) = (node.element isa NullElement)

function Base.getproperty(node::Node, name::Symbol)
    if name === :parent
        n = getfield(node, :parent)
        isnothing(n) ? NULL_NODE : n
    elseif name === :first_child
        n = getfield(node, :first_child)
        isnothing(n) ? NULL_NODE : n
    elseif name === :last_child
        n = getfield(node, :last_child)
        isnothing(n) ? NULL_NODE : n
    elseif name === :prv
        n = getfield(node, :prv)
        isnothing(n) ? NULL_NODE : n
    elseif name === :nxt
        n = getfield(node, :nxt)
        isnothing(n) ? NULL_NODE : n
    elseif name === :sourcepos
        getfield(node, :meta).sourcepos
    elseif name === :last_line_blank
        getfield(node, :meta).last_line_blank
    elseif name === :last_line_checked
        getfield(node, :meta).last_line_checked
    elseif name === :is_open
        getfield(node, :meta).is_open
    elseif name === :literal
        getfield(node, :meta).literal
    elseif name === :meta
        getfield(node, :meta).meta
    else
        invoke(getproperty, Tuple{MarkdownAST.Node, Symbol}, node, name)
    end
end

function Base.setproperty!(node::Node, name::Symbol, x)
    if name === :parent
        setfield!(node, :parent, (x === NULL_NODE) ? nothing : x)
    elseif name === :first_child
        setfield!(node, :first_child, (x === NULL_NODE) ? nothing : x)
    elseif name === :last_child
        setfield!(node, :last_child, (x === NULL_NODE) ? nothing : x)
    elseif name === :prv
        setfield!(node, :prv, (x === NULL_NODE) ? nothing : x)
    elseif name === :nxt
        setfield!(node, :nxt, (x === NULL_NODE) ? nothing : x)
    elseif name === :sourcepos
        getfield(node, :meta).sourcepos = x
    elseif name === :last_line_blank
        getfield(node, :meta).last_line_blank = x
    elseif name === :last_line_checked
        getfield(node, :meta).last_line_checked = x
    elseif name === :is_open
        getfield(node, :meta).is_open = x
    elseif name === :literal
        getfield(node, :meta).literal = x
    elseif name === :meta
        getfield(node, :meta).meta = x
    else
        invoke(setproperty!, Tuple{MarkdownAST.Node, Symbol, Any}, node, name, x)
    end
end

# Import the elements from MarkdownAST. Some need to be renamed, and some can not be
# included because the implementation in MarkdownAST has a different structure.
using MarkdownAST:
    Admonition,
    FootnoteDefinition,
    #DisplayMath, -- depends on .literal
    BlockQuote,
    ThematicBreak,
    #List, -- list elements have a different structure on CM
    #Item,
    Paragraph,
    Heading,
    #CodeBlock, -- depends on .literal, and CM also has heaps of extra fields
    Document,
    Table,
    TableComponent,
    TableHeader,
    TableBody,
    TableRow,
    TableCell
#const HtmlBlock = MarkdownAST.HTMLBlock
using MarkdownAST:
    #Text, -- depends on .literal
    JuliaValue,
    #FootnoteLink, -- CM has .rule field not present in MDAST
    Link,
    Image,
    Backslash,
    SoftBreak,
    LineBreak,
    #Code, -- depends on .literal
    Emph,
    Strong
#const Math = MarkdownAST.InlineMath -- depends on .literal
#const HtmlInline = MarkdownAST.HTMLInline -- depends on .literal

# Fallback constructors. MarkdownAST generally doesn't allow constructing elements that
# do not make sense semantically, but CommonMark relies on the ability to create these
# "null" instances of elements in some cases.
function MarkdownAST.Heading()
    # MarkdownAST doesn't allow .level == 0 headings officially
    h = Heading(1)
    h.level = 0
    return h
end
MarkdownAST.Link() = Link("", "")
MarkdownAST.Image() = Image("", "")
