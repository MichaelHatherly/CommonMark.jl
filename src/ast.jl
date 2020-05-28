abstract type AbstractContainer end
abstract type AbstractBlock <: AbstractContainer end
abstract type AbstractInline <: AbstractContainer end

is_container(::AbstractContainer) = false

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
        node.literal = ""
        return node
    end
end

const NULL_NODE = Node()
isnull(node::Node) = node === NULL_NODE

is_container(node::Node) = is_container(node.t)::Bool

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
            # Stay on node but exit.
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
