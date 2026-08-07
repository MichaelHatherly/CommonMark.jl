# Public.

function Base.show(
        io::IO,
        ::MIME"text/markdown",
        ast::Node,
        env = Dict{String, Any}();
        transform = default_transform,
    )
    format = Markdown(io)
    w = Writer(format, format.buffer, env; transform = transform)
    write_markdown(w, ast)
    write(format.target, escape_markdown(format))
    return nothing
end
"""
    markdown(ast::Node) -> String
    markdown(filename::String, ast::Node)
    markdown(io::IO, ast::Node)

Render a CommonMark AST back to Markdown text.

Useful for normalizing Markdown formatting or for roundtrip testing.
Output uses opinionated formatting. Hard breaks use two trailing spaces.

The output is written to be read back as the document it came from: text that
would otherwise be taken for markup is escaped, and constructs with more than one
spelling take the one that survives. The test suite checks that every example in
the CommonMark spec survives a render and a reparse. Escaping assumes the default
rule set, so a document written for a parser with rules disabled may carry escapes
that parser does not need.

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

"""
The character each claimed spelling opens with, held as a bitmask over the ASCII
range. Every character of the document is tested against it, so the common
answer of "no spelling starts here" costs a shift and a mask rather than a scan
of the spellings. A rule is free to claim a spelling opening with a character
outside that range, which falls back to the scan.
"""
struct ClaimFirsts
    ascii::UInt128
    wide::Vector{Char}
end

function ClaimFirsts(claimed::Vector{String})
    ascii = UInt128(0)
    wide = Char[]
    for claim in claimed
        c = first(claim)
        if isascii(c)
            ascii |= UInt128(1) << UInt32(c)
        elseif c ∉ wide
            push!(wide, c)
        end
    end
    return ClaimFirsts(ascii, wide)
end

opens_claim(firsts::ClaimFirsts, c::AbstractChar) =
    isascii(c) ? !iszero(firsts.ascii & (UInt128(1) << UInt32(c))) : c in firsts.wide

"""
The document as it is written, escaped on the way past.

Whether a character of text has to be escaped depends on the characters either
side of it. The one before has been written already. The one after may be markup
the writer has yet to choose, so a character is held until enough of what
follows it has arrived, and only then written. `lookahead` is how far that
reaches: one character to see a neighbour, more where a rule claims a spelling
longer than that.

Only text is ever held. Markup is read back as written, so nothing about it
waits on what follows, and it goes out a run at a time.
"""
mutable struct EscapeSink{I <: IO} <: IO
    out::I
    claimed::Vector{String}
    firsts::ClaimFirsts
    # Claimed where a line's content starts, and read only there.
    claimed_line::Vector{String}
    firsts_line::ClaimFirsts
    lookahead::Int
    held::Vector{Char}
    held_escapable::Vector{Bool}
    held_opens_line::Vector{Bool}
    # Set by the margin, and read by whatever is written next.
    margin_pending::Bool
    prev::Char
    begin_content::Bool
    follows_digit::Bool
end

EscapeSink(out::I) where {I <: IO} = EscapeSink{I}(
    out, String[], ClaimFirsts(String[]), String[], ClaimFirsts(String[]), 1,
    Char[], Bool[], Bool[], false, '\0', false, false,
)

mutable struct Markdown{I <: IO}
    target::I
    buffer::EscapeSink{IOBuffer}
    indent::Int
    margin::Vector{MarginSegment}
    list_depth::Int
    list_item_number::Vector{Int}
    list_marker_offset::Vector{Int}
    verbatim::Int
    Markdown(io::I) where {I} =
        new{I}(io, EscapeSink(IOBuffer()), 0, [], 0, [], [], 0)
end

"""
Name the syntax the document's rules claim, which decides both what the writer
escapes and how far it has to see past a character to know.
"""
function claim!(format::Markdown, claimed::Vector{String}, claimed_line::Vector{String})
    sink = format.buffer
    sink.claimed = claimed
    sink.firsts = ClaimFirsts(claimed)
    sink.claimed_line = claimed_line
    sink.firsts_line = ClaimFirsts(claimed_line)
    # A spelling is recognised from the character that opens it, so seeing the
    # rest of it means seeing one fewer than its length past that character.
    longest = 0
    for spellings in (claimed, claimed_line), spelling in spellings
        longest = max(longest, length(spelling))
    end
    sink.lookahead = max(1, longest - 1)
    return nothing
end

"""
Render part of a document on its own, such as a table cell measured for the
width of its column, or a notebook cell. Escaping depends on the syntax the
document's rules claim, which the fragment reaches through the tree that holds
it. A fragment built by hand, with no document over it, claims nothing.
"""
function markdown_fragment(node::Node, env = Dict{String, Any}())
    format = Markdown(devnull)
    root = document(node)
    claim!(format, claimed_syntax(root), claimed_line_syntax(root))
    w = Writer(format, format.buffer, env)
    write_markdown(w, node)
    return escape_markdown(format)
end

# The line's content starts at whatever is written next, which is the only place
# the line-start rules apply.
margin_written!(format::Markdown) = (format.buffer.margin_pending = true; nothing)

# `\0` stands in for the end of the document, where a line ends as well.
line_end(c::AbstractChar) = c === '\0' || c === '\n'

# Constructs that would be re-read as block markup when they start a line. An
# indented code block is covered by escaping leading whitespace, and a backtick
# fence by escaping every backtick, so the tilde fence is the only fence here.
#
# `follows_digit` marks the characters after a line's leading digits, which an
# ordered list marker follows. Nothing else opens a block there, since every
# other spelling has to be the first thing on the line.
function starts_block(c::AbstractChar, nextc::AbstractChar, follows_digit::Bool)
    # A marker needs its trailing space to open a list or heading, and a run of
    # its own character to underline, break, or fence.
    marker = nextc === ' ' || nextc === '\t' || line_end(nextc)
    follows_digit && return (c === '.' || c === ')') && marker
    (c === ' ' || c === '\t') && return true
    c === '>' && return true
    c === '#' && return marker || nextc === '#'
    (c === '-' || c === '*' || c === '+' || c === '_') && return marker || nextc === c
    c === '=' && return nextc === '=' || line_end(nextc)
    c === '~' && return nextc === '~'
    return false
end

# A delimiter run surrounded by whitespace can neither open nor close emphasis,
# so it survives a reparse as literal text.
inert_delimiter(prev::AbstractChar, nextc::AbstractChar) = isedge(prev) && isedge(nextc)
isedge(c::AbstractChar) = c === '\0' || isspace(c)

# Text is written verbatim wherever it cannot be mistaken for markup, so escapes
# stay rare enough to keep the output readable. `\0` for `prev` or `nextc` means
# the text ends there.
function needs_escape(
        c::AbstractChar,
        prev::AbstractChar,
        nextc::AbstractChar,
        begin_content::Bool,
        follows_digit::Bool,
    )
    # A tab is markup only where it indents a line or ends one, and both of
    # those are handled below. No other control character has a literal
    # spelling.
    c < ' ' && c !== '\t' && return true
    (c === '`' || c === '\\') && return true
    begin_content && starts_block(c, nextc, follows_digit) && return true
    # Whitespace before the end of a line is stripped, and two spaces there make
    # a hard break instead.
    (c === ' ' || c === '\t') && line_end(nextc) && return true
    c === '*' && return !inert_delimiter(prev, nextc)
    # Underscores between alphanumerics never delimit emphasis either.
    c === '_' && return !(inert_delimiter(prev, nextc) || (isalnumeric(prev) && isalnumeric(nextc)))
    # Brackets are escaped in pairs or not at all: escaping only the closing one
    # would leave the opening one free to pair with a later bracket instead.
    (c === '[' || c === ']') && return true
    c === '<' && return isalnumeric(nextc) || nextc === '/' || nextc === '?' || nextc === '!'
    c === '!' && return nextc === '['
    c === '&' && return isalnumeric(nextc) || nextc === '#'
    return false
end

isalnumeric(c::AbstractChar) = isletter(c) || isdigit(c)


# Only ASCII punctuation can carry a backslash escape, so anything else that
# needs hiding is written as a numeric character reference.
is_ascii_punct(c::AbstractChar) = isascii(c) && is_unicode_punct(c)

function escape_char(io::IO, c::AbstractChar)
    return if is_ascii_punct(c)
        print(io, '\\', c)
    else
        print(io, "&#", UInt32(c), ';')
    end
end

"""
Write a node's text content, as against the markup [`literal`](@ref) writes.
Escaping waits until the whole document is written, when every character's
neighbours are known, so the range holding this text is recorded rather than
escaped here.

`escaped_first` marks text whose leading character is already escaped by a
preceding `Backslash` node, which the parser keeps in the AST. A
verbatim range, such as the label of a reference link, is never escaped.
"""
function content(w, str::AbstractString, escaped_first::Bool = false)
    isempty(str) && return nothing
    w.enabled || return nothing
    if w.format.verbatim != 0
        return literal(w, str)
    end
    sink = w.format.buffer
    if escaped_first
        # The backslash before it is already written, so the first character
        # stands as it is spelled.
        head = str[firstindex(str)]
        write_markup!(sink, string(head))
        rest = SubString(str, nextind(str, firstindex(str)))
        isempty(rest) || write_escapable!(sink, rest)
    else
        write_escapable!(sink, str)
    end
    # `literal` keeps this for the writer that asks whether a line already ended,
    # and text written straight to the sink has to answer the same way.
    w.last = str[lastindex(str)]
    return nothing
end

"""
Open a verbatim range: text that has to reparse exactly as written, such as the
label of a reference link, and so carries no escapes. Ranges nest, and
[`pop_verbatim!`](@ref) closes the innermost.
"""
push_verbatim!(w) = (w.format.verbatim += 1; nothing)

"""
Close the verbatim range [`push_verbatim!`](@ref) opened.
"""
pop_verbatim!(w) = (w.format.verbatim -= 1; nothing)

# The character `k` past the front of what is held, reading on into `rest` once
# the held characters run out. `\0` means nothing follows.
function ahead(sink::EscapeSink, k::Int, rest::AbstractString, ri::Int)
    held = sink.held
    k <= length(held) && return @inbounds held[k]
    k -= length(held)
    i = ri
    stop = ncodeunits(rest)
    while k > 1 && i <= stop
        i = nextind(rest, i)
        k -= 1
    end
    return (k > 1 || i > stop) ? '\0' : rest[i]
end

# Whether a claimed spelling starts at the front of what is held. The spelling
# may run past the held characters into what follows them.
function held_starts_claim(
        sink::EscapeSink, claimed::Vector{String}, firsts::ClaimFirsts,
        rest::AbstractString, ri::Int,
    )
    opens_claim(firsts, @inbounds sink.held[1]) || return false
    for claim in claimed
        k = 1
        matched = true
        for wanted in claim
            if ahead(sink, k, rest, ri) !== wanted
                matched = false
                break
            end
            k += 1
        end
        matched && return true
    end
    return false
end

# A spelling claimed where this character stands: anywhere for the claims of an
# inline rule, and only where a line's content starts for those of a block rule.
function held_claimed(sink::EscapeSink, rest::AbstractString, ri::Int)
    if !isempty(sink.claimed) &&
            held_starts_claim(sink, sink.claimed, sink.firsts, rest, ri)
        return true
    end
    sink.begin_content && !isempty(sink.claimed_line) || return false
    return held_starts_claim(sink, sink.claimed_line, sink.firsts_line, rest, ri)
end

# What a character written leaves behind it for the next one.
@inline function carry!(sink::EscapeSink, c::AbstractChar)
    sink.begin_content = sink.begin_content && isdigit(c)
    sink.follows_digit = isdigit(c)
    sink.prev = c
    return nothing
end

"""
Write out what is held, as far as `rest` lets it be decided.

A character of text is only settled once `lookahead` characters stand behind it,
counting the rest of what is held and the `n_rest` characters coming after. Text
short enough to leave that unmet stays held, waiting on whatever is written
next. Markup settles as it arrives, since nothing about it turns on what
follows.
"""
function resolve_held!(
        sink::EscapeSink, rest::AbstractString, ri::Int, n_rest::Int,
        force::Bool = false,
    )
    while !isempty(sink.held)
        escapable = @inbounds sink.held_escapable[1]
        !force && escapable && length(sink.held) - 1 + n_rest < sink.lookahead && break
        c = @inbounds sink.held[1]
        (@inbounds sink.held_opens_line[1]) && (sink.begin_content = true)
        if escapable && (
                needs_escape(
                    c, sink.prev, ahead(sink, 2, rest, ri),
                    sink.begin_content, sink.follows_digit,
                ) || held_claimed(sink, rest, ri)
            )
            escape_char(sink.out, c)
        else
            write(sink.out, c)
        end
        carry!(sink, c)
        popfirst!(sink.held)
        popfirst!(sink.held_escapable)
        popfirst!(sink.held_opens_line)
    end
    return nothing
end

# Take a run in whole, for text too short to settle anything on its own.
function hold_run!(sink::EscapeSink, s::AbstractString, escapable::Bool)
    for c in s
        push!(sink.held, c)
        push!(sink.held_escapable, escapable)
        push!(sink.held_opens_line, sink.margin_pending)
        sink.margin_pending = false
    end
    return nothing
end

# Markup is read back as written, so it waits on nothing and goes out whole. The
# line-start rules still read through it, since a list marker is written as
# markup.
function write_markup!(sink::EscapeSink, s::AbstractString)
    isempty(s) && return nothing
    if !isempty(sink.held)
        resolve_held!(sink, s, firstindex(s), length(s))
        # What is still held is text the writer has not put enough behind yet,
        # and this markup has to keep its place after it.
        if !isempty(sink.held)
            hold_run!(sink, s, false)
            return resolve_held!(sink, "", 1, 0)
        end
    end
    if sink.margin_pending
        sink.begin_content = true
        sink.margin_pending = false
    end
    print(sink.out, s)
    last_c = s[lastindex(s)]
    sink.begin_content = sink.begin_content && all(isdigit, s)
    sink.follows_digit = isdigit(last_c)
    sink.prev = last_c
    return nothing
end

Base.write(sink::EscapeSink, s::String) = (write_markup!(sink, s); ncodeunits(s))
Base.write(sink::EscapeSink, s::SubString{String}) =
    (write_markup!(sink, s); ncodeunits(s))
function Base.write(sink::EscapeSink, c::Char)
    # Nothing held means the character stands on its own, which spares building
    # a string for it. A line ending is written this way for every line.
    if isempty(sink.held)
        if sink.margin_pending
            sink.begin_content = true
            sink.margin_pending = false
        end
        write(sink.out, c)
        carry!(sink, c)
    else
        write_markup!(sink, string(c))
    end
    return ncodeunits(c)
end
Base.write(sink::EscapeSink, b::UInt8) = write(sink, Char(b))
Base.unsafe_write(sink::EscapeSink, p::Ptr{UInt8}, n::UInt) =
    (write_markup!(sink, unsafe_string(p, n)); n)

"""
The document's own text, escaped wherever it would be read as markup.

Everything but the last `lookahead` characters has all the context it needs
inside `s`, and is written here. The tail is held for the next thing written to
say what follows it.
"""
function write_escapable!(sink::EscapeSink, s::AbstractString)
    isempty(s) && return nothing
    if !isempty(sink.held)
        resolve_held!(sink, s, firstindex(s), length(s))
        if !isempty(sink.held)
            hold_run!(sink, s, true)
            return resolve_held!(sink, "", 1, 0)
        end
    end
    if sink.margin_pending
        sink.begin_content = true
        sink.margin_pending = false
    end
    # Walk back `lookahead` characters to find where the tail starts.
    tail = ncodeunits(s) + 1
    for _ in 1:(sink.lookahead)
        tail <= firstindex(s) && break
        tail = prevind(s, tail)
    end
    escape_run!(sink, s, tail)
    return hold_run!(sink, SubString(s, tail), true)
end

# Escape `s` up to `stop`, in the runs between the characters that have to be
# hidden, which most text has none of.
function escape_run!(sink::EscapeSink, s::AbstractString, stop::Int)
    ncu = ncodeunits(s)
    i = firstindex(s)
    i >= stop && return nothing
    run = i
    c, j = char_forward(s, i, ncu)
    while i < stop
        nextc, after_next = char_forward(s, j, ncu)
        if needs_escape(c, sink.prev, nextc, sink.begin_content, sink.follows_digit) ||
                claimed_at(sink, c, s, i)
            i > run && write(sink.out, SubString(s, run, prevind(s, i)))
            escape_char(sink.out, c)
            run = j
        end
        carry!(sink, c)
        i, c, j = j, nextc, after_next
    end
    run < stop && write(sink.out, SubString(s, run, prevind(s, stop)))
    return nothing
end

# A spelling claimed where `c` stands in `s`. The claims of a block rule are
# read only where a line's content starts, since that is the only place the rule
# would read them back.
function claimed_at(sink::EscapeSink, c::AbstractChar, s::AbstractString, i::Int)
    if opens_claim(sink.firsts, c) && starts_claim(sink.claimed, s, i)
        return true
    end
    sink.begin_content || return false
    return opens_claim(sink.firsts_line, c) && starts_claim(sink.claimed_line, s, i)
end

# A claimed spelling written out in full at `i`.
function starts_claim(claimed::Vector{String}, s::AbstractString, i::Int)
    for claim in claimed
        startswith(SubString(s, i), claim) && return true
    end
    return false
end

# The character at `i`, and where the one after it starts. Markdown is mostly
# ASCII, and a byte below `0x80` stands for itself, so the general decode is
# reached for only where it has to be. `\0` marks the end of the text.
@inline function char_forward(s::AbstractString, i::Int, ncu::Int)
    i > ncu && return ('\0', i + 1)
    byte = @inbounds codeunit(s, i)
    byte < 0x80 && return (Char(byte), i + 1)
    return (s[i], nextind(s, i))
end

"""
Finish the document, writing out whatever is still held back, and hand back what
was written. Nothing follows the last character, which the line-end rules read
as the end of a line.
"""
function escape_markdown(format::Markdown)
    sink = format.buffer
    isempty(sink.held) || resolve_held!(sink, "", 1, 0, true)
    return String(take!(sink.out))
end

# Parentheses only need escaping when they cannot be read as a balanced pair.
function balanced_parens(destination::AbstractString)
    depth = 0
    for c in destination
        c === '(' && (depth += 1)
        c === ')' && (depth -= 1)
        depth < 0 && return false
    end
    return depth == 0
end

# A destination is delimited by whitespace unless wrapped in angle brackets.
function write_destination(w, destination::AbstractString)
    out = IOBuffer()
    # A line ending ends the destination in either form, so the only spelling
    # left for one is its percent encoding.
    destination = replace(replace(destination, '\r' => "%0D"), '\n' => "%0A")
    wrapped = isempty(destination) || occursin(r"\s", destination)
    escape_parens = !wrapped && !balanced_parens(destination)
    for c in destination
        if c === '<' || c === '>' || c === '\\' || (escape_parens && (c === '(' || c === ')'))
            escape_char(out, c)
        elseif !wrapped && c === '`'
            escape_char(out, c)
        else
            print(out, c)
        end
    end
    body = String(take!(out))
    return wrapped ? literal(w, "<", body, ">") : literal(w, body)
end

function escape_markdown_title(s::AbstractString)
    out = IOBuffer()
    for c in s
        c in ('"', '\\', '`', '<', '>') && print(out, '\\')
        print(out, c)
    end
    return String(take!(out))
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

function write_markdown(writer::Writer, ast::Node)
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

# Extension syntax the document was parsed with has to be escaped in text too.
function write_markdown(::Document, w, node, ent)
    ent && claim!(w.format, node.t.claimed_syntax, node.t.claimed_line_syntax)
    return nothing
end

write_markdown(::Text, w, node, ent) =
    content(w, node.literal, !isnull(node.prv) && node.prv.t isa Backslash)

write_markdown(::Backslash, w, node, ent) = literal(w, "\\")

# An ATX heading occupies a single line, so a break in its content has nowhere
# to go and closes up to a space. Setext form keeps the break.
function breaks_line(node::Node)
    parent = node.parent
    while !isnull(parent) && parent.t isa AbstractInline
        parent = parent.parent
    end
    isnull(parent) && return true
    parent.t isa Heading || return true
    return setext_heading(parent.t, parent)
end

function write_markdown(::SoftBreak, w, node, ent)
    breaks_line(node) || return literal(w, " ")
    cr(w)
    return print_margin(w)
end

function write_markdown(::LineBreak, w, node, ent)
    breaks_line(node) || return literal(w, " ")
    # Backslash hard breaks already have the `\` from the Backslash node
    if isnull(node.prv) || !(node.prv.t isa Backslash)
        literal(w, "  ")
    end
    cr(w)
    return print_margin(w)
end

# Emit `content` wrapped in a backtick span, with a trailing `suffix` after the
# closing delimiter. The delimiter is the next count longer than the longest
# backtick run in `content` that keeps the parity the span needs: a code span
# takes an odd count, math an even one. Content that starts or ends with a
# backtick is space-padded so it can't merge with the delimiter.
function backtick_span(w, content, suffix = ""; even::Bool = false)
    num = foldl(eachmatch(r"`+", content); init = 0) do a, b
        max(a, length(b.match))
    end
    backticks = num + 1
    iseven(backticks) === even || (backticks += 1)
    # Empty content has no spelling of its own, since a bare pair of delimiters
    # reads as text, so the span holds a single space instead.
    isempty(content) && (content = " ")
    # A code span drops one leading and trailing space unless its content is
    # nothing but spaces, so content already sitting between spaces needs a pair
    # of its own to survive.
    spaced = startswith(content, ' ') && endswith(content, ' ') && any(!isequal(' '), content)
    pad = spaced || startswith(content, '`') || endswith(content, '`')
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

# An autolink is a link whose text is its own destination and whose text, in
# angle brackets, spells an autolink. Written as an inline link its text would
# need escaping, which the angle bracket form avoids.
function is_autolink(link::Link, node::Node)
    isempty(link.title) || return false
    child = node.first_child
    (!isnull(child) && child.t isa Text && isnull(child.nxt)) || return false
    destination = link.destination
    startswith(destination, "mailto:") && (destination = chop(destination; head = 7, tail = 0))
    destination == normalize_uri(child.literal) || return false
    bracketed = string('<', child.literal, '>')
    m = something(match(reAutolink, bracketed), match(reEmailAutolink, bracketed), Some(nothing))
    # Both patterns are anchored at the start only, so a text holding its own
    # `>` would match a prefix and leave the rest behind.
    return m !== nothing && ncodeunits(m.match) == ncodeunits(bracketed)
end

function write_markdown(link::Link, w, node, ent)
    if is_autolink(link, node)
        # The text repeats the destination, so it is skipped rather than written.
        if ent
            literal(w, "<", node.first_child.literal, ">")
            w.context[:autolink_enabled] = w.enabled
            w.enabled = false
        else
            w.enabled = w.context[:autolink_enabled]
        end
        return nothing
    end
    return if ent
        literal(w, "[")
    else
        literal(w, "](")
        write_destination(w, link.destination)
        isempty(link.title) || literal(w, " \"", escape_markdown_title(link.title), "\"")
        literal(w, ")")
    end
end

function write_markdown(image::Image, w, node, ent)
    return if ent
        literal(w, "![")
    else
        literal(w, "](")
        write_destination(w, image.destination)
        isempty(image.title) || literal(w, " \"", escape_markdown_title(image.title), "\"")
        literal(w, ")")
    end
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

# Only the setext form spans several lines, and only levels one and two have
# one, so content holding a break decides how the heading is written.
function setext_heading(heading::Heading, node::Node)
    heading.level <= 2 || return false
    for (child, entering) in node
        entering && (child.t isa SoftBreak || child.t isa LineBreak) && return true
    end
    return false
end

function write_markdown(heading::Heading, w, node, ent)
    setext = setext_heading(heading, node)
    return if ent
        print_margin(w)
        setext || literal(w, "#"^heading.level, " ")
    else
        cr(w)
        if setext
            print_margin(w)
            literal(w, (heading.level === 1 ? "=" : "-")^3)
            cr(w)
        end
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
        push!(w.format.list_marker_offset, sibling_list_offset(node))
    else
        w.format.list_depth -= 1
        pop!(w.format.list_item_number)
        pop!(w.format.list_marker_offset)
        cr(w)
        linebreak(w, node)
    end
end

# Lists of the same kind sitting next to each other would reparse as a single
# list, so each one shifts its marker away from the one before it.
function sibling_list_offset(list::Node)
    offset = 0
    prev = list.prv
    while !isnull(prev) &&
            prev.t isa List &&
            prev.t.list_data.type === list.t.list_data.type
        offset += 1
        prev = prev.prv
    end
    return offset
end

function write_markdown(item::Item, w, node, enter)
    return if enter
        offset = w.format.list_marker_offset[end]
        if item.list_data.type === :ordered
            delimiter = isodd(offset) ? ") " : ". "
            number = lpad(string(w.format.list_item_number[end], delimiter), 4, " ")
            w.format.list_item_number[end] += 1
            push_margin!(w, 1, number)
        else
            bullets = ['-', '+', '*', '-', '+', '*']
            bullet = bullets[mod1(min(w.format.list_depth, length(bullets)) + offset, length(bullets))]
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

# Indentation alone marks the block, so anything that reads the same indentation
# as its own continuation swallows it, and a line of nothing but spaces loses
# them to the writer's trailing whitespace trimming.
function indentable(node::Node)
    prv = node.prv
    if !isnull(prv) && (prv.t isa List || (prv.t isa CodeBlock && !prv.t.is_fenced))
        return false
    end
    for line in eachline(IOBuffer(node.literal))
        !isempty(line) && all(isspace, line) && return false
    end
    return true
end

function write_fence(w, fence, info, content)
    print_margin(w)
    literal(w, fence, info)
    cr(w)
    for line in eachline(IOBuffer(content); keep = true)
        print_margin(w)
        literal(w, line)
    end
    # A last line with no newline of its own would carry the closing fence.
    cr(w)
    print_margin(w)
    literal(w, fence)
    return cr(w)
end

# A backtick fence closes on the first run of backticks as long as itself, so it
# has to be longer than anything the content holds.
function longest_backtick_run(content::AbstractString)
    return foldl(eachmatch(r"`+", content); init = 0) do a, b
        max(a, length(b.match))
    end
end

function write_markdown(code::CodeBlock, w, node, ent)
    if code.is_fenced
        # A fence the parser read already clears its content. One a caller built
        # by hand carries no such guarantee, and only backticks close a backtick
        # fence.
        fence_length = if code.fence_char === '`'
            max(code.fence_length, longest_backtick_run(node.literal) + 1)
        else
            code.fence_length
        end
        write_fence(w, code.fence_char^fence_length, code.info, node.literal)
    elseif indentable(node)
        for line in eachline(IOBuffer(node.literal); keep = true)
            print_margin(w)
            indent = all(isspace, line) ? 0 : CODE_INDENT
            literal(w, ' '^indent, line)
        end
    else
        write_fence(w, "`"^max(longest_backtick_run(node.literal) + 1, 3), "", node.literal)
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
