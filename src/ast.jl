abstract type AbstractContainer end
abstract type AbstractBlock <: AbstractContainer end
abstract type AbstractInline <: AbstractContainer end

is_container(::AbstractContainer) = false

const SourcePos = NTuple{2,NTuple{2,Int}}

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
    literal_buffer::Union{Nothing,IOBuffer}
    meta::Union{Nothing,Dict{String,Any}}

    Node() = new()

    function Node(t::AbstractContainer, sourcepos = ((0, 0), (0, 0)))
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
        node.literal_buffer = nothing
        node.meta = nothing
        return node
    end
end

"""Finalize literal from buffer, converting IOBuffer to String."""
function finalize_literal!(node::Node)
    if node.literal_buffer !== nothing
        node.literal = String(take!(node.literal_buffer))
        node.literal_buffer = nothing
    end
end

"""Get meta value without allocating if meta is nothing."""
getmeta(node::Node, key, default) =
    isnothing(node.meta) ? default : get(node.meta, key, default)

"""Check if meta has key without allocating if meta is nothing."""
hasmeta(node::Node, key) = !isnothing(node.meta) && haskey(node.meta, key)

"""Set meta value, initializing dict if needed."""
function setmeta!(node::Node, key, value)
    isnothing(node.meta) && (node.meta = Dict{String,Any}())
    node.meta[key] = value
end

"""Merge dict into meta, initializing if needed."""
function mergemeta!(node::Node, d::AbstractDict)
    isnothing(node.meta) && (node.meta = Dict{String,Any}())
    merge!(node.meta, d)
end

function copy_tree(func::Function, root::Node)
    lookup = Dict{Node,Node}()
    for (old, enter) in root
        if enter
            lookup[old] = Node()
        end
    end
    for (old, enter) in root
        if enter
            new = lookup[old]

            # Custom copying of the node payload.
            new.t = func(old.t)

            new.parent = get(lookup, old.parent, NULL_NODE)
            new.first_child = get(lookup, old.first_child, NULL_NODE)
            new.last_child = get(lookup, old.last_child, NULL_NODE)
            new.prv = get(lookup, old.prv, NULL_NODE)
            new.nxt = get(lookup, old.nxt, NULL_NODE)

            new.sourcepos = old.sourcepos
            new.last_line_blank = old.last_line_blank
            new.last_line_checked = old.last_line_checked
            new.is_open = old.is_open
            new.literal = old.literal
            new.literal_buffer = nothing

            new.meta = isnothing(old.meta) ? nothing : copy(old.meta)
        end
    end
    return lookup[root]
end
copy_tree(root::Node) = copy_tree(identity, root)

const NULL_NODE = Node()

"""
    isnull(node::Node) -> Bool

Check if a node is the null node (empty reference).
"""
isnull(node::Node) = node === NULL_NODE

"""
    container_equal(a::AbstractContainer, b::AbstractContainer)

Compare two container types for equality, checking type and all fields.
"""
container_equal(a::T, b::T) where {T<:AbstractContainer} =
    all(getfield(a, f) == getfield(b, f) for f in fieldnames(T))
container_equal(::AbstractContainer, ::AbstractContainer) = false

"""
    ast_equal(a::Node, b::Node)

Compare two AST nodes for structural equality. Ignores source positions and
parser state, comparing only the semantic content: container types, literals,
and tree structure.
"""
function ast_equal(a::Node, b::Node)
    isnull(a) && isnull(b) && return true
    (isnull(a) || isnull(b)) && return false
    container_equal(a.t, b.t) || return false
    a.literal == b.literal || return false
    # Compare children
    ca, cb = a.first_child, b.first_child
    while !isnull(ca) && !isnull(cb)
        ast_equal(ca, cb) || return false
        ca, cb = ca.nxt, cb.nxt
    end
    isnull(ca) && isnull(cb)
end

is_container(node::Node) = is_container(node.t)::Bool

Base.show(io::IO, node::Node) = print(io, "Node($(typeof(node.t)))")

Base.IteratorSize(::Type{Node}) = Base.SizeUnknown()

function Base.iterate(node::Node, (sr, sc, se) = (node, node, true))
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

"""
    append_child(parent::Node, child::Node)

Add `child` as the last child of `parent`. Unlinks `child` from any previous location.
"""
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

"""
    prepend_child(parent::Node, child::Node)

Add `child` as the first child of `parent`. Unlinks `child` from any previous location.
"""
function prepend_child(node::Node, child::Node)
    unlink(child)
    child.parent = node
    if !isnull(node.first_child)
        node.first_child.prv = child
        child.nxt = node.first_child
        node.first_child = child
    else
        node.first_child = child
        node.last_child = child
    end
end

"""
    unlink(node::Node)

Remove `node` from its parent, updating sibling links. Safe to call on unlinked nodes.
"""
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

"""
    insert_after(node::Node, sibling::Node)

Insert `sibling` immediately after `node` in the tree.
"""
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

"""
    insert_before(node::Node, sibling::Node)

Insert `sibling` immediately before `node` in the tree.
"""
function insert_before(node::Node, sibling::Node)
    unlink(sibling)
    sibling.prv = node.prv
    if !isnull(sibling.prv)
        sibling.prv.nxt = sibling
    end
    sibling.nxt = node
    node.prv = sibling
    sibling.parent = node.parent
    if isnull(sibling.prv)
        sibling.parent.first_child = sibling
    end
end

# Builder helpers for Node(Type, children...) constructors.
_to_node(s::AbstractString) = text(s)
_to_node(n::Node) = n

function _build(t::AbstractContainer, children)
    node = Node(t)
    for child in children
        append_child(node, _to_node(child))
    end
    node
end
