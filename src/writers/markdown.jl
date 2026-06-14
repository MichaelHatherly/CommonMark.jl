# Public.

function Base.show(
        io::IO,
        ::MIME"text/markdown",
        ast::Node,
        env = Dict{String, Any}();
        transform = default_transform,
    )
    w = Writer(Markdown(io), io, env; transform = transform)
    write_markdown(w, ast)
    return nothing
end
"""
    markdown(ast::Node) -> String
    markdown(filename::String, ast::Node)
    markdown(io::IO, ast::Node)

Render a CommonMark AST back to Markdown text.

Useful for normalizing Markdown formatting or for roundtrip testing.
Output uses opinionated formatting. Hard breaks use two trailing spaces.

# Examples

```julia
p = Parser()
ast = p("# Hello\\n\\nWorld")
markdown(ast)  # "# Hello\\n\\nWorld\\n"
```
"""
markdown(args...; kws...) = writer(MIME"text/markdown"(), args...; kws...)

# Internals.

mime_to_str(::MIME"text/markdown") = "markdown"

mutable struct Markdown{I <: IO}
    buffer::I
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    in_autolink::Bool
    # O(1) state read by inline nodes instead of re-walking/re-scanning the tree:
    current_heading::Union{Nothing, Symbol}  # :setext / :atx while inside a heading
    link_image_depth::Int                    # > 0 while inside link/image text
    has_ref_defs::Bool                       # document emits `[label]: url` definitions
    Markdown(io::I) where {I} = new{I}(io, 0, [], 0, [], false, nothing, 0, false)
end

# NOTE: single-pair `replace` chained for Julia 1.3 compatibility (multi-pair
# `replace` requires Julia 1.7+). Backslashes are escaped first so the
# backslashes introduced by later steps are not doubled.
escape_markdown_title(s::AbstractString) =
    replace(replace(s, "\\" => "\\\\"), "\"" => "\\\"")

# Link/image destinations that would not survive a re-parse in bare form are
# wrapped in pointy brackets. Bare destinations may not contain whitespace,
# control characters, or unbalanced/escaped parentheses.
function escape_markdown_destination(dest::AbstractString)
    balance = 0
    balanced = true
    for c in dest
        if c == '('
            balance += 1
        elseif c == ')'
            balance -= 1
            balance < 0 && (balanced = false)
        end
    end
    balanced &= balance == 0
    needs_brackets =
        !balanced || any(c -> isspace(c) || iscntrl(c) || c in ('<', '>', '\\'), dest)
    needs_brackets || return dest
    # Chained single-pair `replace` for Julia 1.3 compatibility (see note above);
    # backslashes first so later-introduced backslashes are not doubled.
    escaped = replace(replace(replace(dest, "\\" => "\\\\"), "<" => "\\<"), ">" => "\\>")
    return string('<', escaped, '>')
end

# Characters that could possibly need escaping in text; the fast path returns the
# literal untouched when it contains none of them.
const MARKDOWN_SPECIAL = ('\\', '`', '*', '_', '[', ']', '<', '&', '\n')

# Entity-reference pattern: a raw `&` followed by this would be re-parsed as
# an entity, so it needs escaping.
const MARKDOWN_ENTITY_LOOKAHEAD =
    r"^&(?:[a-zA-Z][a-zA-Z0-9]{1,31}|#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6});"

# `*`/`_` only need escaping when they could act as an emphasis delimiter in the
# output, i.e. when the (output-adjacent) neighbours make them flanking. These
# are the exact CommonMark flanking rules (see `scan_delims`); an unknown right
# neighbour is treated as escape-worthy.
function _md_flank_escape(delim::Char, left::Char, right::Union{Char, Nothing})
    right === nothing && return true
    r = right::Char
    ws_after = Base.Unicode.isspace(r)
    punct_after = is_unicode_punct(r)
    ws_before = Base.Unicode.isspace(left)
    punct_before = is_unicode_punct(left)
    left_flanking = !ws_after && (!punct_after || ws_before || punct_before)
    right_flanking = !ws_before && (!punct_before || ws_after || punct_after)
    if delim == '_'
        can_open = left_flanking && (!right_flanking || punct_before)
        can_close = right_flanking && (!left_flanking || punct_after)
        return can_open || can_close
    end
    return left_flanking || right_flanking
end

# `<` only starts an autolink or HTML tag when an ASCII letter, `/`, `!`, or `?`
# follows; otherwise it is literal.
function _md_lt_escape(right::Union{Char, Nothing})
    right === nothing && return true
    r = right::Char
    return ('A' <= r <= 'Z') || ('a' <= r <= 'z') || r === '/' || r === '!' || r === '?'
end

# Cheap pre-check before the (anchored) entity regex: a bare `&` can only begin
# an entity when a letter or `#` follows.
function _md_entity_ahead(literal::AbstractString, k::Integer, ncu::Integer)
    nk = nextind(literal, k)
    nk <= ncu || return false
    c = literal[nk]
    (('a' <= c <= 'z') || ('A' <= c <= 'Z') || c === '#') || return false
    return occursin(MARKDOWN_ENTITY_LOOKAHEAD, SubString(literal, k))
end

# The first character a node emits, used to decide a preceding text node's
# trailing escapes. Returns `nothing` when unknown (caller then escapes).
function _md_leading_char(node::Node)
    t = node.t
    if t isa Text
        return isempty(node.literal) ? nothing : node.literal[firstindex(node.literal)]
    elseif t isa Emph || t isa Strong
        return isempty(node.literal) ? nothing : node.literal[firstindex(node.literal)]
    elseif t isa Code
        return '`'
    elseif t isa HtmlInline
        return t.raw ? '`' :
            (isempty(node.literal) ? nothing : node.literal[firstindex(node.literal)])
    elseif t isa Image || t isa ReferenceImage
        return '!'
    elseif t isa Link || t isa ReferenceLink || t isa UnresolvedReference
        return '['
    elseif t isa SoftBreak || t isa LineBreak
        return ' '
    elseif t isa Backslash
        return '\\'
    else
        return nothing
    end
end

# The character emitted immediately after `node` finishes, i.e. the right
# neighbour of its last character.
function _md_following_char(node::Node)
    isnull(node.nxt) || return _md_leading_char(node.nxt)
    p = node.parent
    isnull(p) && return nothing
    t = p.t
    if t isa Emph || t isa Strong
        return isempty(p.literal) ? nothing : p.literal[firstindex(p.literal)]
    elseif t isa Link || t isa Image || t isa ReferenceLink ||
            t isa ReferenceImage || t isa UnresolvedReference
        return ']'
    elseif t isa Paragraph || t isa Heading || t isa Item || t isa BlockQuote
        return '\n'
    else
        return nothing
    end
end

# Decide, in one left-to-right pass, which `[` byte positions of `literal` need
# escaping. A `[` only opens a link/ref when a matching `]` closes it; we escape
# when that pairing could re-resolve: inside link/image text, when an inline
# `(`/full-reference `[` follows the closer, or when the document has reference
# definitions (a shortcut could resolve). A `[` whose closer is not in this node
# is escaped conservatively (the closer may follow in a sibling). Returns
# `nothing` when no `[` needs escaping.
function _md_bracket_escapes(
        literal::AbstractString,
        following::Union{Char, Nothing},
        has_ref_defs::Bool,
        in_link_image::Bool,
    )
    escapes = nothing
    stack = Int[]
    ncu = ncodeunits(literal)
    k = firstindex(literal)
    while k <= ncu
        c = literal[k]
        if c === '['
            push!(stack, k)
        elseif c === ']' && !isempty(stack)
            openk = pop!(stack)
            nk = nextind(literal, k)
            after = nk <= ncu ? literal[nk] : following
            if in_link_image || after === '(' || after === '[' || has_ref_defs
                escapes === nothing && (escapes = Set{Int}())
                push!(escapes, openk)
            end
        end
        k = nextind(literal, k)
    end
    if !isempty(stack)
        escapes === nothing && (escapes = Set{Int}())
        union!(escapes, stack)
    end
    return escapes
end

# Characters that can begin a block construct at the start of a line.
_md_block_starter(c::AbstractChar) =
    c === '#' || c === '>' || c === '=' || c === '-' || c === '+' ||
    c === '*' || c === '_' || c === '\t' || ('0' <= c <= '9')

# Escape a Text node's literal so that it re-parses as the same plain text,
# escaping only the characters that would otherwise be (mis)read as syntax in the
# output context. When the node begins a line, characters that would start a
# block construct there (ATX headings, list markers, blockquotes, setext
# underlines, thematic breaks, an indenting tab) are also escaped.
#
# The output buffer is allocated lazily: the literal is returned unchanged when
# nothing actually needs escaping, and the bracket pre-pass runs only when a `[`
# is present, so the common case allocates nothing.
function escape_markdown_text(w, node::Node)
    literal = node.literal
    isempty(literal) && return literal
    skip_first = !isnull(node.prv) && node.prv.t isa Backslash
    c1 = literal[firstindex(literal)]
    line_block = _md_at_line_start(node) && _md_block_starter(c1)
    # One scan: is there any inline special, and is there a `[` (needs the pre-pass)?
    has_special = false
    has_bracket = false
    for c in literal
        if c in MARKDOWN_SPECIAL
            has_special = true
            if c === '['
                has_bracket = true
                break
            end
        end
    end
    # Fast path: nothing to escape inline and no block construct at a line start.
    if !skip_first && !line_block && !has_special
        return literal
    end

    following = _md_following_char(node)
    in_link_image = w.format.link_image_depth > 0
    brk = has_bracket ?
        _md_bracket_escapes(literal, following, w.format.has_ref_defs, in_link_image) :
        nothing

    ncu = ncodeunits(literal)
    out = nothing                 # ::Union{Nothing, IOBuffer}, created on first escape
    copied = firstindex(literal)  # first byte not yet flushed into `out`
    prev = w.last                 # output-adjacent left neighbour
    i = firstindex(literal)

    # First-character handling for line-start block markers / backslash prefix.
    if skip_first
        # The preceding Backslash node already escapes the first character; keep it.
        prev = c1
        i = nextind(literal, i)
    elseif line_block
        rep = nothing
        if c1 == '\t'
            rep = "&#9;"
        elseif c1 == '#' && occursin(r"^#{1,6}(?:[ \t]|$)", literal)
            rep = "\\#"
        elseif c1 == '>'
            rep = "\\>"
        elseif c1 == '=' && occursin(r"^=+[ \t]*$", literal)
            rep = "\\="
        elseif (c1 == '-' || c1 == '+') && (
                occursin(r"^[-+](?:[ \t]|$)", literal) ||
                    (
                    c1 == '-' && (
                        occursin(r"^-+[ \t]*$", literal) ||
                            occursin(r"^(?:-[ \t]*){3,}$", literal)
                    )
                )
            )
            rep = c1 == '-' ? "\\-" : "\\+"
        elseif c1 == '*' && (
                occursin(r"^\*(?:[ \t]|$)", literal) ||
                    occursin(r"^(?:\*[ \t]*){3,}$", literal)
            )
            rep = "\\*"
        elseif c1 == '_' && occursin(r"^(?:_[ \t]*){3,}$", literal)
            rep = "\\_"
        end
        if rep !== nothing
            out = IOBuffer()
            write(out, rep)
            prev = last(rep)
            i = nextind(literal, i)
            copied = i
        elseif '0' <= c1 <= '9'
            m = match(r"^[0-9]{1,9}(?=[.)](?:[ \t]|$))", literal)
            if m !== nothing
                out = IOBuffer()
                write(out, m.match)
                write(out, '\\')
                prev = '\\'
                i = nextind(literal, i, ncodeunits(m.match))
                copied = i
            end
        end
    end

    k = i
    while k <= ncu
        c = literal[k]
        nk = nextind(literal, k)
        esc = false      # backslash-escape this char?
        newline = false  # rewrite a literal newline as an entity?
        if c == '\\' || c == '`'
            esc = true
        elseif c == '['
            esc = brk !== nothing && k in brk
        elseif c == ']'
            esc = in_link_image
        elseif c == '*'
            esc = _md_flank_escape('*', prev, nk <= ncu ? literal[nk] : following)
        elseif c == '_'
            esc = _md_flank_escape('_', prev, nk <= ncu ? literal[nk] : following)
        elseif c == '<'
            esc = _md_lt_escape(nk <= ncu ? literal[nk] : following)
        elseif c == '\n'
            newline = true
        elseif c == '&'
            esc = _md_entity_ahead(literal, k, ncu)
        end
        if esc || newline
            out === nothing && (out = IOBuffer())
            copied < k && write(out, SubString(literal, copied, prevind(literal, k)))
            if newline
                # Literal newlines (e.g. from `&#10;`) would split the paragraph.
                write(out, "&#10;")
                prev = ';'
            else
                write(out, '\\')
                write(out, c)
                prev = c
            end
            copied = nk
        else
            prev = c
        end
        k = nk
    end

    out === nothing && return literal
    copied <= ncu && write(out, SubString(literal, copied, lastindex(literal)))
    return String(take!(out))
end

# A text node begins a line when it opens a paragraph or directly follows a
# line break, in which case block-level constructs could trigger there.
function _md_at_line_start(node::Node)
    if isnull(node.prv)
        return node.parent.t isa Paragraph
    end
    return node.prv.t isa SoftBreak || node.prv.t isa LineBreak
end

# Print margin with trailing whitespace stripped (for blank lines)
function print_margin_rstrip(w)
    margin = sprint() do io
        for seg in w.format.margin
            if seg.count == 0
                print(io, ' '^seg.width)
            else
                print(io, seg.text)
            end
        end
    end
    return literal(w, rstrip(margin))
end

# A shortcut `[label]` can only re-resolve to a link if the document emits a
# reference definition, so detect that once up front for the `[` escaping logic.
_md_has_ref_defs(ast::Node) = any(p -> p[2] && p[1].t isa ReferenceDefinition, ast)

function write_markdown(writer::Writer, ast::Node)
    writer.format.has_ref_defs = _md_has_ref_defs(ast)
    mime = MIME"text/markdown"()
    for (node, entering) in ast
        node, entering = _transform(writer.transform, mime, node, entering, writer)
        write_markdown(node.t, writer, node, entering)
    end
    return
end

function linebreak(w, node)
    if !isnull(node.nxt)
        # Skip in tight lists - Item writer handles loose list spacing
        if node.parent.t isa Item && node.parent.parent.t.list_data.tight
            return nothing
        end
        print_margin_rstrip(w)
        literal(w, "\n")
    end
    return nothing
end

# Writers.

write_markdown(::Document, w, node, ent) = nothing

function write_markdown(::Text, w, node, ent)
    w.format.in_autolink && return literal(w, node.literal)
    return literal(w, escape_markdown_text(w, node))
end

write_markdown(::Backslash, w, node, ent) = literal(w, "\\")

# Setext form is the only way to represent a heading that contains soft
# breaks, but it is limited to levels 1 and 2.
function _md_is_setext(node::Node)
    node.t.level <= 2 || return false
    for (n, enter) in node
        enter && n.t isa SoftBreak && return true
    end
    return false
end

function write_markdown(::SoftBreak, w, node, ent)
    # Setext headings keep their line breaks; an ATX heading is a single line, so
    # breaks anywhere inside it (also nested in emphasis etc.) collapse to a
    # space. `current_heading` is set once on the enclosing heading's enter.
    w.format.current_heading === :atx && return literal(w, " ")
    cr(w)
    return print_margin(w)
end

function write_markdown(::LineBreak, w, node, ent)
    # Backslash hard breaks already have the `\` from the Backslash node
    if isnull(node.prv) || !(node.prv.t isa Backslash)
        literal(w, "  ")
    end
    cr(w)
    return print_margin(w)
end

# Emit `content` wrapped in a backtick span, with a trailing `suffix` after the
# closing delimiter. The delimiter is the next odd count longer than the longest
# backtick run in `content` (even counts collide with math syntax), and content
# that starts or ends with a backtick is space-padded so it can't merge with the
# delimiter.
function backtick_span(w, content, suffix = "")
    num = foldl(eachmatch(r"`+", content); init = 0) do a, b
        max(a, length(b.match))
    end
    backticks = num + (isodd(num) ? 2 : 1)
    # Content that starts and ends with a space also needs padding: the parser
    # strips one leading and trailing space from a space-padded span.
    pad = !isempty(content) && (
        startswith(content, '`') || endswith(content, '`') ||
            (startswith(content, ' ') && endswith(content, ' ') && !all(==(' '), content))
    )
    literal(w, "`"^backticks)
    pad && literal(w, " ")
    literal(w, content)
    pad && literal(w, " ")
    return literal(w, "`"^backticks, suffix)
end

write_markdown(::Code, w, node, ent) = backtick_span(w, node.literal)

function write_markdown(t::HtmlInline, w, node, ent)
    return t.raw ? backtick_span(w, node.literal, "{=html}") : literal(w, node.literal)
end

# A link can be written in `<autolink>` form when its only content is a text
# node matching the autolink syntax whose normalised form is the destination.
function _md_is_autolink(link::Link, node::Node)
    isempty(link.title) || return false
    child = node.first_child
    (isnull(child) || !isnull(child.nxt) || !(child.t isa Text)) && return false
    wrapped = string('<', child.literal, '>')
    m = match(reAutolink, wrapped)
    if m !== nothing && m.match == wrapped
        return normalize_uri(child.literal) == link.destination
    end
    m = match(reEmailAutolink, wrapped)
    return m !== nothing && m.match == wrapped &&
        normalize_uri("mailto:$(child.literal)") == link.destination
end

function write_markdown(link::Link, w, node, ent)
    if ent
        w.format.link_image_depth += 1
        if _md_is_autolink(link, node)
            w.format.in_autolink = true
            literal(w, "<")
        else
            literal(w, "[")
        end
    else
        if w.format.in_autolink
            w.format.in_autolink = false
            literal(w, ">")
        else
            literal(w, "](", escape_markdown_destination(link.destination))
            isempty(link.title) ||
                literal(w, " \"", escape_markdown_title(link.title), "\"")
            literal(w, ")")
        end
        w.format.link_image_depth -= 1
    end
    return nothing
end

function write_markdown(image::Image, w, node, ent)
    if ent
        w.format.link_image_depth += 1
        literal(w, "![")
    else
        literal(w, "](", escape_markdown_destination(image.destination))
        isempty(image.title) || literal(w, " \"", escape_markdown_title(image.title), "\"")
        literal(w, ")")
        w.format.link_image_depth -= 1
    end
    return nothing
end

write_markdown(::Emph, w, node, ent) = literal(w, node.literal)

write_markdown(::Strong, w, node, ent) = literal(w, node.literal)

function write_markdown(::Paragraph, w, node, ent)
    return if ent
        print_margin(w)
    else
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(heading::Heading, w, node, ent)
    return if ent
        # Compute setext-ness once here; soft breaks and the exit branch read it.
        w.format.current_heading = _md_is_setext(node) ? :setext : :atx
        print_margin(w)
        w.format.current_heading === :atx && literal(w, "#"^heading.level, " ")
    else
        if w.format.current_heading === :setext
            cr(w)
            print_margin(w)
            literal(w, (heading.level == 1 ? '=' : '-')^3)
        end
        w.format.current_heading = nothing
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(::BlockQuote, w, node, ent)
    return if ent
        push_margin!(w, ">")
        push_margin!(w, " ")
    else
        pop_margin!(w)
        maybe_print_margin(w, node)
        pop_margin!(w)
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(list::List, w, node, ent)
    return if ent
        w.format.list_depth += 1
        push!(w.format.list_item_number, list.list_data.start)
    else
        w.format.list_depth -= 1
        pop!(w.format.list_item_number)
        cr(w)
        linebreak(w, node)
    end
end

function write_markdown(item::Item, w, node, enter)
    return if enter
        if item.list_data.type === :ordered
            # Preserve the parsed delimiter: `1.` and `1)` lists are distinct,
            # so rewriting one as the other merges adjacent sibling lists.
            delimiter = item.list_data.delimiter in (".", ")") ? item.list_data.delimiter : "."
            number = lpad(string(w.format.list_item_number[end], delimiter, " "), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number)
        else
            # Preserve the parsed bullet for the same reason: adjacent sibling
            # lists are only kept apart by their differing markers.
            bullet = item.list_data.bullet_char in ('-', '+', '*') ?
                item.list_data.bullet_char : '-'
            push_margin!(w, 1, lpad("$bullet ", 4, " "))
        end
    else
        if isnull(node.first_child)
            print_margin_rstrip(w)
            cr(w)
        end
        pop_margin!(w)
        if !node.parent.t.list_data.tight
            cr(w)
            linebreak(w, node)
        end
    end
end

function write_markdown(::ThematicBreak, w, node, ent)
    print_margin(w)
    literal(w, "* * *")
    cr(w)
    return linebreak(w, node)
end

function write_markdown(code::CodeBlock, w, node, ent)
    # An indented code block directly after a list would be re-parsed as part
    # of the final list item, so it has to be written fenced instead.
    must_fence = !isnull(node.prv) && node.prv.t isa List
    if code.is_fenced || must_fence
        fence = if code.is_fenced
            code.fence_char^code.fence_length
        else
            num = foldl(eachmatch(r"`+", node.literal); init = 2) do a, b
                max(a, length(b.match))
            end
            "`"^(num + 1)
        end
        print_margin(w)
        literal(w, fence, code.info)
        cr(w)
        for line in eachline(IOBuffer(node.literal); keep = true)
            print_margin(w)
            literal(w, line)
        end
        print_margin(w)
        literal(w, fence)
        cr(w)
    else
        for line in eachline(IOBuffer(node.literal); keep = true)
            print_margin(w)
            # Whitespace-only lines keep their indent too: it is part of the
            # block's content and would otherwise be stripped on re-parse.
            indent = line in ("", "\n") ? 0 : CODE_INDENT
            literal(w, ' '^indent, line)
        end
    end
    return linebreak(w, node)
end

function write_markdown(t::HtmlBlock, w, node, ent)
    if t.raw
        print_margin(w)
        literal(w, "```{=html}\n")
        for line in eachline(IOBuffer(node.literal))
            print_margin(w)
            literal(w, line, "\n")
        end
        print_margin(w)
        literal(w, "```\n")
    else
        for line in eachline(IOBuffer(node.literal); keep = true)
            print_margin(w)
            literal(w, line)
        end
        cr(w)
    end
    return linebreak(w, node)
end
