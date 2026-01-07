# Extension for preserving reference links in AST

"""
    ReferenceLinkRule()

Preserve reference link style in the AST.

Not enabled by default. By default, reference links are resolved to inline
links during parsing. This rule preserves the original reference style
(full, collapsed, or shortcut) for roundtrip rendering.

```markdown
[full style][ref]
[collapsed style][]
[shortcut style]

[ref]: https://example.com
```

## AST Node Types

When enabled, this rule produces these node types:

- `ReferenceLink` / `ReferenceImage` - resolved reference links with fields:
  - `destination::String` - the URL
  - `title::String` - optional title
  - `label::String` - the reference label
  - `style::Symbol` - `:full`, `:collapsed`, or `:shortcut`

- `ReferenceDefinition` - block node for `[label]: url` definitions

- `UnresolvedReference` - references with undefined labels:
  - `label::String` - the reference label
  - `style::Symbol` - `:full`, `:collapsed`, or `:shortcut`
  - `image::Bool` - true for `![...]` syntax

## Finding Undefined References

The `UnresolvedReference` type enables programmatic detection of broken links:

```julia
p = Parser()
enable!(p, ReferenceLinkRule())
ast = p(markdown_text)

undefined = [n.t for (n, entering) in ast
             if entering && n.t isa CommonMark.UnresolvedReference]
# Each has: label, style (:full/:collapsed/:shortcut), image (Bool)
```
"""
struct ReferenceLinkRule end

# AST types

mutable struct ReferenceLink <: AbstractInline
    destination::String
    title::String
    label::String
    style::Symbol  # :full, :collapsed, :shortcut
end

is_container(::ReferenceLink) = true

mutable struct ReferenceImage <: AbstractInline
    destination::String
    title::String
    label::String
    style::Symbol
end

is_container(::ReferenceImage) = true

# Node for reference links with undefined labels
mutable struct UnresolvedReference <: AbstractInline
    label::String
    style::Symbol
    image::Bool
end

is_container(::UnresolvedReference) = true

# Block type for reference definitions
struct ReferenceDefinition <: AbstractBlock
    label::String
    destination::String
    title::String
end

is_container(::ReferenceDefinition) = false
accepts_lines(::ReferenceDefinition) = false
can_contain(::ReferenceDefinition, t) = false
continue_(::ReferenceDefinition, ::Parser, ::Node) = 1
finalize(::ReferenceDefinition, ::Parser, ::Node) = nothing

# Node constructors for programmatic AST building

const REFLINK_STYLES = (:full, :collapsed, :shortcut)

"""Reference-style link. Build with `Node(ReferenceLink, children...; dest, label, title="", style=:full)`."""
function Node(
    ::Type{ReferenceLink},
    children...;
    dest::AbstractString,
    label::AbstractString,
    title::AbstractString = "",
    style::Symbol = :full,
)
    style in REFLINK_STYLES || error("style must be one of $REFLINK_STYLES")
    _build(ReferenceLink(dest, title, label, style), children)
end

"""Reference-style image. Build with `Node(ReferenceImage, children...; dest, label, title="", style=:full)`."""
function Node(
    ::Type{ReferenceImage},
    children...;
    dest::AbstractString,
    label::AbstractString,
    title::AbstractString = "",
    style::Symbol = :full,
)
    style in REFLINK_STYLES || error("style must be one of $REFLINK_STYLES")
    _build(ReferenceImage(dest, title, label, style), children)
end

"""Reference definition. Build with `Node(ReferenceDefinition; label, dest, title="")`."""
function Node(
    ::Type{ReferenceDefinition};
    label::AbstractString,
    dest::AbstractString,
    title::AbstractString = "",
)
    Node(ReferenceDefinition(label, dest, title))
end

"""Unresolved reference. Build with `Node(UnresolvedReference, children...; label, style=:shortcut, image=false)`."""
function Node(
    ::Type{UnresolvedReference},
    children...;
    label::AbstractString,
    style::Symbol = :shortcut,
    image::Bool = false,
)
    style in REFLINK_STYLES || error("style must be one of $REFLINK_STYLES")
    _build(UnresolvedReference(label, style, image), children)
end

# Inline rule - intercepts reference links before standard LinkRule

function parse_reference_close_bracket(parser::InlineParser, block::Node)
    @assert read(parser, Char) === ']'
    startpos = position(parser)

    opener = parser.brackets
    opener === nothing && (append_child(block, text("]")); return true)
    if !opener.active
        append_child(block, text("]"))
        remove_bracket!(parser)
        return true
    end

    is_image = opener.image
    savepos = position(parser)

    # If followed by '(', this is an inline link - let LinkRule handle it
    if trypeek(parser, Char, '\0') === '('
        seek(parser, startpos - 1)
        return false
    end

    # Try to match reference link
    beforelabel = position(parser)
    n = parse_link_label(parser)

    local style::Symbol
    local reflabel::String

    if n > 2
        # Full reference [text][label]
        reflabel = String(bytes(parser, beforelabel, beforelabel + n - 1))
        style = :full
    elseif n == 2
        # Collapsed reference [text][]
        reflabel = String(bytes(parser, opener.index, startpos - 1))
        style = :collapsed
    elseif !opener.bracket_after
        # Shortcut reference [text]
        reflabel = String(bytes(parser, opener.index, startpos - 1))
        style = :shortcut
        seek(parser, savepos)
    else
        # No reference match - let LinkRule handle it
        seek(parser, startpos - 1)
        return false
    end

    # Strip brackets from label for storage
    label = if startswith(reflabel, '[') && endswith(reflabel, ']')
        chop(reflabel; head = 1, tail = 1)
    else
        reflabel
    end

    # Lookup in refmap
    link = get(parser.refmap, normalize_reference(reflabel), nothing)
    if link === nothing
        if style === :shortcut
            # Shortcut style is unambiguous - capture as UnresolvedReference
            # Check if preceded by "]" - indicates this was originally full/collapsed
            # opener.node is the placeholder for "[", its prev sibling is what came before
            inferred_style = :shortcut
            effective_label = label
            inferred_image = is_image
            prev_node = opener.node.prv
            if !isnull(prev_node) && prev_node.t isa Text && prev_node.literal == "]"
                # This shortcut followed a ] - was originally full or collapsed
                if isempty(label)
                    # Empty label means collapsed style [text][]
                    inferred_style = :collapsed
                    # Extract the link text as the label
                    text_node = prev_node.prv
                    if !isnull(text_node) && text_node.t isa Text
                        effective_label = text_node.literal
                    end
                else
                    # Non-empty label means full style [text][label]
                    inferred_style = :full
                end
                # Check if original was an image by looking for "![" opener
                # Walk back: ] -> text -> [ or ![
                text_node = prev_node.prv
                if !isnull(text_node)
                    bracket_node = text_node.prv
                    if !isnull(bracket_node) && bracket_node.t isa Text
                        inferred_image = startswith(bracket_node.literal, "!")
                    end
                end
            end
            node =
                Node(UnresolvedReference(effective_label, inferred_style, inferred_image))
        else
            # Full/collapsed style: must backtrack to allow other parses
            # e.g. [foo][bar][baz] should parse as [foo] + link[bar][baz]
            seek(parser, startpos - 1)
            return false
        end
    else
        dest, title = link
        node = Node(
            is_image ?
            ReferenceImage(dest, title === nothing ? "" : title, label, style) :
            ReferenceLink(dest, title === nothing ? "" : title, label, style),
        )
    end

    # Move children from opener to new node
    tmp = opener.node.nxt
    while !isnull(tmp)
        nxt = tmp.nxt
        unlink(tmp)
        append_child(node, tmp)
        tmp = nxt
    end

    append_child(block, node)
    process_emphasis(parser, opener.previousDelimiter)
    remove_bracket!(parser)
    unlink(opener.node)

    # Deactivate earlier link openers (no links in links)
    if !is_image
        op = parser.brackets
        while op !== nothing
            if !op.image
                op.active = false
            end
            op = op.previous
        end
    end

    return true
end

inline_rule(::ReferenceLinkRule) = Rule(parse_reference_close_bracket, 0.5, "]")

# Block rule - captures reference definitions in place

block_rule(::ReferenceLinkRule) =
    Rule(0.5, "[") do parser, container
        parser.indented && return 0

        ln = rest_from_nonspace(parser)

        # Match [label]: pattern - label can contain anything except unescaped [ or ]
        m = match(r"^\[([^\[\]\\]|\\.){1,999}\]:", ln)
        m === nothing && return 0

        # Extract label (strip brackets and colon)
        label_with_brackets = m.match[1:end-1]  # remove trailing :
        label = chop(label_with_brackets; head = 1, tail = 1)  # remove [ and ]

        # Parse rest of line for destination and title
        rest = SubString(ln, length(m.match) + 1)

        # Skip leading whitespace
        rest_stripped = lstrip(rest)
        isempty(rest_stripped) && return 0  # no destination

        # Use InlineParser to parse destination and title
        inline_parser = parser.inline_parser
        inline_parser.buf = String(rest_stripped)
        seek(inline_parser, 1)

        dest = parse_link_destination(inline_parser)
        dest === nothing && return 0

        # Try to parse title
        title = ""
        chomp_ws(inline_parser)
        if position(inline_parser) > 1
            t = parse_link_title(inline_parser)
            t !== nothing && (title = t)
        end

        # Verify we consumed the meaningful content (allow trailing whitespace)
        remaining = SubString(inline_parser.buf, position(inline_parser))
        if !all(isspace, remaining)
            return 0  # extra content after definition
        end

        # Create the definition node
        close_unmatched_blocks(parser)
        add_child(parser, ReferenceDefinition(label, dest, title), parser.next_nonspace)

        # Add to refmap for inline link resolution (first definition wins)
        normlabel = normalize_reference(label)
        haskey(parser.refmap, normlabel) || (parser.refmap[normlabel] = (dest, title))

        # Consume the entire line
        advance_offset(parser, length(parser.buf) - parser.next_nonspace + 1, false)
        return 2  # leaf block
    end

#
# Writers
#

# Markdown - output reference style

function write_markdown(ref::ReferenceLink, w, node, ent)
    if ent
        literal(w, "[")
    else
        if ref.style === :full
            literal(w, "][", ref.label, "]")
        elseif ref.style === :collapsed
            literal(w, "][]")
        else  # :shortcut
            literal(w, "]")
        end
    end
end

function write_markdown(ref::ReferenceImage, w, node, ent)
    if ent
        literal(w, "![")
    else
        if ref.style === :full
            literal(w, "][", ref.label, "]")
        elseif ref.style === :collapsed
            literal(w, "][]")
        else
            literal(w, "]")
        end
    end
end

# HTML - same as regular Link/Image

function write_html(ref::ReferenceLink, r, n, ent)
    if ent
        attrs = []
        if !(r.format.safe && potentially_unsafe(ref.destination))
            push!(attrs, "href" => escape_xml(ref.destination))
        end
        if !isempty(ref.title)
            push!(attrs, "title" => escape_xml(ref.title))
        end
        tag(r, "a", attributes(r, n, attrs))
    else
        tag(r, "/a")
    end
end

function write_html(ref::ReferenceImage, r, n, ent)
    if ent
        if r.format.disable_tags == 0
            if r.format.safe && potentially_unsafe(ref.destination)
                literal(r, "<img src=\"\" alt=\"")
            else
                literal(r, "<img src=\"", escape_xml(ref.destination), "\" alt=\"")
            end
        end
        r.format.disable_tags += 1
    else
        r.format.disable_tags -= 1
        if r.format.disable_tags == 0
            if !isempty(ref.title)
                literal(r, "\" title=\"", escape_xml(ref.title))
            end
            literal(r, "\" />")
        end
    end
end

# LaTeX

function write_latex(ref::ReferenceLink, w, node, ent)
    if ent
        type, n = startswith(ref.destination, '#') ? ("hyperlink", 1) : ("href", 0)
        literal(w, "\\$type{$(chop(ref.destination; head=n, tail=0))}{")
    else
        literal(w, "}")
    end
end

function write_latex(ref::ReferenceImage, w, node, ent)
    if ent
        cr(w)
        literal(w, "\\begin{figure}\n")
        literal(w, "\\centering\n")
        literal(w, "\\includegraphics[max width=\\linewidth]{", ref.destination, "}\n")
        literal(w, "\\caption{")
    else
        literal(w, "}\n")
        literal(w, "\\end{figure}")
        cr(w)
    end
end

# Term

function write_term(ref::ReferenceLink, render, node, enter)
    style = crayon"blue underline"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

function write_term(ref::ReferenceImage, render, node, enter)
    style = crayon"green"
    if enter
        print_literal(render, style)
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, inv(style))
    end
end

# Typst

function write_typst(ref::ReferenceLink, w, node, ent)
    if ent
        literal(w, "#link(", repr(ref.destination), ")[")
    else
        literal(w, "]")
    end
end

function write_typst(ref::ReferenceImage, w, node, ent)
    if ent
        literal(w, "#figure(image(", repr(ref.destination), "), caption: [")
    else
        literal(w, "])")
    end
end

# Writers for ReferenceDefinition

function write_markdown(def::ReferenceDefinition, w, node, ent)
    print_margin(w)
    literal(w, "[", def.label, "]: ", def.destination)
    isempty(def.title) || literal(w, " \"", escape_markdown_title(def.title), "\"")
    cr(w)
    linebreak(w, node)
end

write_html(::ReferenceDefinition, r, n, ent) = nothing
write_latex(::ReferenceDefinition, w, n, ent) = nothing
write_term(::ReferenceDefinition, r, n, ent) = nothing
write_typst(::ReferenceDefinition, w, n, ent) = nothing

# Writers for UnresolvedReference - preserve original syntax
# For full/collapsed style, Text nodes before contain [text] or ![text], we just output [label] or []
# For shortcut style, we output [text] or ![text] directly

function write_markdown(ref::UnresolvedReference, w, node, ent)
    if ent
        # Only use image flag for shortcut style - for full/collapsed, ![ is in preceding Text
        use_image = ref.image && ref.style === :shortcut
        literal(w, use_image ? "![" : "[")
    else
        literal(w, "]")
    end
end

# HTML - output as text (no link)
function write_html(ref::UnresolvedReference, r, n, ent)
    if ent
        use_image = ref.image && ref.style === :shortcut
        literal(r, use_image ? "![" : "[")
    else
        literal(r, "]")
    end
end

# LaTeX - output as text
function write_latex(ref::UnresolvedReference, w, node, ent)
    if ent
        use_image = ref.image && ref.style === :shortcut
        literal(w, use_image ? "![" : "[")
    else
        literal(w, "]")
    end
end

# Term - output as warning style
function write_term(ref::UnresolvedReference, render, node, enter)
    style = crayon"red"
    if enter
        use_image = ref.image && ref.style === :shortcut
        print_literal(render, style, use_image ? "![" : "[")
        push_inline!(render, style)
    else
        pop_inline!(render)
        print_literal(render, "]", inv(style))
    end
end

# Typst - output as text
function write_typst(ref::UnresolvedReference, w, node, ent)
    if ent
        use_image = ref.image && ref.style === :shortcut
        literal(w, use_image ? "![" : "[")
    else
        literal(w, "]")
    end
end

# JSON - same as regular Link/Image

function write_json(ref::ReferenceLink, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        target = Any[ref.destination, ref.title]
        push_element!(ctx, json_el(ctx, "Link", Any[node_attr(node), inlines, target]))
    end
end

function write_json(ref::ReferenceImage, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        target = Any[ref.destination, ref.title]
        push_element!(ctx, json_el(ctx, "Image", Any[node_attr(node), inlines, target]))
    end
end

write_json(::ReferenceDefinition, ctx, node, enter) = nothing

function write_json(ref::UnresolvedReference, ctx, node, enter)
    if enter
        inlines = Any[]
        push_container!(ctx, inlines)
    else
        inlines = pop_container!(ctx)
        # Use distinct type name so tools can find unresolved references
        push_element!(
            ctx,
            json_el(
                ctx,
                "UnresolvedReference",
                Any[node_attr(node), inlines, Any[ref.label, string(ref.style), ref.image]],
            ),
        )
    end
end
