abstract type AbstractContainer end

abstract type AbstractBlock <: AbstractContainer end

struct BlockQuote <: AbstractBlock end

mutable struct CodeBlock <: AbstractBlock
    info::String
    is_fenced::Bool
    fence_char::Char
    fence_length::Int
    fence_offset::Int
    CodeBlock() = new("", false, '\0', 0, 0)
end

struct Document <: AbstractBlock end

mutable struct Heading <: AbstractBlock
    level::Int
    Heading() = new(0)
end

mutable struct HtmlBlock <: AbstractBlock
    html_block_type::Int
    HtmlBlock() = new(0)
end

mutable struct ListData
    type::String
    tight::Bool
    bullet_char::Char
    start::Int
    delimiter::String
    padding::Int
    marker_offset::Int
    ListData(indent=0) = new("", true, ' ', 1, "", 0, indent)
end

mutable struct Item <: AbstractBlock
    list_data::ListData
    Item() = new(ListData())
end

mutable struct List <: AbstractBlock
    list_data::ListData
    List() = new(ListData())
end

struct Paragraph <: AbstractBlock end
struct ThematicBreak <: AbstractBlock end

abstract type AbstractInline <: AbstractContainer end

struct SoftBreak <: AbstractInline end
struct LineBreak <: AbstractInline end

mutable struct Link <: AbstractInline
    destination::String
    title::String
    Link() = new("", "")
end

mutable struct Image <: AbstractInline
    destination::String
    title::String
    Image() = new("", "")
end

struct Emph <: AbstractInline end
struct Strong <: AbstractInline end
struct Code <: AbstractInline end
struct Text <: AbstractInline end
struct HtmlInline <: AbstractInline end

is_container(other::AbstractContainer) = false
is_container(::Document) = true
is_container(::BlockQuote) = true
is_container(::List) = true
is_container(::Item) = true
is_container(::Paragraph) = true
is_container(::Heading) = true
is_container(::Emph) = true
is_container(::Strong) = true
is_container(::Link) = true
is_container(::Image) = true

const SourcePos = NTuple{2, NTuple{2, Int}}

mutable struct Node
    t::AbstractContainer
    parent::Node
    first_child::Node
    last_child::Node
    prv::Node
    nxt::Node
    sourcepos::SourcePos
    last_line_blank::Bool
    last_line_checked::Bool
    is_open::Bool
    string_content::String
    literal::String

    Node() = new()

    function Node(t::AbstractContainer, sourcepos=((0, 0), (0, 0)))
        node = new()
        node.t = t
        node.parent = NULL_NODE
        node.first_child = NULL_NODE
        node.last_child = NULL_NODE
        node.prv = NULL_NODE
        node.nxt = NULL_NODE
        node.sourcepos = sourcepos
        node.last_line_blank = false
        node.last_line_checked = false
        node.is_open = true
        node.string_content = ""
        node.literal = ""
        return node
    end
end

const NULL_NODE = Node()
isnull(node::Node) = node === NULL_NODE

is_container(node::Node) = is_container(node.t)

Base.show(io::IO, node::Node) = print(io, "Node($(typeof(node.t)))")

Base.IteratorSize(::Type{Node}) = Base.SizeUnknown()

function Base.iterate(node::Node, (sr, sc, se)=(node, node, true))
    cur, entering = sc, se
    isnull(cur) && return nothing
    if entering && is_container(cur)
        if !isnull(cur.first_child)
            sc = cur.first_child
            se = true
        else
            # stay on node but exit
            se = false
        end
    elseif cur === sr
        sc = NULL_NODE
    elseif isnull(cur.nxt)
        sc = cur.parent
        se = false
    else
        sc = cur.nxt
        se = true
    end
    return (cur, entering), (sr, sc, se)
end

function append_child(node::Node, child::Node)
    unlink(child)
    child.parent = node
    if !isnull(node.last_child)
        node.last_child.nxt = child
        child.prv = node.last_child
        node.last_child = child
    else
        node.first_child = child
        node.last_child = child
    end
end

function prepend_child(node::Node, child::Node)
    unlink(child)
    child.parent = node
    if node.first_child
        node.first_child.prv = child
        child.nxt = node.first_child
        node.first_child = child
    else
        node.first_child = child
        node.last_child = child
    end
end

function unlink(node::Node)
    if !isnull(node.prv)
        node.prv.nxt = node.nxt
    elseif !isnull(node.parent)
        node.parent.first_child = node.nxt
    end

    if !isnull(node.nxt)
        node.nxt.prv = node.prv
    elseif !isnull(node.parent)
        node.parent.last_child = node.prv
    end

    node.parent = NULL_NODE
    node.nxt = NULL_NODE
    node.prv = NULL_NODE
end

function insert_after(node::Node, sibling::Node)
    unlink(sibling)
    sibling.nxt = node.nxt
    if !isnull(sibling.nxt)
        sibling.nxt.prv = sibling
    end
    sibling.prv = node
    node.nxt = sibling
    sibling.parent = node.parent
    if isnull(sibling.nxt)
        sibling.parent.last_child = sibling
    end
end

function insert_before(node::Node, sibling::Node)
    unlink(sibling)
    sibling.prv = node.prv
    if sibling.prv
        sibling.prv.nxt = sibling
    end
    sibling.nxt = node
    node.prv = sibling
    sibling.parent = node.parent
    if !sibling.prv
        sibling.parent.first_child = sibling
    end
end
