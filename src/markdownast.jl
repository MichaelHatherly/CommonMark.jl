const AbstractContainer = MarkdownAST.AbstractElement
using MarkdownAST: AbstractBlock, AbstractInline

# MarkdownAST.Node does not allow uninitialized fields., so we put this in .t
# for NULL_NODE
struct NullElement <: AbstractContainer end

const SourcePos = NTuple{2, NTuple{2, Int}}

# A few elements / containers have extra fields in CM, relative to MarkdownAST.
# This here implements a workaround where node.meta.elementextra
abstract type AbstractElementExtra end
struct ElementWrapper{T <: MarkdownAST.AbstractElement, U <: AbstractElementExtra} <: MarkdownAST.AbstractElement
    element::T
    extra::U
    ElementWrapper(element::T, extra::U) where {T, U} = new{T,U}(element, extra)
end

function Base.getproperty(ew::ElementWrapper{T,U}, name::Symbol) where {T, U}
    if name in fieldnames(U)
        getproperty(getfield(ew, :extra), name)
    else
        getproperty(getfield(ew, :element), name)
    end
end
function Base.setproperty!(ew::ElementWrapper{T,U}, name::Symbol, x) where {T, U}
    if name in fieldnames(U)
        setproperty!(getfield(ew, :extra), name, x)
    else
        setproperty!(getfield(ew, :element), name, x)
    end
end

mutable struct CodeBlockExtra <: AbstractElementExtra
    is_fenced::Bool
    fence_char::Char
    fence_length::Int
    fence_offset::Int
    CodeBlockExtra() = new(false, '\0', 0, 0)
end
const CodeBlock = ElementWrapper{MarkdownAST.CodeBlock, CodeBlockExtra}
CodeBlock() = ElementWrapper(MarkdownAST.CodeBlock("", ""), CodeBlockExtra())
hasextrafields(::MarkdownAST.CodeBlock) = true

mutable struct HtmlBlockExtra <: AbstractElementExtra
    html_block_type::Int
    HtmlBlockExtra() = new(0)
end
const HtmlBlock = ElementWrapper{MarkdownAST.HTMLBlock, HtmlBlockExtra}
HtmlBlock() = ElementWrapper(MarkdownAST.HTMLBlock(""), HtmlBlockExtra())
hasextrafields(::MarkdownAST.HTMLBlock) = true

mutable struct ListData
    list::MarkdownAST.List
    bullet_char::Char
    start::Int
    delimiter::String
    padding::Int
    marker_offset::Int
    ListData(indent=0) = new(MarkdownAST.List(:bullet, true), ' ', 1, "", 0, indent)
end
Base.propertynames(::ListData) = (:type, :tight, fieldnames(ListData)...)
function Base.getproperty(list_data::ListData, name::Symbol)
    (name in [:type, :tight]) ? getproperty(list_data.list, name) : getfield(list_data, name)
end
function Base.setproperty!(list_data::ListData, name::Symbol, x)
    if name in [:type, :tight]
        setproperty!(list_data.list, name, x)
    else
        setfield!(list_data, name, convert(fieldtype(ListData, name), x))
    end
end
mutable struct ListItemExtra <: AbstractElementExtra
    list_data :: ListData
end
const List = ElementWrapper{MarkdownAST.List, ListItemExtra}
function List()
    list_data = ListData()
    ElementWrapper(list_data.list, ListItemExtra(list_data))
end
hasextrafields(::MarkdownAST.List) = true
const Item = ElementWrapper{MarkdownAST.Item, ListItemExtra}
Item() = ElementWrapper(MarkdownAST.Item(), ListItemExtra(ListData()))
hasextrafields(::MarkdownAST.Item) = true

hasextrafields(::MarkdownAST.AbstractElement) = false # fallback

mutable struct NodeMeta
    sourcepos::SourcePos
    last_line_blank::Bool
    last_line_checked::Bool
    is_open::Bool
    literal::String
    meta::Dict{String,Any}
    # This field is for storing the extra fields of the current element
    ew::ElementWrapper

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
Node(t::AbstractContainer, sourcepos::SourcePos) = Node(reset_literal_element!(t), NodeMeta(sourcepos))
Node(t::AbstractContainer) = Node(reset_literal_element!(t), NodeMeta())
Node() = Node(NullElement())

function Base.getproperty(node::Node, name::Symbol)
    if name === :t
        hasextrafields(getfield(node, :t)) ? getfield(node, :meta).ew : getfield(node, :t)
    elseif name === :parent
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
        getliteral(node)
    elseif name === :meta
        getfield(node, :meta).meta
    else
        invoke(getproperty, Tuple{MarkdownAST.Node, Symbol}, node, name)
    end
end

function Base.setproperty!(node::Node, name::Symbol, x)
    if name === :t
        if x isa ElementWrapper
            setfield!(node, :t, reset_literal_element!(getfield(x, :element), node.literal))
            setfield!(getfield(node, :meta), :ew, x)
        else
            setfield!(node, :t, reset_literal_element!(x, node.literal))
        end
    elseif name === :parent
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
        setliteral!(node, x)
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
    DisplayMath,
    BlockQuote,
    ThematicBreak,
    #List, -- list elements have a different structure on CM
    #Item,
    Paragraph,
    Heading,
    #CodeBlock, -- handled via ElementWrapper
    Document,
    Table,
    TableComponent,
    TableHeader,
    TableBody,
    TableRow,
    TableCell
#const HtmlBlock = MarkdownAST.HTMLBlock -- handled via ElementWrapper
using MarkdownAST:
    Text,
    JuliaValue,
    #FootnoteLink, -- handled via ElementWrapper
    Link,
    Image,
    Backslash,
    SoftBreak,
    LineBreak,
    Code,
    Emph,
    Strong
const Math = MarkdownAST.InlineMath
const HtmlInline = MarkdownAST.HTMLInline

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
MarkdownAST.Text() = Text("")
MarkdownAST.Code() = Code("")
MarkdownAST.DisplayMath() = DisplayMath("")
MarkdownAST.InlineMath() = MarkdownAST.InlineMath("")
MarkdownAST.HTMLInline() = MarkdownAST.HTMLInline("")

# This is a workaround for elements / containers which in CM store their contents
# in the .literal field, rather than in the .element object itself. So what we do is that,
# for the nodes that have such an element, we return the value from the .element instead.
# When setting, we set both the .meta.literal and the element fields.
literalfield(::Text) = :text
#literalfield(::Union{Code}) = :code
literalfield(::Union{CodeBlock,Code}) = :code
literalfield(::Union{DisplayMath,MarkdownAST.InlineMath}) = :math
#literalfield(::Union{MarkdownAST.HTMLInline}) = :html
literalfield(::Union{MarkdownAST.HTMLBlock,MarkdownAST.HTMLInline}) = :html
literalfield(::Any) = nothing
function getliteral(node::Node)
    field = literalfield(node.element)
    if field !== nothing
        # Just in case, we check for a mismatch between the element and meta literal values.
        # This will happen in copy_free(), so we ignore that, but we shouldn't get it otherwise,
        # in which case we print a warning for now.
        if getproperty(node.element, field) != getfield(node, :meta).literal
            if !any(sf -> sf.func == :copy_tree, stacktrace())
                st = sprint(show, "text/plain", stacktrace())
                @warn "A literal mismatch: $(node.element)\n$(st)" getfield(node.element, field) getfield(node, :meta).literal
            end
        end
    end
    getfield(node, :meta).literal
end
function setliteral!(node::Node, x)
    field = literalfield(node.element)
    (field === nothing) || setproperty!(node.element, field, convert(String, x))
    getfield(node, :meta).literal = x
    return x
end
# This makes sure we reset the element fields if pass an element that has a non-empty
# literal string to the Node() constructor (where .literal defaults to ""), or when we
# update the .t field of a node.
function reset_literal_element!(element::AbstractContainer, literal = "")
    field = literalfield(element)
    (field === nothing) || setproperty!(element, field, literal)
    return element
end

const NULL_NODE = Node()
isnull(node::Node) = (node.element isa NullElement)

# FootnoteRule temporarily moved here so that definition would be available
struct FootnoteRule
    cache::Dict{String, Node}
    FootnoteRule() = new(Dict())
end
struct FootnoteLinkExtra <: AbstractElementExtra
    rule::FootnoteRule
end
const FootnoteLink = ElementWrapper{MarkdownAST.FootnoteLink, FootnoteLinkExtra}
FootnoteLink(id, rule) = ElementWrapper(MarkdownAST.FootnoteLink(id), FootnoteLinkExtra(rule))
hasextrafields(::MarkdownAST.FootnoteLink) = true
