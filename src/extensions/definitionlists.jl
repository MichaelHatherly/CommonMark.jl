"""
    DefinitionListRule()

Parse definition lists (Pandoc-compatible syntax).

Not enabled by default. Terms are plain paragraph lines, definitions start with
`:` followed by 1-3 spaces or a tab.

```markdown
Term 1
:   Definition 1a
:   Definition 1b

Term 2
:   Definition 2
```
"""
struct DefinitionListRule end

#
# AST types
#

mutable struct DefinitionList <: AbstractBlock
    tight::Bool
    DefinitionList() = new(true)
end

struct DefinitionTerm <: AbstractBlock end

struct DefinitionDescription <: AbstractBlock end

#
# Container interface
#

is_container(::DefinitionList) = true
is_container(::DefinitionTerm) = true
is_container(::DefinitionDescription) = true

accepts_lines(::DefinitionList) = false
accepts_lines(::DefinitionTerm) = false
accepts_lines(::DefinitionDescription) = false

can_contain(::DefinitionList, t) = t isa DefinitionTerm || t isa DefinitionDescription
can_contain(::DefinitionTerm, t) = false
# Prevents nested definition lists, matching Pandoc behavior.
can_contain(::DefinitionDescription, t) =
    !(t isa Item) &&
    !(t isa DefinitionList) &&
    !(t isa DefinitionTerm) &&
    !(t isa DefinitionDescription)

contains_inlines(::DefinitionTerm) = true

continue_(::DefinitionList, ::Parser, ::Node) = 0
continue_(::DefinitionTerm, ::Parser, ::Node) = 1

function continue_(::DefinitionDescription, parser::Parser, ::Any)
    if parser.indent >= 4
        advance_offset(parser, 4, true)
    elseif parser.blank
        advance_next_nonspace(parser)
    else
        return 1
    end
    return 0
end

function finalize(::DefinitionList, ::Parser, block::Node)
    dl = block.t::DefinitionList
    child = block.first_child
    while !isnull(child)
        if child.t isa DefinitionDescription
            # Check within DD for blank lines between sub-children
            subchild = child.first_child
            while !isnull(subchild)
                if ends_with_blank_line(subchild) && !isnull(subchild.nxt)
                    dl.tight = false
                    return nothing
                end
                subchild = subchild.nxt
            end
        end
        child = child.nxt
    end
    return nothing
end

finalize(::DefinitionTerm, ::Parser, ::Node) = nothing
finalize(::DefinitionDescription, ::Parser, ::Node) = nothing

#
# Node constructors
#

function Node(::Type{DefinitionList}, children...; tight::Bool = true)
    dl = DefinitionList()
    dl.tight = tight
    _build(dl, children)
end

Node(::Type{DefinitionTerm}, children...) = _build(DefinitionTerm(), children)
Node(::Type{DefinitionDescription}, children...) = _build(DefinitionDescription(), children)

#
# Parsing
#

const reDefinitionMarker = r"^:[ \t]{1,3}"

function parse_definition(parser, container)
    parser.indented && return 0
    ln = rest_from_nonspace(parser)
    m = match(reDefinitionMarker, ln)
    m === nothing && return 0

    # Case 1: container is a Paragraph (tight definition)
    if container.t isa Paragraph
        close_unmatched_blocks(parser)
        finalize_literal!(container)

        # Check if previous sibling is a DefinitionList we can extend
        prev = container.prv
        dl_node = if !isnull(prev) && prev.t isa DefinitionList
            prev.is_open = true
            parser.tip = prev
            prev
        else
            nothing
        end

        # Convert paragraph to term
        term_node = Node(DefinitionTerm(), container.sourcepos)
        term_node.literal = container.literal

        if dl_node === nothing
            # Create new DefinitionList
            dl_node = Node(DefinitionList(), container.sourcepos)
            insert_after(container, dl_node)
            unlink(container)
            append_child(dl_node, term_node)
            parser.tip = dl_node
        else
            unlink(container)
            append_child(dl_node, term_node)
        end

        # Add DefinitionDescription
        advance_next_nonspace(parser)
        advance_offset(parser, length(m.match), false)
        dd = add_child(parser, DefinitionDescription(), parser.pos)
        return 1

        # Case 2: container is a DefinitionList (additional definition)
    elseif container.t isa DefinitionList
        close_unmatched_blocks(parser)
        advance_next_nonspace(parser)
        advance_offset(parser, length(m.match), false)
        dd = add_child(parser, DefinitionDescription(), parser.pos)
        return 1

        # Case 3: fallback - check last_child for loose case or extending closed list
    else
        lc = container.last_child
        isnull(lc) && return 0

        # Loose case: last child is a closed Paragraph
        if lc.t isa Paragraph && !lc.is_open
            close_unmatched_blocks(parser)
            finalize_literal!(lc)

            # Check if sibling before the paragraph is a closed DefinitionList
            prev = lc.prv
            dl_node = if !isnull(prev) && prev.t isa DefinitionList
                prev.is_open = true
                parser.tip = prev
                prev
            else
                nothing
            end

            term_node = Node(DefinitionTerm(), lc.sourcepos)
            term_node.literal = lc.literal

            if dl_node === nothing
                dl_node = add_child(parser, DefinitionList(), lc.sourcepos[1][2])
                dl_node.t.tight = false
                unlink(lc)
                append_child(dl_node, term_node)
            else
                unlink(lc)
                append_child(dl_node, term_node)
            end

            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            dd = add_child(parser, DefinitionDescription(), parser.pos)
            return 1

            # Extending a closed DefinitionList
        elseif lc.t isa DefinitionList && !lc.is_open
            close_unmatched_blocks(parser)
            lc.is_open = true
            parser.tip = lc

            advance_next_nonspace(parser)
            advance_offset(parser, length(m.match), false)
            dd = add_child(parser, DefinitionDescription(), parser.pos)
            return 1
        end

        return 0
    end
end

block_rule(::DefinitionListRule) = Rule(parse_definition, 0.5, ":")

#
# Writers
#

# HTML

function write_html(::DefinitionList, rend, node, enter)
    if enter
        cr(rend)
        tag(rend, "dl", attributes(rend, node))
        cr(rend)
    else
        cr(rend)
        tag(rend, "/dl")
        cr(rend)
    end
end

function write_html(::DefinitionTerm, rend, node, enter)
    if enter
        tag(rend, "dt", attributes(rend, node))
    else
        tag(rend, "/dt")
        cr(rend)
    end
end

function write_html(::DefinitionDescription, rend, node, enter)
    if enter
        tag(rend, "dd", attributes(rend, node))
        cr(rend)
    else
        tag(rend, "/dd")
        cr(rend)
    end
end

# LaTeX

function write_latex(::DefinitionList, w, node, enter)
    cr(w)
    if enter
        literal(w, "\\begin{description}\n")
        if node.t.tight
            literal(w, "\\setlength{\\itemsep}{0pt}\n")
            literal(w, "\\setlength{\\parskip}{0pt}\n")
        end
    else
        literal(w, "\\end{description}")
    end
    cr(w)
end

function write_latex(::DefinitionTerm, w, node, enter)
    if enter
        literal(w, "\\item[")
    else
        literal(w, "]")
        cr(w)
    end
end

function write_latex(::DefinitionDescription, w, node, enter)
    # Content rendered by children, no explicit wrapper
    nothing
end

# Typst

function write_typst(::DefinitionList, w, node, enter)
    if !enter
        cr(w)
        linebreak(w, node)
    end
end

function write_typst(::DefinitionTerm, w, node, enter)
    if enter
        print_margin(w)
        literal(w, "/ ")
    else
        literal(w, ": ")
    end
end

function _typst_use_block(node)
    dl = node.parent.t::DefinitionList
    !dl.tight && return true
    # Multiple children in this DD
    !isnull(node.first_child) && !isnull(node.first_child.nxt) && return true
    # Adjacent DD sibling (multi-def)
    (!isnull(node.prv) && node.prv.t isa DefinitionDescription) && return true
    (!isnull(node.nxt) && node.nxt.t isa DefinitionDescription) && return true
    return false
end

function write_typst(::DefinitionDescription, w, node, enter)
    use_block = _typst_use_block(node)
    is_first = isnull(node.prv) || node.prv.t isa DefinitionTerm
    is_last = isnull(node.nxt) || node.nxt.t isa DefinitionTerm
    if enter
        if use_block && is_first
            literal(w, "#block[\n")
        end
        if !is_first
            cr(w)
            literal(w, "\n")
        end
    else
        if use_block && is_last
            cr(w)
            print_margin(w)
            literal(w, "]\n")
        end
        cr(w)
    end
end

# Markdown (roundtrip)

function write_markdown(::DefinitionList, w, node, enter)
    if !enter
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(::DefinitionTerm, w, node, enter)
    if enter
        print_margin(w)
    else
        cr(w)
    end
end

function write_markdown(::DefinitionDescription, w, node, enter)
    if enter
        push_margin!(w, 1, ":   ", " "^4)
    else
        pop_margin!(w)
        if !isnull(node.nxt) && node.nxt.t isa DefinitionTerm
            cr(w)
            print_margin_rstrip(w)
            literal(w, "\n")
        end
    end
end

# Terminal

function write_term(::DefinitionList, rend, node, enter)
    if !enter && !isnull(node.nxt)
        print_margin(rend)
        print_literal(rend, "\n")
    end
end

function write_term(::DefinitionTerm, rend, node, enter)
    style = crayon"bold"
    if enter
        rend.format.wrap = 0
        print_margin(rend)
        print_literal(rend, style)
        push_inline!(rend, style)
    else
        pop_inline!(rend)
        print_literal(rend, inv(style))
        rend.format.wrap = -1
        print_literal(rend, "\n")
    end
end

function write_term(::DefinitionDescription, rend, node, enter)
    if enter
        push_margin!(rend, "  ", crayon"")
    else
        pop_margin!(rend)
        if !isnull(node.nxt) && node.nxt.t isa DefinitionTerm
            # blank line before next term
        end
    end
end

# JSON (Pandoc AST)

function write_json(::DefinitionList, ctx, node, enter)
    if enter
        items = Any[]
        push_container!(ctx, items)
    else
        items = pop_container!(ctx)
        push_element!(ctx, json_el(ctx, "DefinitionList", items))
    end
end

function write_json(::DefinitionTerm, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        # Store term inlines as the first element of a [term, [defs...]] pair
        # We need to collect definitions that follow
        push_element!(ctx, inlines)
    end
end

function write_json(::DefinitionDescription, ctx, node, enter)
    if enter
        blocks = Any[]
        push_container!(ctx, blocks)
    else
        blocks = pop_container!(ctx)
        push_element!(ctx, blocks)
    end
end
