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

    # Lookup in refmap
    link = get(parser.refmap, normalize_reference(reflabel), nothing)
    if link === nothing
        seek(parser, startpos - 1)
        return false
    end

    dest, title = link

    # Strip brackets from label for storage
    label = if startswith(reflabel, '[') && endswith(reflabel, ']')
        chop(reflabel; head = 1, tail = 1)
    else
        reflabel
    end

    # Create ReferenceLink or ReferenceImage node
    node = Node(
        is_image ? ReferenceImage(dest, title === nothing ? "" : title, label, style) :
        ReferenceLink(dest, title === nothing ? "" : title, label, style),
    )

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
