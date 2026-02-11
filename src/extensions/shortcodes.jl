#
# AST Nodes
#

"""Inline shortcode. Unexpanded shortcodes pass through to output."""
struct Shortcode <: AbstractInline
    name::String
    args::Vector{String}
    kwargs::Vector{Pair{String,String}}
    raw::String
end

"""Block-level shortcode (standalone on a line)."""
struct ShortcodeBlock <: AbstractBlock
    name::String
    args::Vector{String}
    kwargs::Vector{Pair{String,String}}
    raw::String
end

#
# Context
#

"""Context passed to shortcode handlers during expansion."""
struct ShortcodeContext
    source::String
    sourcepos::SourcePos
    meta::Dict{String,Any}
end

function _shortcode_context(parser::Parser, sourcepos::SourcePos)
    ShortcodeContext(
        getmeta(parser.doc, "source", ""),
        sourcepos,
        something(parser.doc.meta, Dict{String,Any}()),
    )
end

function _shortcode_context(block::Node)
    doc = block
    while !isnull(doc.parent)
        doc = doc.parent
    end
    ShortcodeContext(
        getmeta(doc, "source", ""),
        block.sourcepos,
        something(doc.meta, Dict{String,Any}()),
    )
end

#
# Rule
#

"""
    ShortcodeRule(; open="{{<", close=">}}", handlers=Dict{String,Function}())

Parse shortcodes with configurable delimiters.

Not enabled by default. Default delimiters match Quarto/Hugo syntax.

Handlers run at parse time: `handler(name, args, kwargs, ctx::ShortcodeContext) -> Node`.
`args` is a `Vector{String}` of positional arguments, `kwargs` is a
`Vector{Pair{String,String}}` of named `key=value` arguments. Quoted strings
preserve spaces; backslash escapes work inside quotes.
If a handler returns a Node, it replaces the shortcode in the AST.
If no handler matches, the shortcode node is preserved for write-time handling
via the writer `transform` system.

```markdown
Inline: Text {{< ref "page" >}} here.
Block (standalone): {{< pagebreak >}}
```
"""
struct ShortcodeRule
    open::String
    close::String
    handlers::Dict{String,Function}
    function ShortcodeRule(;
        open::String = "{{<",
        close::String = ">}}",
        handlers::Dict{String,Function} = Dict{String,Function}(),
    )
        new(open, close, handlers)
    end
end

#
# Parse logic
#

"""
Try to parse a shortcode from current position.
Returns `(name, args, kwargs, raw)` or `nothing`.
Restores parser position on failure.
"""
function _try_parse_shortcode(p::AbstractParser, rule::ShortcodeRule)
    startswith(p, rule.open) || return nothing
    start_pos = position(p)

    # Advance past open delimiter
    for _ in rule.open
        read(p, Char)
    end

    # Skip whitespace after opener
    while !eof(p)
        c = trypeek(p, Char)
        (c === nothing || !isspace(c)) && break
        read(p, Char)
    end

    # Read name (non-whitespace, stop at close delimiter)
    name_start = position(p)
    while !eof(p)
        c = trypeek(p, Char)
        (c === nothing || isspace(c)) && break
        startswith(p, rule.close) && break
        read(p, Char)
    end
    name_end = position(p) - 1
    if name_end < name_start
        seek(p, start_pos)
        return nothing
    end
    name = String(bytes(p, name_start, name_end))

    # Scan for close delimiter, collecting args
    while !eof(p)
        if startswith(p, rule.close)
            args_end = position(p) - 1
            args =
                args_end >= name_end + 1 ? strip(String(bytes(p, name_end + 1, args_end))) :
                ""
            # Consume close delimiter
            for _ in rule.close
                read(p, Char)
            end
            raw = String(bytes(p, start_pos, position(p) - 1))
            parsed_args, parsed_kwargs = _parse_shortcode_args(string(args))
            return (name, parsed_args, parsed_kwargs, raw)
        end
        read(p, Char)
    end

    # No close delimiter found
    seek(p, start_pos)
    return nothing
end

"""Parse shortcode args string into positional args and named kwargs."""
function _parse_shortcode_args(s::AbstractString)
    args = String[]
    kwargs = Pair{String,String}[]
    isempty(s) && return (args, kwargs)
    buf = IOBuffer()
    in_quote = nothing  # nothing, '"', or '\''
    eq_pos = 0          # position of first unquoted '=' in current token
    token_len = 0
    escaped = false
    for c in s
        if escaped
            write(buf, c)
            token_len += 1
            escaped = false
        elseif in_quote !== nothing && c == '\\'
            escaped = true
        elseif in_quote !== nothing
            if c == in_quote
                in_quote = nothing
            else
                write(buf, c)
                token_len += 1
            end
        elseif c == '"' || c == '\''
            in_quote = c
        elseif isspace(c)
            _flush_shortcode_token!(buf, args, kwargs, eq_pos)
            eq_pos = 0
            token_len = 0
        else
            write(buf, c)
            token_len += 1
            if c == '=' && eq_pos == 0
                eq_pos = token_len
            end
        end
    end
    _flush_shortcode_token!(buf, args, kwargs, eq_pos)
    return (args, kwargs)
end

function _flush_shortcode_token!(buf::IOBuffer, args, kwargs, eq_pos)
    position(buf) == 0 && return
    token = String(take!(buf))
    if eq_pos > 1
        key = token[1:prevind(token, eq_pos)]
        val = token[nextind(token, eq_pos):end]
        push!(kwargs, key => val)
    else
        push!(args, token)
    end
end

function _is_solo_shortcode(literal::AbstractString, rule::ShortcodeRule)
    s = strip(literal)
    isempty(s) && return nothing
    p = StringParser(s)
    result = _try_parse_shortcode(p, rule)
    result === nothing && return nothing
    eof(p) || return nothing
    return result
end

#
# Inline rule
#

inline_rule(rule::ShortcodeRule) =
    Rule(1, string(first(rule.open))) do p, block
        result = _try_parse_shortcode(p, rule)
        result === nothing && return false
        name, args, kwargs, raw = result
        handler = get(rule.handlers, name, nothing)
        if handler !== nothing
            ctx = _shortcode_context(block)
            append_child(block, handler(name, args, kwargs, ctx))
        else
            append_child(block, Node(Shortcode(name, args, kwargs, raw)))
        end
        return true
    end

#
# Block modifier
#

block_modifier(rule::ShortcodeRule) =
    Rule(2) do parser, node
        node.t isa Paragraph || return nothing
        result = _is_solo_shortcode(node.literal, rule)
        result === nothing && return nothing
        name, args, kwargs, raw = result

        handler = get(rule.handlers, name, nothing)
        if handler !== nothing
            ctx = _shortcode_context(parser, node.sourcepos)
            replacement = handler(name, args, kwargs, ctx)
            node.t = replacement.t
            node.literal = replacement.literal
            while !isnull(replacement.first_child)
                child = replacement.first_child
                unlink(child)
                append_child(node, child)
            end
        else
            node.t = ShortcodeBlock(name, args, kwargs, raw)
            node.literal = ""
        end
        return nothing
    end

#
# Writers
#

# --- Inline ---
write_html(sc::Shortcode, w, n, ent) = literal(w, sc.raw)
write_latex(sc::Shortcode, w, n, ent) = literal(w, sc.raw)
write_typst(sc::Shortcode, w, n, ent) = literal(w, sc.raw)
write_term(sc::Shortcode, w, n, ent) = print_literal(w, sc.raw)
write_markdown(sc::Shortcode, w, n, ent) = literal(w, sc.raw)

# --- Block ---
function write_html(sc::ShortcodeBlock, w, n, ent)
    cr(w)
    literal(w, sc.raw)
    cr(w)
end
function write_latex(sc::ShortcodeBlock, w, n, ent)
    cr(w)
    literal(w, sc.raw)
    cr(w)
end
function write_typst(sc::ShortcodeBlock, w, n, ent)
    cr(w)
    literal(w, sc.raw)
    cr(w)
end
function write_term(sc::ShortcodeBlock, w, n, ent)
    print_margin(w)
    print_literal(w, sc.raw, "\n")
end
function write_markdown(sc::ShortcodeBlock, w, n, ent)
    print_margin(w)
    literal(w, sc.raw)
    cr(w)
    linebreak(w, n)
end

# --- JSON ---
function write_json(sc::Shortcode, ctx, n, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawInline", Any["shortcode", sc.raw]))
end
function write_json(sc::ShortcodeBlock, ctx, n, enter)
    enter || return
    push_element!(ctx, json_el(ctx, "RawBlock", Any["shortcode", sc.raw]))
end
