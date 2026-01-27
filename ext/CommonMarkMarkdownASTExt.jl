# Bidirectional conversion between CommonMark.jl and MarkdownAST.jl ASTs.

module CommonMarkMarkdownASTExt

@static if isdefined(Base, :get_extension)
    import CommonMark
    import MarkdownAST
else
    import ..CommonMark
    import ..MarkdownAST
end

#
# CommonMark → MarkdownAST
#

"""
    MarkdownAST.Node(cm::CommonMark.Node) -> MarkdownAST.Node

Convert a CommonMark.jl AST to a MarkdownAST.jl AST.

# Examples

```julia
using CommonMark, MarkdownAST
cm = CommonMark.Parser()("# Hello **world**")
mast = MarkdownAST.Node(cm)
```
"""
function MarkdownAST.Node(cm::CommonMark.Node)
    cm.t isa CommonMark.Document || error("Expected Document root node")
    _to_mast(cm)
end

function MarkdownAST.Node(doc::CommonMark.LazyCommonMarkDoc)
    cm = CommonMark._parse_doc(doc)
    MarkdownAST.Node(cm)
end

# Interface implementation for cross-extension conversion
CommonMark.to_mast(doc::CommonMark.LazyCommonMarkDoc) = MarkdownAST.Node(doc)

Base.convert(::Type{MarkdownAST.Node}, doc::CommonMark.LazyCommonMarkDoc) =
    MarkdownAST.Node(doc)

function _to_mast(cm::CommonMark.Node)
    element = _cm_to_element(cm.t, cm)
    if isnothing(element)
        # Container being dropped - return children as vector
        nodes = MarkdownAST.Node[]
        child = cm.first_child
        while !CommonMark.isnull(child)
            result = _to_mast(child)
            if result isa Vector
                append!(nodes, result)
            elseif !isnothing(result)
                push!(nodes, result)
            end
            child = child.nxt
        end
        return nodes
    end
    node = MarkdownAST.Node(element)
    child = cm.first_child
    while !CommonMark.isnull(child)
        child_result = _to_mast(child)
        if child_result isa Vector
            for n in child_result
                push!(node.children, n)
            end
        elseif !isnothing(child_result)
            push!(node.children, child_result)
        end
        child = child.nxt
    end
    return node
end

# Block containers
_cm_to_element(::CommonMark.Document, cm) = MarkdownAST.Document()
_cm_to_element(::CommonMark.Paragraph, cm) = MarkdownAST.Paragraph()

function _cm_to_element(h::CommonMark.Heading, cm)
    MarkdownAST.Heading(h.level)
end

_cm_to_element(::CommonMark.BlockQuote, cm) = MarkdownAST.BlockQuote()

function _cm_to_element(l::CommonMark.List, cm)
    ld = l.list_data
    MarkdownAST.List(ld.type, ld.tight)
end

_cm_to_element(::CommonMark.Item, cm) = MarkdownAST.Item()

function _cm_to_element(cb::CommonMark.CodeBlock, cm)
    # Strip trailing newline that CommonMark adds
    code = cm.literal
    code = endswith(code, '\n') ? chop(code) : code
    MarkdownAST.CodeBlock(cb.info, code)
end

_cm_to_element(::CommonMark.ThematicBreak, cm) = MarkdownAST.ThematicBreak()

function _cm_to_element(::CommonMark.HtmlBlock, cm)
    MarkdownAST.HTMLBlock(cm.literal)
end

# Inline elements
function _cm_to_element(::CommonMark.Text, cm)
    MarkdownAST.Text(cm.literal)
end

_cm_to_element(::CommonMark.SoftBreak, cm) = MarkdownAST.SoftBreak()
_cm_to_element(::CommonMark.LineBreak, cm) = MarkdownAST.LineBreak()

function _cm_to_element(::CommonMark.Code, cm)
    MarkdownAST.Code(cm.literal)
end

_cm_to_element(::CommonMark.Emph, cm) = MarkdownAST.Emph()
_cm_to_element(::CommonMark.Strong, cm) = MarkdownAST.Strong()

function _cm_to_element(l::CommonMark.Link, cm)
    MarkdownAST.Link(l.destination, l.title)
end

function _cm_to_element(i::CommonMark.Image, cm)
    MarkdownAST.Image(i.destination, i.title)
end

function _cm_to_element(::CommonMark.HtmlInline, cm)
    MarkdownAST.HTMLInline(cm.literal)
end

_cm_to_element(::CommonMark.Backslash, cm) = MarkdownAST.Backslash()

# Tables
function _cm_to_element(t::CommonMark.Table, cm)
    MarkdownAST.Table(t.spec)
end

_cm_to_element(::CommonMark.TableHeader, cm) = MarkdownAST.TableHeader()
_cm_to_element(::CommonMark.TableBody, cm) = MarkdownAST.TableBody()
_cm_to_element(::CommonMark.TableRow, cm) = MarkdownAST.TableRow()

function _cm_to_element(tc::CommonMark.TableCell, cm)
    MarkdownAST.TableCell(tc.align, tc.header, tc.column)
end

# Extensions with MarkdownAST equivalents
function _cm_to_element(a::CommonMark.Admonition, cm)
    MarkdownAST.Admonition(a.category, a.title)
end

function _cm_to_element(::CommonMark.Math, cm)
    MarkdownAST.InlineMath(cm.literal)
end

function _cm_to_element(::CommonMark.DisplayMath, cm)
    MarkdownAST.DisplayMath(cm.literal)
end

function _cm_to_element(fd::CommonMark.FootnoteDefinition, cm)
    MarkdownAST.FootnoteDefinition(fd.id)
end

function _cm_to_element(fl::CommonMark.FootnoteLink, cm)
    MarkdownAST.FootnoteLink(fl.id)
end

function _cm_to_element(jv::CommonMark.JuliaValue, cm)
    MarkdownAST.JuliaValue(jv.ex, jv.ref)
end

function _cm_to_element(je::CommonMark.JuliaExpression, cm)
    # JuliaExpression becomes JuliaValue with just the expression
    MarkdownAST.JuliaValue(je.ex, nothing)
end

# DocStringSection is a wrapper used by docstring parsing - drop it, keep children
_cm_to_element(::CommonMark.DocStringSection, cm) = nothing

# Fallback: warn and skip
function _cm_to_element(t::CommonMark.AbstractContainer, cm)
    @warn "Unsupported CommonMark type for MarkdownAST conversion: $(typeof(t))"
    return nothing
end

#
# MarkdownAST → CommonMark
#

"""
    CommonMark.Node(mast::MarkdownAST.Node) -> CommonMark.Node

Convert a MarkdownAST.jl AST to a CommonMark.jl AST.

# Examples

```julia
using CommonMark, MarkdownAST
mast = @ast MarkdownAST.Document() do
    MarkdownAST.Heading(1) do
        "Hello"
    end
end
cm = CommonMark.Node(mast)
CommonMark.html(cm)
```
"""
function CommonMark.Node(mast::MarkdownAST.Node)
    mast.element isa MarkdownAST.Document || error("Expected Document root node")
    _to_cm(mast)
end

function _to_cm(mast::MarkdownAST.Node)
    node = _mast_to_node(mast.element, mast)
    isnothing(node) && return nothing
    for child in mast.children
        child_node = _to_cm(child)
        !isnothing(child_node) && CommonMark.append_child(node, child_node)
    end
    return node
end

# Block containers
_mast_to_node(::MarkdownAST.Document, m) = CommonMark.Node(CommonMark.Document())
_mast_to_node(::MarkdownAST.Paragraph, m) = CommonMark.Node(CommonMark.Paragraph())

function _mast_to_node(e::MarkdownAST.Heading, m)
    n = CommonMark.Node(CommonMark.Heading())
    n.t.level = e.level
    n
end

_mast_to_node(::MarkdownAST.BlockQuote, m) = CommonMark.Node(CommonMark.BlockQuote())

function _mast_to_node(e::MarkdownAST.List, m)
    n = CommonMark.Node(CommonMark.List())
    n.t.list_data.type = e.type
    n.t.list_data.tight = e.tight
    n.t.list_data.bullet_char = '-'
    n.t.list_data.delimiter = "."
    n
end

function _mast_to_node(::MarkdownAST.Item, m)
    CommonMark.Node(CommonMark.Item())
end

function _mast_to_node(e::MarkdownAST.CodeBlock, m)
    n = CommonMark.Node(CommonMark.CodeBlock())
    n.t.info = e.info
    n.t.is_fenced = true
    n.t.fence_char = '`'
    n.t.fence_length = max(3, max_backtick_run(e.code) + 1)
    n.literal = endswith(e.code, '\n') ? e.code : e.code * "\n"
    n
end

function max_backtick_run(s::AbstractString)
    max_run = 0
    current = 0
    for c in s
        if c == '`'
            current += 1
            max_run = max(max_run, current)
        else
            current = 0
        end
    end
    return max_run
end

_mast_to_node(::MarkdownAST.ThematicBreak, m) = CommonMark.Node(CommonMark.ThematicBreak())

function _mast_to_node(e::MarkdownAST.HTMLBlock, m)
    n = CommonMark.Node(CommonMark.HtmlBlock())
    n.literal = e.html
    n
end

# Inline elements
function _mast_to_node(e::MarkdownAST.Text, m)
    n = CommonMark.Node(CommonMark.Text())
    n.literal = e.text
    n
end

_mast_to_node(::MarkdownAST.SoftBreak, m) = CommonMark.Node(CommonMark.SoftBreak())
_mast_to_node(::MarkdownAST.LineBreak, m) = CommonMark.Node(CommonMark.LineBreak())

function _mast_to_node(e::MarkdownAST.Code, m)
    n = CommonMark.Node(CommonMark.Code())
    n.literal = e.code
    n
end

function _mast_to_node(::MarkdownAST.Emph, m)
    n = CommonMark.Node(CommonMark.Emph())
    n.literal = "*"  # Delimiter hint for markdown writer
    n
end

function _mast_to_node(::MarkdownAST.Strong, m)
    n = CommonMark.Node(CommonMark.Strong())
    n.literal = "**"  # Delimiter hint for markdown writer
    n
end

function _mast_to_node(e::MarkdownAST.Link, m)
    n = CommonMark.Node(CommonMark.Link())
    n.t.destination = e.destination
    n.t.title = e.title
    n
end

function _mast_to_node(e::MarkdownAST.Image, m)
    n = CommonMark.Node(CommonMark.Image())
    n.t.destination = e.destination
    n.t.title = e.title
    n
end

function _mast_to_node(e::MarkdownAST.HTMLInline, m)
    n = CommonMark.Node(CommonMark.HtmlInline())
    n.literal = e.html
    n
end

_mast_to_node(::MarkdownAST.Backslash, m) = CommonMark.Node(CommonMark.Backslash())

# Tables
function _mast_to_node(e::MarkdownAST.Table, m)
    CommonMark.Node(CommonMark.Table(e.spec))
end

_mast_to_node(::MarkdownAST.TableHeader, m) = CommonMark.Node(CommonMark.TableHeader())
_mast_to_node(::MarkdownAST.TableBody, m) = CommonMark.Node(CommonMark.TableBody())
_mast_to_node(::MarkdownAST.TableRow, m) = CommonMark.Node(CommonMark.TableRow())

function _mast_to_node(e::MarkdownAST.TableCell, m)
    CommonMark.Node(CommonMark.TableCell(e.align, e.header, e.column))
end

# Extensions with CommonMark equivalents
function _mast_to_node(e::MarkdownAST.Admonition, m)
    CommonMark.Node(CommonMark.Admonition(e.category, e.title))
end

function _mast_to_node(e::MarkdownAST.InlineMath, m)
    n = CommonMark.Node(CommonMark.Math())
    n.literal = e.math
    n
end

function _mast_to_node(e::MarkdownAST.DisplayMath, m)
    n = CommonMark.Node(CommonMark.DisplayMath())
    n.literal = e.math
    n
end

function _mast_to_node(e::MarkdownAST.FootnoteDefinition, m)
    CommonMark.Node(CommonMark.FootnoteDefinition(e.id))
end

function _mast_to_node(e::MarkdownAST.FootnoteLink, m)
    CommonMark.Node(CommonMark.FootnoteLink, e.id)
end

function _mast_to_node(e::MarkdownAST.JuliaValue, m)
    CommonMark.Node(CommonMark.JuliaValue(e.ex, e.ref))
end

# Fallback: warn and skip
function _mast_to_node(e::MarkdownAST.AbstractElement, m)
    @warn "Unsupported MarkdownAST type for CommonMark conversion: $(typeof(e))"
    return nothing
end

end # module
